import 'dart:async';

import 'package:app/app/now_displaying/now_displaying_visibility_sync.dart';
import 'package:app/app/providers/app_lifecycle_provider.dart';
import 'package:app/app/providers/app_overlay_provider.dart';
import 'package:app/app/providers/bootstrap_provider.dart';
import 'package:app/app/providers/force_update_provider.dart';
import 'package:app/app/providers/indexer_tokens_provider.dart';
import 'package:app/app/providers/local_data_cleanup_provider.dart';
import 'package:app/app/providers/onboarding_provider.dart';
import 'package:app/app/providers/seed_database_provider.dart';
import 'package:app/app/providers/services_provider.dart';
import 'package:app/app/routing/deeplink_handler.dart';
import 'package:app/app/routing/router_provider.dart';
import 'package:app/app/routing/routes.dart';
import 'package:app/app/widgets/builder_overlay_scope.dart';
import 'package:app/domain/models/channel.dart';
import 'package:app/domain/models/playlist.dart';
import 'package:app/domain/models/wallet_address.dart';
import 'package:app/domain/utils/address_deduplication.dart';
import 'package:app/infra/config/app_state_service.dart';
import 'package:app/infra/database/app_database.dart';
import 'package:app/infra/database/database_provider.dart';
import 'package:app/infra/database/seed_database_gate.dart';
import 'package:app/theme/app_theme.dart';
import 'package:app/ui/screens/ff1_setup/connect_ff1_page.dart';
import 'package:app/ui/screens/ff1_setup/start_setup_ff1_page.dart';
import 'package:app/ui/widgets/force_update_overlay.dart';
import 'package:app/widgets/overlays/app_global_overlay_layer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:logging/logging.dart';

/// Root application widget.
/// Consumes the router provider to configure navigation.
class App extends ConsumerWidget {
  /// Creates the root App widget.
  const App({
    required this.initialLocation,
    super.key,
  });

  /// Initial location for the app router.
  final String initialLocation;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(
      routerProvider(initialLocation),
    );

