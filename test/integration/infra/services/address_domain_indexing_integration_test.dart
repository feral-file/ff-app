import 'package:app/infra/config/app_config.dart';
import 'package:app/infra/graphql/indexer_client.dart';
import 'package:app/infra/services/domain_address_service.dart';
import 'package:app/infra/services/indexer_service.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/indexer_domain_integration_helpers.dart';
import '../../helpers/integration_test_harness.dart';

void main() {
  late IndexerService indexerService;
  late DomainAddressService domainAddressService;

  setUpAll(() async {
    await provisionIntegrationEnvFile();

    indexerService = IndexerService(
      client: IndexerClient(
        endpoint: AppConfig.indexerApiUrl,
        defaultHeaders: <String, String>{
          'Content-Type': 'application/json',
          if (AppConfig.indexerApiKey.isNotEmpty)
            'Authorization': 'ApiKey ${AppConfig.indexerApiKey}',
        },
      ),
    );

    domainAddressService = DomainAddressService(
      resolverUrl: AppConfig.domainResolverUrl,
      resolverApiKey: AppConfig.domainResolverApiKey,
    );
  });

  // Integration test: resolves ENS/TNS domains, triggers indexing, and verifies token availability.
  test(
    'indexes einstein-rosen ENS/TNS domains and fetches token pages',
    () async {
      expect(AppConfig.domainResolverUrl, isNotEmpty);
      expect(AppConfig.domainResolverApiKey, isNotEmpty);
      expect(AppConfig.indexerApiUrl, isNotEmpty);
      expect(AppConfig.indexerApiKey, isNotEmpty);

      final ensResolution = await domainAddressService.verifyAddressOrDomain(
        'einstein-rosen.eth',
      );
      final tnsResolution = await domainAddressService.verifyAddressOrDomain(
        'einstein-rosen.tez',
      );

      expect(ensResolution, isNotNull);
      expect(tnsResolution, isNotNull);

      final ensAddress = ensResolution!.address;
      final tnsAddress = tnsResolution!.address;

      await waitForAddressIndexingCompletion(
        indexerService: indexerService,
        address: ensAddress,
      );
      await waitForAddressIndexingCompletion(
        indexerService: indexerService,
        address: tnsAddress,
      );

      final ensTokens = await fetchAllTokensByOffsetCursor(
        indexerService: indexerService,
        address: ensAddress,
        maxPages: 40,
      );
      final tnsTokens = await fetchAllTokensByOffsetCursor(
        indexerService: indexerService,
        address: tnsAddress,
        maxPages: 40,
      );

      expect(
        ensTokens.length,
        greaterThan(100),
        reason: 'Expected >100 tokens for einstein-rosen.eth.',
      );
      expect(
        tnsTokens.length,
        greaterThan(20),
        reason: 'Expected >20 tokens for einstein-rosen.tez.',
      );
    },
    timeout: const Timeout(Duration(minutes: 20)),
  );
}
