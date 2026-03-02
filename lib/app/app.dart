import 'dart:async';

import 'package:app/app/feed/feed_registry_provider.dart';
import 'package:app/app/now_displaying/now_displaying_app_shell.dart';
import 'package:app/app/providers/app_overlay_provider.dart';
import 'package:app/app/providers/bootstrap_provider.dart';
import 'package:app/app/providers/channels_provider.dart';
import 'package:app/app/providers/indexer_tokens_provider.dart';
import 'package:app/app/providers/playlists_provider.dart';
import 'package:app/app/providers/seed_database_provider.dart';
import 'package:app/app/providers/services_provider.dart';
import 'package:app/app/providers/works_provider.dart';
import 'package:app/app/routing/router_provider.dart';
import 'package:app/domain/extensions/extensions.dart';
import 'package:app/domain/models/channel.dart';
import 'package:app/domain/models/playlist.dart';
import 'package:app/domain/models/wallet_address.dart';
import 'package:app/infra/config/app_config.dart';
import 'package:app/infra/config/app_state_service.dart';
import 'package:app/infra/database/app_database.dart';
import 'package:app/infra/database/database_provider.dart';
import 'package:app/infra/database/seed_database_gate.dart';
import 'package:app/theme/app_theme.dart';
import 'package:app/widgets/overlays/app_global_overlay_layer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
        return _AppStartupBootstrap(
          child: Stack(
            children: [
              NowDisplayingAppShell(
                router: router,
                child: child ?? const SizedBox.shrink(),
              ),
              const AppGlobalOverlayLayer(),
            ],
          ),
        );
      },
    );
  }
}

class _AppStartupBootstrap extends ConsumerStatefulWidget {
  const _AppStartupBootstrap({
    required this.child,
  });

  final Widget child;

  @override
  ConsumerState<_AppStartupBootstrap> createState() =>
      _AppStartupBootstrapState();
}

