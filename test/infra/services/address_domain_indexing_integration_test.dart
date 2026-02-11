import 'package:app/domain/models/indexer/asset_token.dart';
import 'package:app/infra/config/app_config.dart';
import 'package:app/infra/graphql/indexer_client.dart';
import 'package:app/infra/services/domain_address_service.dart';
import 'package:app/infra/services/indexer_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// Integration test for ENS/TNS -> indexing -> wait -> token fetch pipeline.
///
/// Run with:
/// `flutter test test/infra/services/address_domain_indexing_integration_test.dart`
void main() {
  setUpAll(() async {
    await AppConfig.initialize();
  });

  group('Address domain indexing integration', () {
    late IndexerService indexerService;
    late DomainAddressService domainAddressService;

    setUp(() {
      final indexerClient = IndexerClient(
        endpoint: AppConfig.indexerApiUrl,
        defaultHeaders: {
          'Content-Type': 'application/json',
          if (AppConfig.indexerApiKey.isNotEmpty)
            'Authorization': 'ApiKey ${AppConfig.indexerApiKey}',
        },
      );
      indexerService = IndexerService(client: indexerClient);
      domainAddressService = DomainAddressService(
        resolverUrl: AppConfig.domainResolverUrl,
        resolverApiKey: AppConfig.domainResolverApiKey,
      );
    });

    test(
      'fetches >100 tokens for einstein-rosen.eth and einstein-rosen.tez '
      'after trigger+wait indexing flow',
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

        final ensResolution = await domainAddressService.verifyAddressOrDomain(
          'einstein-rosen.eth',
        );
        final tnsResolution = await domainAddressService.verifyAddressOrDomain(
          'einstein-rosen.tez',
        );

        expect(
          ensResolution,
          isNotNull,
          reason: 'Failed to resolve einstein-rosen.eth',
        );
        expect(
          tnsResolution,
          isNotNull,
          reason: 'Failed to resolve einstein-rosen.tez',
        );

        final ensAddress = ensResolution!.address;
        final tnsAddress = tnsResolution!.address;

        await _triggerAndWaitAddressIndexing(
          indexerService: indexerService,
          address: ensAddress,
        );
        await _triggerAndWaitAddressIndexing(
          indexerService: indexerService,
          address: tnsAddress,
        );

        final ensTokens = await _fetchAllTokensForAddress(
          indexerService: indexerService,
          address: ensAddress,
        );
        final tnsTokens = await _fetchAllTokensForAddress(
          indexerService: indexerService,
          address: tnsAddress,
        );

        expect(
          ensTokens.length,
          greaterThan(100),
          reason:
              'Expected >100 tokens from einstein-rosen.eth, '
              'got ${ensTokens.length}',
        );
        expect(
          tnsTokens.length,
          greaterThan(100),
          reason:
              'Expected >100 tokens from einstein-rosen.tez, '
              'got ${tnsTokens.length}',
        );
      },
      timeout: const Timeout(Duration(minutes: 20)),
    );
  });
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
      // Match old app behavior: transient status read failures are retried.
    }

    if (DateTime.now().difference(startedAt) > maxWait) {
      throw Exception(
        'Timed out waiting for indexing workflow $workflowId for $address',
      );
    }

    await Future<void>.delayed(const Duration(seconds: 5));
  }
}

Future<List<AssetToken>> _fetchAllTokensForAddress({
  required IndexerService indexerService,
  required String address,
  int pageSize = 50,
  int maxPages = 12,
}) async {
  final all = <AssetToken>[];
  var offset = 0;

  for (var page = 0; page < maxPages; page++) {
    final items = await indexerService.fetchTokensByAddresses(
      addresses: [address],
      limit: pageSize,
      offset: offset,
    );
    if (items.isEmpty) {
      break;
    }

    all.addAll(items);
    if (items.length < pageSize) {
      break;
    }
    offset += pageSize;
  }

  return all;
}
