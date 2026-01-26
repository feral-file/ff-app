import 'package:app/infra/config/app_config.dart';
import 'package:app/infra/graphql/indexer_client.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';

/// Provider for the indexer GraphQL client.
/// Override this in tests with a fake/mock client.
final indexerClientProvider = Provider<IndexerClient>((ref) {
  final log = Logger('IndexerClientProvider');
  
  final endpoint = AppConfig.indexerApiUrl;
  final apiKey = AppConfig.indexerApiKey;
  
  if (endpoint.isEmpty) {
    log.warning('Indexer API URL not configured');
  }
  
  return IndexerClient(
    endpoint: endpoint,
    defaultHeaders: {
      'Content-Type': 'application/json',
      if (apiKey.isNotEmpty) 'Authorization': 'Bearer $apiKey',
    },
  );
});