    return MaterialApp.router(
      title: 'Feral File',
      routerConfig: router,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme(),
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: MediaQuery.textScalerOf(context).clamp(
              minScaleFactor: 1,
              maxScaleFactor: 1.15,
            ),
          ),
          child: BuilderOverlayScope(
            child: _AppStartupBootstrap(
              router: router,
              child: NowDisplayingVisibilitySync(
                child: Stack(
                  children: [
                    child ?? const SizedBox.shrink(),
                    AppGlobalOverlayLayer(router: router),
                    const ForceUpdateOverlay(),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _AppStartupBootstrap extends ConsumerStatefulWidget {
  const _AppStartupBootstrap({
    required this.router,
    required this.child,
  });

  final GoRouter router;
  final Widget child;

  @override
  ConsumerState<_AppStartupBootstrap> createState() =>
      _AppStartupBootstrapState();
}

class _AppStartupBootstrapState extends ConsumerState<_AppStartupBootstrap>
    with WidgetsBindingObserver {
  bool _started = false;
  bool _isResumeSeedSyncInProgress = false;
  bool _isProcessingRouteDeeplink = false;
  DeeplinkNavigationAction? _pendingRouteDeeplinkAction;
  final Completer<void> _bootstrapReadyCompleter = Completer<void>();
  ProviderSubscription<AsyncValue<DeeplinkNavigationAction>>?
  _deeplinkActionsSubscription;

  static final _log = Logger('AppStartupBootstrap');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_started) {
        return;
      }
      _started = true;
      _startDeeplinkHandling();
      unawaited(_bootstrapAtAppStart());
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _deeplinkActionsSubscription?.close();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed || !_started) {
      return;
    }
    unawaited(_syncSeedDatabaseOnResume());
  }

  void _startDeeplinkHandling() {
    _deeplinkActionsSubscription ??= ref
        .listenManual<AsyncValue<DeeplinkNavigationAction>>(
          deeplinkActionsProvider,
          (previous, next) {
            next.whenData(_handleDeeplinkNavigation);
          },
        );
    unawaited(
      ref.read(deeplinkHandlerProvider).start(),
    );
  }

  void _handleDeeplinkNavigation(DeeplinkNavigationAction action) {
    if (action.type == DeeplinkType.deviceConnect) {
      if (action.source == DeeplinkSource.scan) {
        unawaited(
          widget.router.push(
            Routes.connectFF1Page,
            extra: ConnectFF1PagePayload(
              deeplink: action.link,
            ),
          ),
        );
      } else {
        unawaited(
          widget.router.pushReplacement(
            Routes.startSetupFf1,
            extra: StartSetupFf1PagePayload(deeplink: action.link),
          ),
        );
      }
      return;
    }

    if (action.type == DeeplinkType.appRoute) {
      _pendingRouteDeeplinkAction = action;
      unawaited(_processPendingRouteDeeplink());
    }
  }

  Future<void> _processPendingRouteDeeplink() async {
    if (_isProcessingRouteDeeplink) {
      return;
    }
    _isProcessingRouteDeeplink = true;

    try {
      while (mounted && _pendingRouteDeeplinkAction != null) {
        final action = _pendingRouteDeeplinkAction!;
        _pendingRouteDeeplinkAction = null;

        final location = action.location;
        if (location == null || location.isEmpty) {
          continue;
        }

        await _waitUntilReadyForRouteNavigation();
        if (!mounted) {
          return;
        }

        // Keep navigation stack as [home, detail] so back goes to home.
        widget.router.go(Routes.home);
        await widget.router.push(location);
      }
    } finally {
      _isProcessingRouteDeeplink = false;
    }
  }

  Future<void> _waitUntilReadyForRouteNavigation() async {
    await _bootstrapReadyCompleter.future;

    if (!SeedDatabaseGate.isCompleted) {
      await SeedDatabaseGate.future;
    }

    while (mounted) {
      final hasDoneOnboarding = await ref.read(
        hasDoneOnboardingProvider.future,
      );
      if (hasDoneOnboarding) {
        return;
      }
      await Future<void>.delayed(const Duration(milliseconds: 300));
      ref.invalidate(hasDoneOnboardingProvider);
    }
  }

  Future<void> _bootstrapAtAppStart() async {
    try {
      unawaited(_triggerForceUpdateCheck());

      _log.info(
        'Starting app bootstrap: seedGate=${SeedDatabaseGate.isCompleted}',
      );

      unawaited(_migrateLegacyDataInBackground());

      final didReplaceSeedDatabase = await _syncSeedDatabaseAtStartup();
      _log.info(
        'Seed database sync at startup replaced file: $didReplaceSeedDatabase',
      );
      await _recoverFromDatabaseResetIfNeeded();

      final bootstrap = ref.read(bootstrapProvider.notifier);
      await bootstrap.bootstrap();

      await _logStartupFeedState();

      // Ensure tracked addresses have playlists and resume indexing.
      // Always run after bootstrap so interrupted indexing resumes even when
      // ETag unchanged (didReplaceSeedDatabase == false).
      await ref.read(ensureTrackedAddressesHavePlaylistsAndResumeProvider)();
      if (didReplaceSeedDatabase) {
        _refreshProvidersAfterSeedDatabaseReplace();
      }
    } finally {
      if (!_bootstrapReadyCompleter.isCompleted) {
        _bootstrapReadyCompleter.complete();
      }
    }
  }

  Future<void> _triggerForceUpdateCheck() async {
    try {
      final rc = ref.read(remoteConfigServiceProvider);
      await rc.fetchAndPersist();
      final fu = ref.read(forceUpdateServiceProvider);
      final versionInfo = await fu.checkForUpdate();
      if (versionInfo != null && mounted) {
        ref.read(forceUpdateProvider.notifier).setRequired(versionInfo);
      }
    } on Object catch (e, st) {
      _log.warning('Force update check failed', e, st);
    }
  }

  Future<void> _migrateLegacyDataInBackground() async {
    final migrationService = ref.read(legacyDataMigrationServiceProvider);
    if (!await migrationService.shouldRunMigration()) {
      return;
    }

    String? toastOverlayId;
    try {
      if (mounted) {
        toastOverlayId = ref
            .read(appOverlayProvider.notifier)
            .showToast(message: 'Preparing data...');
        await WidgetsBinding.instance.endOfFrame;
      }
      await migrationService.migrateIfNeeded();
    } on Object catch (e, st) {
      _log.warning('Background legacy migration failed.', e, st);
    } finally {
      final overlayId = toastOverlayId;
      if (mounted && overlayId != null) {
        ref.read(appOverlayProvider.notifier).dismissOverlay(overlayId);
      }
    }
  }

  Future<void> _logStartupFeedState() async {
    try {
      final databaseService = ref.read(databaseServiceProvider);
      final channels = await databaseService.getChannelsByType(ChannelType.dp1);
      final playlists = await databaseService.getAllPlaylists(
        type: PlaylistType.dp1,
      );
      _log.info(
        'Startup cache counts: dp1Channels=${channels.length}, '
        'dp1Playlists=${playlists.length}',
      );
      if (channels.isEmpty && playlists.isEmpty) {
        _log.warning(
          'Seed-backed DP1 content is currently empty; if this is a fresh '
          'install, open channel/playlist feeds and tap Retry to re-run seed '
          'sync.',
        );
      }
    } on Exception catch (e, stack) {
      _log.warning('Failed to read startup cache counts', e, stack);
    }
  }

  Future<void> _syncSeedDatabaseOnResume() async {
    if (_isResumeSeedSyncInProgress) {
      return;
    }
    _isResumeSeedSyncInProgress = true;

    try {
      final didReplaceSeedDatabase = await _syncSeedDatabaseIfNeeded(
        showUpdatingToast: false,
      );
      if (didReplaceSeedDatabase) {
        _refreshProvidersAfterSeedDatabaseReplace();
      }
    } finally {
      _isResumeSeedSyncInProgress = false;
    }
  }

  Future<bool> _syncSeedDatabaseAtStartup() async {
    return _syncSeedDatabaseIfNeeded(showUpdatingToast: true);
  }

  Future<bool> _syncSeedDatabaseIfNeeded({
    required bool showUpdatingToast,
    bool failSilently = true,
  }) async {
    String? toastOverlayId;
    return ref
        .read(seedDownloadProvider.notifier)
        .syncAtAppStart(
          beforeReplace: () async {
            if (!SeedDatabaseGate.isCompleted) {
              return;
            }
            if (showUpdatingToast && mounted) {
              toastOverlayId = ref
                  .read(appOverlayProvider.notifier)
                  .showToast(
                    message: 'Updating art library...',
                  );
              await WidgetsBinding.instance.endOfFrame;
            }
            await _disconnectForSeedDatabaseReplace();
          },
          afterReplace: () async {
            try {
              if (!SeedDatabaseGate.isCompleted) {
                return;
              }
              await _reconnectAfterSeedDatabaseReplace();
              await ref.read(
                ensureTrackedAddressesHavePlaylistsAndResumeProvider,
              )();
            } finally {
              final overlayId = toastOverlayId;
              if (showUpdatingToast && mounted && overlayId != null) {
                ref.read(appOverlayProvider.notifier).dismissOverlay(overlayId);
              }
            }
          },
          failSilently: failSilently,
        );
  }

  Future<void> _disconnectForSeedDatabaseReplace() async {
    await ref
        .read(tokensSyncCoordinatorProvider.notifier)
        .stopAndDrainForReset();
    await ref
        .read(ensureTrackedAddressesSyncCoordinatorProvider.notifier)
        .stopAndDrainForReset();

    ref.read(isSeedDatabaseReadyProvider.notifier).state = false;
    // Reset list/item providers so UI detaches from stale rows during swap.
    ref
        .read(localDataCleanupServiceProvider)
        .invalidateListProvidersBeforeDbClose
        ?.call();

    await ref.read(databaseServiceProvider).close();
  }

  Future<void> _reconnectAfterSeedDatabaseReplace() async {
    ref
        .read(localDataCleanupServiceProvider)
        .invalidateReconnectInfraProviders
        ?.call();
    ref.read(isSeedDatabaseReadyProvider.notifier).state = true;
  }

  void _refreshProvidersAfterSeedDatabaseReplace() {
    // Ensure UI providers reconnect to the fresh DB connection and rows.
    ref
        .read(localDataCleanupServiceProvider)
        .invalidateListProvidersBeforeDbClose
        ?.call();
  }

  Future<void> _recoverFromDatabaseResetIfNeeded() async {
    final requiresReindex = await consumeDatabaseResetReindexMarker();
    if (!requiresReindex) {
      return;
    }

    final appState = ref.read(appStateServiceProvider);
    final databaseService = ref.read(databaseServiceProvider);

    // Read known addresses from SQLite source of truth.
    final addressPlaylists = await databaseService.getAddressPlaylists();
    final addresses = addressPlaylists
        .map((playlist) => playlist.ownerAddress)
        .whereType<String>()
        .map((address) => address.toNormalizedAddress())
        .toSet()
        .toList(growable: false);

    if (addresses.isEmpty) {
      return;
    }

    final addressService = ref.read(addressServiceProvider);

    for (final address in addresses) {
      await appState.clearAddressCheckpoint(address);

      await appState.setAddressIndexingStatus(
        address: address,
        status: AddressIndexingProcessStatus.indexingTriggeredPending(),
      );

      await addressService.addAddress(
        walletAddress: WalletAddress(
          address: address,
          createdAt: DateTime.now(),
          name: _shortAddress(address),
        ),
      );
    }
  }

  String _shortAddress(String address) {
    if (address.length <= 10) {
      return address;
    }
    return '${address.substring(0, 6)}...'
        '${address.substring(address.length - 4)}';
  }

  @override
  Widget build(BuildContext context) {
    // Keep AppLifecycleNotifier alive so it can attach
    // the WidgetsBinding observer.
    ref.watch(appLifecycleProvider);
    // Keep tracked addresses sync alive; watches ObjectBox TrackedAddressEntity.
    ref.watch(trackedAddressesSyncProvider);
    return ProviderScope(
      overrides: [
        seedDownloadRetryProvider.overrideWithValue(() async {
          await _syncSeedDatabaseIfNeeded(
            showUpdatingToast: true,
            failSilently: false,
          );
        }),
      ],
      child: widget.child,
    );
  }
}
