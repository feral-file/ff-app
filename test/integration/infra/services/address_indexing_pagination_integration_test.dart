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

  // Integration test: resolves ENS to address, runs indexing, and validates offset-cursor pagination.
  test(
    'indexes reas.eth and paginates token pages without duplicate CIDs',
    () async {
      expect(
        AppConfig.domainResolverUrl,
        isNotEmpty,
        reason: 'DOMAIN_RESOLVER_URL must be set in .env for this test.',
      );
      expect(
        AppConfig.domainResolverApiKey,
        isNotEmpty,
        reason: 'DOMAIN_RESOLVER_API_KEY must be set in .env for this test.',
      );
      expect(
        AppConfig.indexerApiUrl,
        isNotEmpty,
        reason: 'INDEXER_API_URL must be set in .env for this test.',
      );
      expect(
        AppConfig.indexerApiKey,
        isNotEmpty,
        reason: 'INDEXER_API_KEY must be set in .env for this test.',
      );

      final resolved = await domainAddressService.verifyAddressOrDomain(
        'reas.eth',
      );
      expect(resolved, isNotNull, reason: 'Failed to resolve reas.eth');

      final address = resolved!.address;

      await waitForAddressIndexingCompletion(
        indexerService: indexerService,
        address: address,
      );

      final tokens = await fetchAllTokensByOffsetCursor(
        indexerService: indexerService,
        address: address,
      );

      expect(
        tokens.length,
        greaterThan(50),
        reason: 'Expected more than one page for reas.eth after indexing.',
      );
      expect(
        tokens.map((token) => token.cid).toSet().length,
        equals(tokens.length),
        reason: 'Expected no duplicate token CIDs across paginated pages.',
      );
    },
    timeout: const Timeout(Duration(minutes: 20)),
  );
}
