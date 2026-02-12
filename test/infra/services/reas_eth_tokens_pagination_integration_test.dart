import 'package:app/domain/models/indexer/asset_token.dart';
import 'package:app/infra/config/app_config.dart';
import 'package:app/infra/graphql/indexer_client.dart';
import 'package:app/infra/services/domain_address_service.dart';
import 'package:app/infra/services/indexer_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// Integration test for spec-correct token pagination using TokenList.offset.
///
/// Run with:
/// `flutter test test/infra/services/reas_eth_tokens_pagination_integration_test.dart`
void main() {
  setUpAll(() async {
    await AppConfig.initialize();
  });

  test(
    'fetches all tokens for reas.eth using TokenList.offset pagination',
    () async {
      expect(
        AppConfig.domainResolverUrl,
        isNotEmpty,
        reason: 'DOMAIN_RESOLVER_URL must be set in .env for this test',
      );
      expect(
        AppConfig.domainResolverApiKey,
        isNotEmpty,
        reason: 'DOMAIN_RESOLVER_API_KEY must be set in .env for this test',
      );
      expect(
        AppConfig.indexerApiUrl,
        isNotEmpty,
        reason: 'INDEXER_API_URL must be set in .env for this test',
      );
      expect(
        AppConfig.indexerApiKey,
        isNotEmpty,
        reason: 'INDEXER_API_KEY must be set in .env for this test',
      );

      final indexerService = IndexerService(
        client: IndexerClient(
          endpoint: AppConfig.indexerApiUrl,
          defaultHeaders: {
            'Content-Type': 'application/json',
            if (AppConfig.indexerApiKey.isNotEmpty)
              'Authorization': 'ApiKey ${AppConfig.indexerApiKey}',
          },
        ),
      );
      final domainAddressService = DomainAddressService(
        resolverUrl: AppConfig.domainResolverUrl,
        resolverApiKey: AppConfig.domainResolverApiKey,
      );

      final resolved = await domainAddressService.verifyAddressOrDomain(
        'reas.eth',
      );
      expect(resolved, isNotNull, reason: 'Failed to resolve reas.eth');
      final address = resolved!.address;

      await _triggerAndWaitAddressIndexing(
        indexerService: indexerService,
        address: address,
      );

      final tokens = await _fetchAllTokensByOffsetCursor(
        indexerService: indexerService,
        address: address,
      );

      expect(
        tokens.length,
        greaterThan(50),
        reason: 'Expected more than one page for reas.eth',
      );
      expect(
        tokens.map((t) => t.cid).toSet().length,
        equals(tokens.length),
        reason: 'Expected no duplicate token CIDs across paginated pages',
      );
    },
    timeout: const Timeout(Duration(minutes: 20)),
  );
}

Future<void> _triggerAndWaitAddressIndexing({
  required IndexerService indexerService,
  required String address,
}) async {
  final results = await indexerService.indexAddressesList([address]);
  final result = results.firstWhere(
    (e) => e.address == address,
    orElse: () =>
        throw Exception('Indexer did not return workflow for $address'),
  );

  final workflowId = result.workflowId;
  if (workflowId.isEmpty) {
    throw Exception('Empty workflowId for $address');
  }

  final startedAt = DateTime.now();
  const maxWait = Duration(minutes: 15);

  while (true) {
    try {
      final status = await indexerService.getAddressIndexingJobStatus(
        workflowId: workflowId,
      );
      if (status.status.isDone) {
        if (!status.status.isSuccess) {
          throw Exception(
            'Indexing finished with ${status.status.name} for $address',
          );
        }
        return;
      }
    } on Object {
      // Match existing integration behavior: retry transient read failures.
    }

    if (DateTime.now().difference(startedAt) > maxWait) {
      throw Exception(
        'Timed out waiting for indexing workflow $workflowId for $address',
      );
    }

    await Future<void>.delayed(const Duration(seconds: 5));
  }
}

Future<List<AssetToken>> _fetchAllTokensByOffsetCursor({
  required IndexerService indexerService,
  required String address,
  int pageSize = 50,
  int maxPages = 100,
}) async {
  final all = <AssetToken>[];
  int? nextOffset = 0;

  for (var page = 0; page < maxPages; page++) {
    final response = await indexerService.fetchTokensPageByAddresses(
      addresses: [address],
      limit: pageSize,
      offset: nextOffset,
    );
    if (response.tokens.isEmpty) {
      break;
    }

    all.addAll(response.tokens);
    if (response.nextOffset == null) {
      return all;
    }
    nextOffset = response.nextOffset;
  }

  throw Exception('Pagination did not terminate within $maxPages pages');
}
