import 'package:app/app/providers/ff1_bluetooth_device_providers.dart';
import 'package:app/infra/config/app_config.dart';
import 'package:app/infra/config/app_state_service.dart';
import 'package:app/infra/database/database_provider.dart'
    hide ff1BluetoothDeviceServiceProvider;
import 'package:app/infra/database/objectbox_init.dart';
import 'package:app/infra/database/objectbox_models.dart';
import 'package:app/infra/ff1/tv_cast/tv_cast_api.dart';
import 'package:app/infra/ff1/tv_cast/tv_cast_dio.dart';
import 'package:app/infra/graphql/indexer_client_provider.dart';
import 'package:app/infra/services/address_service.dart';
import 'package:app/infra/services/bootstrap_service.dart';
import 'package:app/infra/services/canvas_client_service_v2.dart';
import 'package:app/infra/services/device_info_service.dart';
import 'package:app/infra/services/domain_address_service.dart';
import 'package:app/infra/services/feral_file_dp1_feed_service.dart';
import 'package:app/infra/services/force_update_service.dart';
import 'package:app/infra/services/indexer_service.dart';
import 'package:app/infra/services/indexer_sync_service.dart';
import 'package:app/infra/services/legacy_data_migration_service.dart';
import 'package:app/infra/services/pending_addresses_store.dart';
import 'package:app/infra/services/personal_tokens_sync_service.dart';
import 'package:app/infra/services/remote_config_service.dart';
import 'package:app/infra/services/support_email_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// ignore_for_file: lines_longer_than_80_chars // Reason: provider documentation lines intentionally keep fully-qualified refs.

/// Provider for [PendingAddressesStore].
///
/// Stores wallet addresses added before the Drift DB is ready (fresh install
/// while the seed database is still downloading).
final pendingAddressesStoreProvider = Provider<PendingAddressesStore>((ref) {
  return PendingAddressesStore();
});

/// Provider for the AddressService.
/// Manages user wallet addresses and address-based playlists.
final addressServiceProvider = Provider<AddressService>((ref) {
  final databaseService = ref.watch(databaseServiceProvider);
  final indexerSyncService = ref.watch(indexerSyncServiceProvider);
  final domainAddressService = ref.watch(domainAddressServiceProvider);
  final personalTokensSyncService = ref.watch(
    personalTokensSyncServiceProvider,
  );
  final pendingAddressesStore = ref.watch(pendingAddressesStoreProvider);

  return AddressService(
    databaseService: databaseService,
    indexerSyncService: indexerSyncService,
    domainAddressService: domainAddressService,
    personalTokensSyncService: personalTokensSyncService,
    pendingAddressesStore: pendingAddressesStore,
  );
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

/// Provider for the DP1FeedServiceImpl.
/// Fetches playlists from DP1 feed servers with cache policy support.
final dp1FeedServiceProvider = Provider<FeralFileDP1FeedService>((ref) {
  final databaseService = ref.watch(databaseServiceProvider);
  final appStateService = ref.watch(appStateServiceProvider);

  return FeralFileDP1FeedService(
    baseUrl: AppConfig.dp1FeedUrl,
    databaseService: databaseService,
    appStateService: appStateService,
    apiKey: AppConfig.dp1FeedApiKey,
  );
});

/// Provider for composing support emails from the app.
final supportEmailServiceProvider = Provider<SupportEmailService>((ref) {
  return SupportEmailService();
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
  return CanvasClientServiceV2(
    deviceInfoService,
    tvCastApi,
    dp1FeedBaseUrl: AppConfig.dp1FeedUrl,
  );
});

/// Provider for IndexerService (network-only).
final indexerServiceProvider = Provider<IndexerService>((ref) {
  final client = ref.watch(indexerClientProvider);
  return IndexerService(client: client);
});

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
