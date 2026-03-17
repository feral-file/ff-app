import 'dart:async';

import 'package:app/app/providers/address_indexing_job_provider.dart';
import 'package:app/app/providers/ff1_bluetooth_device_providers.dart';
import 'package:app/domain/extensions/playlist_ext.dart';
import 'package:app/domain/utils/address_deduplication.dart';
import 'package:app/infra/config/app_config.dart';
import 'package:app/infra/config/app_state_service.dart';
import 'package:app/infra/database/database_provider.dart'
    hide ff1BluetoothDeviceServiceProvider;
import 'package:app/infra/database/ff1_bluetooth_device_service.dart';
import 'package:app/infra/database/objectbox_init.dart';
import 'package:app/infra/database/objectbox_models.dart';
import 'package:app/infra/database/seed_database_gate.dart';
import 'package:app/infra/ff1/tv_cast/tv_cast_api.dart';
import 'package:app/infra/ff1/tv_cast/tv_cast_dio.dart';
import 'package:app/infra/graphql/indexer_client_provider.dart';
import 'package:app/infra/services/address_service.dart';
import 'package:app/infra/services/address_sync_collection_service.dart';
import 'package:app/infra/services/bootstrap_service.dart';
import 'package:app/infra/services/canvas_client_service_v2.dart';
import 'package:app/infra/services/device_info_service.dart';
import 'package:app/infra/services/domain_address_service.dart';
import 'package:app/infra/services/favorite_playlist_service.dart';
import 'package:app/infra/services/force_update_service.dart';
import 'package:app/infra/services/indexer_service.dart';
import 'package:app/infra/services/indexer_service_isolate.dart';
import 'package:app/infra/services/indexer_sync_service.dart';
import 'package:app/infra/services/legacy_data_migration_service.dart';
import 'package:app/infra/services/personal_tokens_sync_service.dart';
import 'package:app/infra/services/remote_config_service.dart';
import 'package:app/infra/services/support_email_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';

// ignore_for_file: lines_longer_than_80_chars // Reason: provider documentation lines intentionally keep fully-qualified refs.

final _log = Logger('ServicesProvider');

/// Coordinates ensureTrackedAddresses sync triggered by ObjectBox. Tracks all
/// in-flight sync so [stopAndDrainForReset] can wait before DB is closed
/// (Forget I Exist).
class EnsureTrackedAddressesSyncCoordinatorNotifier extends Notifier<void> {
  bool _isStoppingForReset = false;
  final Set<Completer<void>> _inFlightCompleters = {};

  @override
  void build() {
    _isStoppingForReset = false;
  }

  /// Schedules ensure sync. Call from trackedAddressesSyncProvider subscription.
  void scheduleSync() {
    if (_isStoppingForReset) return;
    final ensureSync =
        ref.read(ensureTrackedAddressesHavePlaylistsAndResumeProvider);
    final completer = Completer<void>();
    _inFlightCompleters.add(completer);
    unawaited((() async {
      try {
        await ensureSync();
      } finally {
        _inFlightCompleters.remove(completer);
        if (!completer.isCompleted) completer.complete();
      }
    })());
  }

  /// Stops and waits for all in-flight ensure sync. Must complete before DB close.
  Future<void> stopAndDrainForReset() async {
    _isStoppingForReset = true;
    final completers = Set<Completer<void>>.from(_inFlightCompleters);
    if (completers.isNotEmpty) {
      _log.info(
        'EnsureTrackedAddressesSyncCoordinator: waiting for '
        '${completers.length} in-flight ensure sync(s)',
      );
      await Future.wait(completers.map((c) => c.future));
      _log.info(
        'EnsureTrackedAddressesSyncCoordinator: in-flight ensure sync completed',
      );
    }
  }
}

final ensureTrackedAddressesSyncCoordinatorProvider =
    NotifierProvider<EnsureTrackedAddressesSyncCoordinatorNotifier, void>(
      EnsureTrackedAddressesSyncCoordinatorNotifier.new,
    );

/// Provider for the AddressService.
/// Manages user wallet addresses and address-based playlists.
final addressServiceProvider = Provider<AddressService>((ref) {
  final databaseService = ref.watch(databaseServiceProvider);
  final indexerSyncService = ref.watch(indexerSyncServiceProvider);
  final domainAddressService = ref.watch(domainAddressServiceProvider);
  final personalTokensSyncService = ref.watch(
    personalTokensSyncServiceProvider,
  );
  final indexerServiceIsolate = ref.watch(indexerServiceIsolateProvider);

  final service = AddressService(
    databaseService: databaseService,
    indexerSyncService: indexerSyncService,
    domainAddressService: domainAddressService,
    personalTokensSyncService: personalTokensSyncService,
    indexerServiceIsolate: indexerServiceIsolate,
    appStateService: ref.watch(appStateServiceProvider),
  );

  service.setIndexingJobStatusCallback((response) {
    ref.read(addressIndexingJobProvider.notifier).updateJob(response);
  });

  return service;
});

