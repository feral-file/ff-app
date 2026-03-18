import 'package:app/domain/models/models.dart';
import 'package:app/infra/config/app_state_service.dart';
import 'package:app/infra/database/app_database.dart';
import 'package:app/infra/database/database_service.dart';
import 'package:app/infra/database/seed_database_gate.dart';
import 'package:app/infra/graphql/indexer_client.dart';
import 'package:app/infra/services/address_service.dart';
import 'package:app/infra/services/domain_address_service.dart';
import 'package:app/infra/services/indexer_service.dart';
import 'package:app/infra/services/indexer_sync_service.dart';
import 'package:app/infra/services/personal_tokens_sync_service.dart';
import 'package:drift/native.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_indexer_service_isolate.dart';

class _FakeAppStateService implements AppStateServiceBase {
  _FakeAppStateService({List<String> initialTracked = const []})
      : _tracked = List.from(initialTracked);

  final List<String> _tracked;

  @override
  Future<List<String>> getTrackedPersonalAddresses() async =>
      List.unmodifiable(_tracked);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  setUpAll(() {
    dotenv.testLoad(fileInput: 'INDEXER_API_URL=https://example.invalid');
  });

  group('AddressService.isAddressAlreadyAdded', () {
    tearDown(SeedDatabaseGate.resetForTesting);

    test('checks getTrackedPersonalAddresses when address is in ObjectBox',
        () async {
      final fakeAppState = _FakeAppStateService(
        initialTracked: <String>['0x99fc8ad516fbcc9ba3123d56e63a35d05aa9efb8'],
      );

      final database = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);
      final databaseService = DatabaseService(database);

      final addressService = AddressService(
        databaseService: databaseService,
        indexerSyncService: IndexerSyncService(
          indexerService: IndexerService(
            client: IndexerClient(endpoint: 'https://example.invalid'),
          ),
          databaseService: databaseService,
        ),
        domainAddressService: DomainAddressService(
          resolverUrl: '',
          resolverApiKey: '',
        ),
        personalTokensSyncService: PersonalTokensSyncService(
          indexerService: IndexerService(
            client: IndexerClient(endpoint: 'https://example.invalid'),
          ),
          databaseService: databaseService,
          appStateService: fakeAppState,
        ),
        indexerServiceIsolate: FakeIndexerServiceIsolate(),
        appStateService: fakeAppState,
      );

      expect(
        await addressService.isAddressAlreadyAdded(
          address: '0x99fc8ad516fbcc9ba3123d56e63a35d05aa9efb8',
          chain: Chain.ethereum,
        ),
        isTrue,
      );
    });

    test('returns false when address is not in getTrackedPersonalAddresses',
        () async {
      SeedDatabaseGate.complete();

      final fakeAppState = _FakeAppStateService(initialTracked: <String>[]);

      final database = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);
      final databaseService = DatabaseService(database);

      final addressService = AddressService(
        databaseService: databaseService,
        indexerSyncService: IndexerSyncService(
          indexerService: IndexerService(
            client: IndexerClient(endpoint: 'https://example.invalid'),
          ),
          databaseService: databaseService,
        ),
        domainAddressService: DomainAddressService(
          resolverUrl: '',
          resolverApiKey: '',
        ),
        personalTokensSyncService: PersonalTokensSyncService(
          indexerService: IndexerService(
            client: IndexerClient(endpoint: 'https://example.invalid'),
          ),
          databaseService: databaseService,
          appStateService: fakeAppState,
        ),
        indexerServiceIsolate: FakeIndexerServiceIsolate(),
        appStateService: fakeAppState,
      );

      expect(
        await addressService.isAddressAlreadyAdded(
          address: '0x99fc8AD516FBCC9bA3123D56e63A35d05AA9EFB8',
          chain: Chain.ethereum,
        ),
        isFalse,
      );
    });

    test('treats Tezos addresses as case-sensitive', () async {
      SeedDatabaseGate.complete();

      final fakeAppState =
          _FakeAppStateService(initialTracked: <String>['tz1ABC']);

      final database = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);
      final databaseService = DatabaseService(database);

      final addressService = AddressService(
        databaseService: databaseService,
        indexerSyncService: IndexerSyncService(
          indexerService: IndexerService(
            client: IndexerClient(endpoint: 'https://example.invalid'),
          ),
          databaseService: databaseService,
        ),
        domainAddressService: DomainAddressService(
          resolverUrl: '',
          resolverApiKey: '',
        ),
        personalTokensSyncService: PersonalTokensSyncService(
          indexerService: IndexerService(
            client: IndexerClient(endpoint: 'https://example.invalid'),
          ),
          databaseService: databaseService,
          appStateService: fakeAppState,
        ),
        indexerServiceIsolate: FakeIndexerServiceIsolate(),
        appStateService: fakeAppState,
      );

      expect(
        await addressService.isAddressAlreadyAdded(
          address: 'TZ1ABC',
          chain: Chain.tezos,
        ),
        isFalse,
      );
    });
  });
}
