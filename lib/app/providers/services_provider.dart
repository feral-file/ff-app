import 'package:app/app/providers/indexer_provider.dart';
import 'package:app/infra/config/app_config.dart';
import 'package:app/infra/config/feed_config_store.dart';
import 'package:app/infra/database/database_provider.dart';
import 'package:app/infra/services/address_service.dart';
import 'package:app/infra/services/address_indexing_process_service.dart';
import 'package:app/infra/services/bootstrap_service.dart';
import 'package:app/infra/services/domain_address_service.dart';
import 'package:app/infra/services/feral_file_dp1_feed_service.dart';
import 'package:app/infra/services/support_email_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Provider for per-address index + sync process orchestration.
final addressIndexingProcessServiceProvider =
    Provider<AddressIndexingProcessService>((ref) {
      final indexerService = ref.watch(indexerServiceProvider);
      final indexerSyncService = ref.watch(indexerSyncServiceProvider);
      final feedConfigStore = ref.watch(feedConfigStoreProvider);
      return AddressIndexingProcessService(
        indexerService: indexerService,
        indexerSyncService: indexerSyncService,
        feedConfigStore: feedConfigStore,
      );
    });

/// Provider for the AddressService.
/// Manages user wallet addresses and address-based playlists.
final addressServiceProvider = Provider<AddressService>((ref) {
  final databaseService = ref.watch(databaseServiceProvider);
  final indexerSyncService = ref.watch(indexerSyncServiceProvider);
  final domainAddressService = ref.watch(domainAddressServiceProvider);
  final addressIndexingProcessService = ref.watch(
    addressIndexingProcessServiceProvider,
  );

  return AddressService(
    databaseService: databaseService,
    indexerSyncService: indexerSyncService,
    domainAddressService: domainAddressService,
    addressIndexingProcessService: addressIndexingProcessService,
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
  final indexerService = ref.watch(indexerServiceProvider);
  final feedConfigStore = ref.watch(feedConfigStoreProvider);

  return FeralFileDP1FeedService(
    baseUrl: AppConfig.dp1FeedUrl,
    isExternalFeedService: false,
    databaseService: databaseService,
    indexerService: indexerService,
    feedConfigStore: feedConfigStore,
    apiKey: AppConfig.dp1FeedApiKey,
  );
});

/// Provider for composing support emails from the app.
final supportEmailServiceProvider = Provider<SupportEmailService>((ref) {
  return SupportEmailService();
});
