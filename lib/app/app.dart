import 'dart:async';

import 'package:app/app/feed/feed_registry_provider.dart';
import 'package:app/app/now_displaying/now_displaying_app_shell.dart';
import 'package:app/app/providers/bootstrap_provider.dart';
import 'package:app/app/providers/channels_provider.dart';
import 'package:app/app/providers/indexer_tokens_provider.dart';
import 'package:app/app/providers/playlists_provider.dart';
import 'package:app/app/providers/seed_database_provider.dart';
import 'package:app/app/providers/services_provider.dart';
import 'package:app/app/providers/works_provider.dart';
import 'package:app/app/routing/router_provider.dart';
import 'package:app/app/routing/routes.dart';
import 'package:app/domain/extensions/extensions.dart';
import 'package:app/domain/models/channel.dart';
import 'package:app/domain/models/playlist.dart';
import 'package:app/domain/models/wallet_address.dart';
import 'package:app/infra/config/app_state_service.dart';
import 'package:app/infra/database/app_database.dart';
import 'package:app/infra/database/database_provider.dart';
import 'package:app/infra/database/seed_database_gate.dart';
import 'package:app/theme/app_theme.dart';
import 'package:app/ui/screens/global_toast_overlay_screen.dart';
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
        return _AppStartupBootstrap(
          router: router,
          child: NowDisplayingAppShell(
            router: router,
            child: child ?? const SizedBox.shrink(),
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
    final didReplaceSeedDatabase = await _syncSeedDatabaseAtStartup();
    await _recoverFromDatabaseResetIfNeeded();

    final bootstrap = ref.read(bootstrapProvider.notifier);
    await bootstrap.bootstrap();

    // After the database is open and bootstrap is done, migrate any addresses
    // that were added during onboarding before the seed was downloaded.
    await _migratePendingAddresses();
    if (didReplaceSeedDatabase) {
      _refreshProvidersAfterSeedDatabaseReplace();
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
    var isToastVisible = false;
    final router = widget.router;
    return ref
        .read(seedDownloadProvider.notifier)
        .syncAtAppStart(
          beforeReplace: () async {
            if (!SeedDatabaseGate.isCompleted) {
              return;
            }
            if (showUpdatingToast && mounted) {
              unawaited(
                router.pushNamed(
                  RouteNames.globalToast,
                  extra: const GlobalToastPayload(
                    message: 'Updating feed...',
                  ),
                ),
              );
              await WidgetsBinding.instance.endOfFrame;
              isToastVisible = true;
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
              if (showUpdatingToast &&
                  mounted &&
                  isToastVisible &&
                  router.canPop()) {
                router.pop();
                isToastVisible = false;
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
