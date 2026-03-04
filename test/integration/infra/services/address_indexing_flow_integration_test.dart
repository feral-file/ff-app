import 'package:app/infra/config/app_config.dart';
import 'package:app/infra/config/app_state_service.dart';
import 'package:app/infra/database/seed_database_gate.dart';
import 'package:app/infra/graphql/indexer_client.dart';
import 'package:app/infra/services/address_service.dart';
import 'package:app/infra/services/domain_address_service.dart';
import 'package:app/infra/services/indexer_service.dart';
import 'package:app/infra/services/indexer_service_isolate.dart';
import 'package:app/infra/services/indexer_sync_service.dart';
import 'package:app/infra/services/pending_addresses_store.dart';
import 'package:app/infra/services/personal_tokens_sync_service.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/integration_test_harness.dart';
import '../../helpers/spy_indexer_service_isolate.dart';

/// Migration integration test: verifies the add-address flow triggers
/// index → pullStatus → fetchTokens per [50-indexing-address-flow.mdc].
void main() {
  late IntegrationTestContext context;
  late AddressService addressService;
  late SpyIndexerServiceIsolate spyIsolate;

  setUpAll(() async {
    context = await createIntegrationTestContext();

    final realIsolate = IndexerServiceIsolate(
      endpoint: AppConfig.indexerApiUrl,
      apiKey: AppConfig.indexerApiKey,
    );
    spyIsolate = SpyIndexerServiceIsolate(delegate: realIsolate);

    final indexerService = IndexerService(
      client: IndexerClient(
        endpoint: AppConfig.indexerApiUrl,
        defaultHeaders: <String, String>{
          'Content-Type': 'application/json',
          if (AppConfig.indexerApiKey.isNotEmpty)
            'Authorization': 'ApiKey ${AppConfig.indexerApiKey}',
        },
      ),
    );

    addressService = AddressService(
      databaseService: context.databaseService,
      indexerSyncService: IndexerSyncService(
        indexerService: indexerService,
        databaseService: context.databaseService,
      ),
      domainAddressService: DomainAddressService(
        resolverUrl: AppConfig.domainResolverUrl,
        resolverApiKey: AppConfig.domainResolverApiKey,
      ),
      personalTokensSyncService: PersonalTokensSyncService(
        indexerService: indexerService,
        databaseService: context.databaseService,
        appStateService: _FakeAppStateService(),
      ),
      pendingAddressesStore: PendingAddressesStore(),
      indexerServiceIsolate: spyIsolate,
    );
  });

  tearDownAll(() async {
    SeedDatabaseGate.resetForTesting();
    await context.dispose();
  });

  test(
    'addAddressOrDomain einstein-rosen.eth triggers index→pullStatus→fetchTokens and ingests 100+ tokens',
    () async {
      expect(AppConfig.domainResolverUrl, isNotEmpty);
      expect(AppConfig.domainResolverApiKey, isNotEmpty);
      expect(AppConfig.indexerApiUrl, isNotEmpty);
      expect(AppConfig.indexerApiKey, isNotEmpty);

      const inputDomain = 'einstein-rosen.eth';
      final playlist = await addressService.addAddressOrDomain(
        value: inputDomain,
      );
      final resolvedAddress = playlist.ownerAddress!;

      // Poll until tokens in DB > 100 (indexing completes).
      const pollInterval = Duration(seconds: 5);
      const timeout = Duration(minutes: 20);
      final deadline = DateTime.now().add(timeout);
      int tokenCount = 0;

      while (DateTime.now().isBefore(deadline)) {
        final playlists =
            await context.databaseService.getAddressPlaylists();
        final match = playlists.where(
          (p) => p.ownerAddress?.toUpperCase() == resolvedAddress.toUpperCase(),
        ).toList();
        if (match.isNotEmpty) {
          tokenCount = match.first.itemCount ?? 0;
          if (tokenCount > 100) break;
        }
        await Future<void>.delayed(pollInterval);
      }

      expect(
        tokenCount,
        greaterThan(100),
        reason: 'Expected >100 tokens ingested for $inputDomain.',
      );

      // Verify call order: index before pullStatus before first fetchTokens.
      expect(spyIsolate.callSequence, contains('index'));
      expect(spyIsolate.callSequence, contains('pullStatus'));
      expect(spyIsolate.callSequence, contains('fetchTokens'));

      final indexPos = spyIsolate.callSequence.indexOf('index');
      final pullPos = spyIsolate.callSequence.indexOf('pullStatus');
      final fetchPos = spyIsolate.callSequence.indexOf('fetchTokens');

      expect(
        indexPos,
        lessThan(pullPos),
        reason: 'index must be called before pullStatus.',
      );
      expect(
        pullPos,
        lessThan(fetchPos),
        reason: 'pullStatus must be called before first fetchTokens.',
      );
    },
    timeout: const Timeout(Duration(minutes: 20)),
  );
}

class _FakeAppStateService implements AppStateServiceBase {
  final List<String> _tracked = <String>[];

  @override
  Future<void> trackPersonalAddress(String address) async {
    if (!_tracked.contains(address)) _tracked.add(address);
  }

  @override
  Future<List<String>> getTrackedPersonalAddresses() async =>
      List.unmodifiable(_tracked);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
