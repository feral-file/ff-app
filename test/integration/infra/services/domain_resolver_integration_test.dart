import 'package:app/domain/models/address.dart';
import 'package:app/domain/models/models.dart';
import 'package:app/infra/config/app_config.dart';
import 'package:app/infra/services/domain_address_service.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/integration_test_harness.dart';

void main() {
  late DomainAddressService domainAddressService;

  setUpAll(() async {
    await provisionIntegrationEnvFile();

    domainAddressService = DomainAddressService(
      resolverUrl: AppConfig.domainResolverUrl,
      resolverApiKey: AppConfig.domainResolverApiKey,
    );
  });

  // Integration test: resolves real ENS and TNS domains via the domain resolver API.
  test(
    'resolves einstein-rosen ENS/TNS domains into valid addresses',
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

      final ensResolution = await domainAddressService.verifyAddressOrDomain(
        'einstein-rosen.eth',
      );
      final tnsResolution = await domainAddressService.verifyAddressOrDomain(
        'einstein-rosen.tez',
      );

      expect(ensResolution, isNotNull);
      expect(ensResolution!.type, equals(Chain.ethereum));
      expect(
        ensResolution.address,
        startsWith('0x'),
        reason: 'ENS should resolve to a checksummed Ethereum address.',
      );

      expect(tnsResolution, isNotNull);
      expect(tnsResolution!.type, equals(Chain.tezos));
      expect(
        RegExp(r'^tz[1-3][1-9A-HJ-NP-Za-km-z]{33}$').hasMatch(
          tnsResolution.address,
        ),
        isTrue,
        reason: 'TNS should resolve to a valid Tezos address.',
      );
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