class _AppStartupBootstrapState extends ConsumerState<_AppStartupBootstrap>
    with WidgetsBindingObserver {
  bool _started = false;
  bool _isResumeSeedSyncInProgress = false;

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

      unawaited(_bootstrapAtAppStart());
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed || !_started) {
      return;
    }
    unawaited(_syncSeedDatabaseOnResume());
  }

  Future<void> _bootstrapAtAppStart() async {
    _log.info(
      'Starting app bootstrap: seedGate=${SeedDatabaseGate.isCompleted}',
    );

    final didReplaceSeedDatabase = await _syncSeedDatabaseAtStartup();
    _log.info(
      'Seed database sync at startup replaced file: $didReplaceSeedDatabase',
    );
    await _recoverFromDatabaseResetIfNeeded();

    final bootstrap = ref.read(bootstrapProvider.notifier);
    await bootstrap.bootstrap();

    await _logStartupFeedState();

    // After the database is open and bootstrap is done, migrate any addresses
    // that were added during onboarding before the seed was downloaded.
    await _migratePendingAddresses();
    if (didReplaceSeedDatabase) {
      _refreshProvidersAfterSeedDatabaseReplace();
    }
  }

  Future<void> _logStartupFeedState() async {
    final feedManager = ref.read(feedManagerProvider);
    final databaseService = ref.read(databaseServiceProvider);
    final appStateService = ref.read(appStateServiceProvider);

    _log.info(
      'AppConfig.dp1FeedUrlPresent=${AppConfig.dp1FeedUrl.isNotEmpty}, '
      'AppConfig.dp1FeedApiKeyPresent=${AppConfig.dp1FeedApiKey.isNotEmpty}',
    );

    final services = feedManager.feedServices;
    _log.info('Startup feed services available: ${services.length}');
    for (final service in services) {
      final stale = await service.shouldReloadCache();
      final bareIngestCompleted = await appStateService
          .hasFeedBareIngestCompleted(service.baseUrl);
      final lastRefresh = await appStateService.getLastRefreshTime(
        service.baseUrl,
      );
      _log.info(
        'Startup feed policy for ${service.baseUrl}: '
        'stale=$stale, '
        'bareIngestCompleted=$bareIngestCompleted, '
        'lastRefresh=${lastRefresh.toIso8601String()}',
      );
    }

    try {
      final channels = await databaseService.getChannelsByType(ChannelType.dp1);
      final baseUrls = services.map((s) => s.baseUrl).toList(growable: false);
      final playlistCount = baseUrls.isEmpty
          ? 0
          : (await databaseService.getPlaylistRowsByBaseUrls(
              baseUrls: baseUrls,
              type: PlaylistType.dp1,
            )).length;
      _log.info(
        'Startup cache counts: dp1Channels=${channels.length}, '
        'dp1Playlists=$playlistCount, baseUrls=${baseUrls.join(',')}',
      );
    } on Exception catch (e, stack) {
      _log.warning('Failed to read startup feed cache counts', e, stack);
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
  }) async {
    var personalAddresses = <String>[];
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
                    message: 'Updating feed...',
                  );
              await WidgetsBinding.instance.endOfFrame;
            }
            personalAddresses =
                await _capturePersonalAddressesBeforeSeedReplace();
            await _disconnectForSeedDatabaseReplace();
          },
          afterReplace: () async {
            try {
              if (!SeedDatabaseGate.isCompleted) {
                return;
              }
              await _reconnectAfterSeedDatabaseReplace();
              await _refetchPersonalPlaylists(personalAddresses);
            } finally {
              final overlayId = toastOverlayId;
              if (showUpdatingToast && mounted && overlayId != null) {
                ref.read(appOverlayProvider.notifier).dismissOverlay(overlayId);
              }
            }
          },
        );
  }

  Future<List<String>> _capturePersonalAddressesBeforeSeedReplace() async {
    final playlists = await ref
        .read(databaseServiceProvider)
        .getAddressPlaylists();
    return playlists
        .map((playlist) => playlist.ownerAddress?.trim())
        .whereType<String>()
        .where((address) => address.isNotEmpty)
        .map((address) => address.toUpperCase())
        .toSet()
        .toList(growable: false);
  }

  Future<void> _disconnectForSeedDatabaseReplace() async {
    await ref.read(feedManagerProvider).pauseAndDrainWork();
    await ref
        .read(tokensSyncCoordinatorProvider.notifier)
        .stopAndDrainForReset();

    // Reset list/item providers so UI detaches from stale rows during swap.
    ref
      ..invalidate(channelsProvider(ChannelType.dp1))
      ..invalidate(channelsProvider(ChannelType.localVirtual))
      ..invalidate(playlistsProvider(PlaylistType.dp1))
      ..invalidate(playlistsProvider(PlaylistType.addressBased))
      ..invalidate(worksProvider);

    await ref.read(databaseServiceProvider).close();
  }

  Future<void> _reconnectAfterSeedDatabaseReplace() async {
    ref
      ..invalidate(tokensSyncCoordinatorProvider)
      ..invalidate(appDatabaseProvider)
      ..invalidate(databaseServiceProvider)
      ..invalidate(feedManagerProvider);
  }

  void _refreshProvidersAfterSeedDatabaseReplace() {
    // Ensure UI providers reconnect to the fresh DB connection and rows.
    ref
      ..invalidate(channelsProvider(ChannelType.dp1))
      ..invalidate(channelsProvider(ChannelType.localVirtual))
      ..invalidate(playlistsProvider(PlaylistType.dp1))
      ..invalidate(playlistsProvider(PlaylistType.addressBased))
      ..invalidate(worksProvider);
  }

  Future<void> _refetchPersonalPlaylists(List<String> addresses) async {
    if (addresses.isEmpty) return;

    final addressService = ref.read(addressServiceProvider);
    for (final address in addresses) {
      await addressService.addAddress(
        walletAddress: WalletAddress(
          address: address,
          createdAt: DateTime.now(),
          name: _shortAddress(address),
        ),
        syncNow: false,
      );
    }

    await ref
        .read(tokensSyncCoordinatorProvider.notifier)
        .syncAddresses(addresses);
  }

  /// Reads addresses stored in `PendingAddressesStore` (written when the user
  /// added an address during onboarding while the seed was still downloading)
  /// and creates the corresponding SQLite playlists + starts workers.
  Future<void> _migratePendingAddresses() async {
    final pendingStore = ref.read(pendingAddressesStoreProvider);
    final addresses = await pendingStore.getAddresses();

    if (addresses.isEmpty) return;

    _log.info(
      'Migrating ${addresses.length} address(es) added during pre-seed '
      'onboarding to SQLite.',
    );

    final addressService = ref.read(addressServiceProvider);

    for (final address in addresses) {
      try {
        await addressService.addAddress(
          walletAddress: WalletAddress(
            address: address,
            createdAt: DateTime.now(),
            name: address.shortenAddress(),
          ),
        );
        _log.info('Migrated pending address: $address');
      } on Object catch (e, st) {
        _log.warning('Failed to migrate pending address: $address', e, st);
      }
    }

    await pendingStore.clear();
    _log.info('Pending address migration complete.');
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
        .map((address) => address.toUpperCase())
        .toSet()
        .toList(growable: false);

    if (addresses.isEmpty) {
      return;
    }

    final addressService = ref.read(addressServiceProvider);

    for (final address in addresses) {
      await appState.clearAddressAnchor(address);

      await appState.setAddressIndexingStatus(
        address: address,
        status: AddressIndexingProcessStatus(
          state: AddressIndexingProcessState.indexingTriggered,
          updatedAt: DateTime.now().toUtc(),
        ),
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
  Widget build(BuildContext context) => widget.child;
}
