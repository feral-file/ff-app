import 'package:app/infra/config/app_config.dart';
import 'package:app/infra/config/feed_config_store.dart';
import 'package:app/infra/database/database_provider.dart';
import 'package:app/infra/graphql/indexer_client_provider.dart';
import 'package:app/infra/services/address_service.dart';
import 'package:app/infra/services/bootstrap_service.dart';
import 'package:app/infra/services/dp1_feed_service.dart';
import 'package:app/infra/services/indexer_service.dart';
import 'package:app/infra/services/indexer_sync_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Provider for the IndexerService.
/// Handles fetching tokens from the indexer API.
final indexerServiceProvider = Provider<IndexerService>((ref) {
  final client = ref.watch(indexerClientProvider);

  return IndexerService(
    client: client,
  );
});

/// Provider for the IndexerSyncService.
/// Orchestrates indexer fetch + local ingestion for address playlists.
final indexerSyncServiceProvider = Provider<IndexerSyncService>((ref) {
  final databaseService = ref.watch(databaseServiceProvider);
  final indexerService = ref.watch(indexerServiceProvider);

  return IndexerSyncService(
    indexerService: indexerService,
    databaseService: databaseService,
  );
});

/// Provider for the AddressService.
/// Manages user wallet addresses and address-based playlists.
final addressServiceProvider = Provider<AddressService>((ref) {
  final databaseService = ref.watch(databaseServiceProvider);
  final indexerService = ref.watch(indexerServiceProvider);
  final indexerSyncService = ref.watch(indexerSyncServiceProvider);

  return AddressService(
    databaseService: databaseService,
    indexerService: indexerService,
    indexerSyncService: indexerSyncService,
  );
});

/// Provider for the BootstrapService.
/// Handles initial app setup and data bootstrapping.
final bootstrapServiceProvider = Provider<BootstrapService>((ref) {
  final databaseService = ref.watch(databaseServiceProvider);

  return BootstrapService(
    databaseService: databaseService,
  );
});

/// Provider for the DP1FeedServiceImpl.
/// Fetches playlists from DP1 feed servers with cache policy support.
///
/// This provider is used by the default bootstrap flow (non-curated feeds).
/// For curated feeds with remote config channels, use FeralFileDP1FeedService
/// directly in FeedRegistryNotifier.
final dp1FeedServiceProvider = Provider<DP1FeedServiceImpl>((ref) {
  final databaseService = ref.watch(databaseServiceProvider);
  final indexerService = ref.watch(indexerServiceProvider);
  final feedConfigStore = ref.watch(feedConfigStoreProvider);

  return DP1FeedServiceImpl(
    baseUrl: AppConfig.dp1FeedUrl,
    databaseService: databaseService,
    indexerService: indexerService,
    feedConfigStore: feedConfigStore,
    apiKey: AppConfig.dp1FeedApiKey,
  );
});
