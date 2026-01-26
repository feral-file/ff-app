import 'package:app/infra/config/app_config.dart';
import 'package:app/infra/database/database_provider.dart';
import 'package:app/infra/graphql/indexer_client_provider.dart';
import 'package:app/infra/services/address_service.dart';
import 'package:app/infra/services/bootstrap_service.dart';
import 'package:app/infra/services/dp1_feed_service.dart';
import 'package:app/infra/services/indexer_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Provider for the IndexerService.
/// Handles fetching tokens from the indexer API.
final indexerServiceProvider = Provider<IndexerService>((ref) {
  final client = ref.watch(indexerClientProvider);
  final databaseService = ref.watch(databaseServiceProvider);

  return IndexerService(
    client: client,
    databaseService: databaseService,
  );
});

/// Provider for the AddressService.
/// Manages user wallet addresses and address-based playlists.
final addressServiceProvider = Provider<AddressService>((ref) {
  final databaseService = ref.watch(databaseServiceProvider);
  final indexerService = ref.watch(indexerServiceProvider);

  return AddressService(
    databaseService: databaseService,
    indexerService: indexerService,
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

/// Provider for the DP1FeedService.
/// Fetches playlists from DP1 feed servers.
final dp1FeedServiceProvider = Provider<DP1FeedService>((ref) {
  final databaseService = ref.watch(databaseServiceProvider);
  final indexerService = ref.watch(indexerServiceProvider);

  return DP1FeedService(
    databaseService: databaseService,
    indexerService: indexerService,
    apiKey: AppConfig.dp1FeedApiKey,
  );
});
