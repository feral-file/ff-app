import 'package:app/infra/config/app_config.dart';
import 'package:app/infra/graphql/indexer_client.dart';
import 'package:app/infra/logging/structured_logger.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';

/// Provider for the indexer GraphQL client.
/// Override this in tests with a fake/mock client.
final indexerClientProvider = Provider<IndexerClient>((ref) {
  final log = Logger('IndexerClientProvider');
  final structuredLog = AppStructuredLog.forLogger(log);

  final endpoint = AppConfig.indexerApiUrl;
  final apiKey = AppConfig.indexerApiKey;

  if (endpoint.isEmpty) {
    structuredLog.warning(
      category: LogCategory.graphql,
      event: 'indexer_endpoint_missing',
      message: 'indexer API URL not configured',
    );
  }

  final authorization = apiKey.isEmpty ? null : 'ApiKey $apiKey';

  final client = IndexerClient(
    endpoint: endpoint,
    logger: log,
    defaultHeaders: {
      'Content-Type': 'application/json',
      'Authorization': ?authorization,
    },
  );

  ref.onDispose(client.dispose);
  return client;
});