/// Ensures tracked addresses have playlists and resumes indexing for
/// non-completed addresses. Runs bootstrap, creates missing playlists, then
/// delegates to [AddressService.resumeIndexingForAddresses].
///
/// Skips when [SeedDatabaseGate] not completed or [isSeedDatabaseReadyProvider]
/// is false (e.g. during seed replace or Forget I Exist).
final ensureTrackedAddressesHavePlaylistsAndResumeProvider =
    Provider<Future<void> Function()>((ref) {
  return () async {
    if (!SeedDatabaseGate.isCompleted) {
      _log.info(
        'ensureTrackedAddressesHavePlaylistsAndResume: seed database not completed',
      );
      return;
    }
    if (!ref.read(isSeedDatabaseReadyProvider)) {
      _log.info(
        'ensureTrackedAddressesHavePlaylistsAndResume: database not ready',
      );
      return;
    }
    _log.info(
      'ensureTrackedAddressesHavePlaylistsAndResume: running bootstrap',
    );
    await ref.read(bootstrapServiceProvider).bootstrap();
    final appState = ref.read(appStateServiceProvider);
    final walletAddresses = await appState.getTrackedWalletAddresses();
    _log.info(
      'ensureTrackedAddressesHavePlaylistsAndResume: tracked wallet addresses: '
      '${walletAddresses.length}',
    );
    if (walletAddresses.isEmpty) return;
    final normalizedAddresses = walletAddresses
        .map((wa) => wa.address.toNormalizedAddress())
        .toSet()
        .toList(growable: false);
    final databaseService = ref.read(databaseServiceProvider);
    final playlists = await databaseService.getAddressPlaylists();
    for (final wa in walletAddresses) {
      final normalized = wa.address.toNormalizedAddress();
      final hasPlaylist = playlists.any(
        (p) => p.ownerAddress?.toNormalizedAddress() == normalized,
      );
      if (hasPlaylist) continue;
      final playlist = PlaylistExt.fromWalletAddress(wa);
      await databaseService.ingestPlaylist(playlist);
      _log.info('Created playlist for tracked address: $normalized (name: ${wa.name})');
    }
    final statuses = await appState.getAllAddressIndexingStatuses();
    final toResume = <String>[];
    for (final addr in normalizedAddresses) {
      final status = statuses[addr];
      if (status == null) {
        await appState.setAddressIndexingStatus(
          address: addr,
          status: AddressIndexingProcessStatus.idle(),
        );
        toResume.add(addr);
      } else if (status.state != AddressIndexingProcessState.completed) {
        toResume.add(addr);
      }
    }
    if (toResume.isEmpty) return;
    _log.info(
      'ensureTrackedAddressesHavePlaylistsAndResume: resuming '
      '${toResume.length} address(es)',
    );
    await ref.read(addressServiceProvider).resumeIndexingForAddresses(toResume);
  };
});

/// Watches ObjectBox [TrackedAddressEntity]; on emit calls
/// [ensureTrackedAddressesSyncCoordinatorProvider]. Coordinator tracks in-flight
/// sync for drain (Forget I Exist).
final trackedAddressesSyncProvider = Provider<void>((ref) {
  ref.keepAlive();
  final coordinator =
      ref.read(ensureTrackedAddressesSyncCoordinatorProvider.notifier);
  final appStateService = ref.read(appStateServiceProvider);
  final sub = appStateService.watchTrackedAddressesAsWalletAddresses().listen((
    addresses,
  ) {
    _log.info(
      'trackedAddressesSyncProvider: list wallet addresses: '
      '${addresses.map((a) => a.address).toList()}',
    );
    coordinator.scheduleSync();
  });
  ref.onDispose(sub.cancel);
});

/// Provider for ENS/TNS address resolution and address/domain validation.
final domainAddressServiceProvider = Provider<DomainAddressService>((ref) {
  return DomainAddressService(
    resolverUrl: AppConfig.domainResolverUrl,
    resolverApiKey: AppConfig.domainResolverApiKey,
  );
});

/// Provider for the BootstrapService.
/// Handles initial app setup and data bootstrapping.
final bootstrapServiceProvider = Provider<BootstrapService>((ref) {
  final databaseService = ref.watch(databaseServiceProvider);
  return BootstrapService(databaseService: databaseService);
});

/// Provider for FavoritePlaylistService.
/// Manages user's Favorite playlist (starred works).
final favoritePlaylistServiceProvider = Provider<FavoritePlaylistService>((
  ref,
) {
  final databaseService = ref.watch(databaseServiceProvider);
  return FavoritePlaylistService(databaseService: databaseService);
});

/// Provider for composing support emails from the app.
final supportEmailServiceProvider = Provider<SupportEmailService>((ref) {
  final deviceInfoService = ref.watch(deviceInfoServiceProvider);
  FF1BluetoothDeviceService? ff1Service;
  try {
    ff1Service = ref.watch(ff1BluetoothDeviceServiceProvider);
  } on UnimplementedError {
    ff1Service = null;
  }
  return SupportEmailService(
    deviceInfoService: deviceInfoService,
    ff1DeviceService: ff1Service,
  );
});

/// Provider for [RemoteConfigService].
/// Fetches and caches app_update config from remote URL.
final remoteConfigServiceProvider = Provider<RemoteConfigService>((ref) {
  return RemoteConfigService();
});

/// Provider for [ForceUpdateService].
/// Checks app version against remote config and opens store for update.
final forceUpdateServiceProvider = Provider<ForceUpdateService>((ref) {
  return ForceUpdateService(
    remoteConfigService: ref.watch(remoteConfigServiceProvider),
  );
});

/// Provider for device identity (used by FF1 connect request).
final deviceInfoServiceProvider = Provider<DeviceInfoService>((ref) {
  return DeviceInfoService();
});

/// Provider for TvCast API (relayer cast endpoint).
/// Uses [createTvCastDio] (baseUrl, timeouts, API-KEY header from [AppConfig.ff1RelayerApiKey]).
final tvCastApiProvider = Provider<TvCastApi>((ref) {
  final dio = createTvCastDio();
  return TvCastApi(dio);
});

/// Provider for CanvasClientServiceV2 (cast and control FF1 devices).
final canvasClientServiceV2Provider = Provider<CanvasClientServiceV2>((ref) {
  final deviceInfoService = ref.watch(deviceInfoServiceProvider);
  final tvCastApi = ref.watch(tvCastApiProvider);
  return CanvasClientServiceV2(deviceInfoService, tvCastApi);
});

/// Provider for IndexerService (network-only).
final indexerServiceProvider = Provider<IndexerService>((ref) {
  final client = ref.watch(indexerClientProvider);
  return IndexerService(client: client);
});

/// Provider for IndexerServiceIsolate (runs indexer API in dedicated isolate).
final indexerServiceIsolateProvider = Provider<IndexerServiceIsolateOperations>(
  (ref) {
    final isolate = IndexerServiceIsolate(
      endpoint: AppConfig.indexerApiUrl,
      apiKey: AppConfig.indexerApiKey,
    );
    ref.onDispose(isolate.stop);
    return isolate;
  },
);

/// Provider for IndexerSyncService (fetch + local ingestion).
final indexerSyncServiceProvider = Provider<IndexerSyncService>((ref) {
  final indexerService = ref.watch(indexerServiceProvider);
  final databaseService = ref.watch(databaseServiceProvider);
  return IndexerSyncService(
    indexerService: indexerService,
    databaseService: databaseService,
  );
});

/// Provider for simple personal-token sync (no workers/scheduler).
final personalTokensSyncServiceProvider = Provider<PersonalTokensSyncService>((
  ref,
) {
  return PersonalTokensSyncService(
    indexerService: ref.watch(indexerServiceProvider),
    databaseService: ref.watch(databaseServiceProvider),
    appStateService: ref.watch(appStateServiceProvider),
  );
});

/// Provider for syncCollection-based address token updates.
final addressSyncCollectionServiceProvider =
    Provider<AddressSyncCollectionService>((ref) {
      return AddressSyncCollectionService(
        indexerService: ref.watch(indexerServiceProvider),
        databaseService: ref.watch(databaseServiceProvider),
        appStateService: ref.watch(appStateServiceProvider),
      );
    });

/// Provider for one-time legacy data migration service.
final legacyDataMigrationServiceProvider = Provider<LegacyDataMigrationService>(
  (ref) {
    final store = getInitializedObjectBoxStore();
    return LegacyDataMigrationService(
      localConfigBox: store.box<AppStateEntity>(),
      addressService: ref.watch(addressServiceProvider),
      bluetoothDeviceService: ref.watch(ff1BluetoothDeviceServiceProvider),
    );
  },
);
