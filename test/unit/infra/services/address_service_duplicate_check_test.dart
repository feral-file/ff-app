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
import 'package:app/infra/services/pending_addresses_store.dart';
import 'package:app/infra/services/personal_tokens_sync_service.dart';
import 'package:drift/native.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_indexer_service_isolate.dart';

class _FakePendingAddressesStore extends PendingAddressesStore {
  _FakePendingAddressesStore({List<String>? initial}) : _stored = [...?initial];

  final List<String> _stored;

  @override
  Future<List<String>> getAddresses() async => List.unmodifiable(_stored);

  void addRaw(String address) => _stored.add(address);
}

class _FakePersonalTokensSyncService implements PersonalTokensSyncService {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeAppStateService implements AppStateServiceBase {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  setUpAll(() {
    dotenv.testLoad(fileInput: 'INDEXER_API_URL=https://example.invalid');
  });

  group('AddressService.isAddressAlreadyAdded', () {
    tearDown(SeedDatabaseGate.resetForTesting);

    test('checks PendingAddressesStore when seed gate is not open', () async {
      final pending = _FakePendingAddressesStore(
        initial: <String>[
          '0x99fc8AD516FBCC9bA3123D56e63A35d05AA9EFB8',
        ],
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
        personalTokensSyncService: _FakePersonalTokensSyncService(),
        pendingAddressesStore: pending,
        indexerServiceIsolate: FakeIndexerServiceIsolate(),
        appStateService: _FakeAppStateService(),
      );

      expect(
        await addressService.isAddressAlreadyAdded(
          address: '0x99fc8ad516fbcc9ba3123d56e63a35d05aa9efb8',
          chain: Chain.ethereum,
        ),
        isTrue,
      );
    });

    test('checks SQLite when seed gate is open', () async {
      SeedDatabaseGate.complete();

      final database = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);
      final databaseService = DatabaseService(database);

      await databaseService.ingestPlaylist(
        const Playlist(
          id: 'addr:ETH:0x99fc8ad516fbcc9ba3123d56e63a35d05aa9efb8',
          name: 'Existing',
          type: PlaylistType.addressBased,
          channelId: 'my_collection',
          ownerAddress: '0x99fc8ad516fbcc9ba3123d56e63a35d05aa9efb8',
          ownerChain: 'eth',
        ),
      );

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
        personalTokensSyncService: _FakePersonalTokensSyncService(),
        pendingAddressesStore: _FakePendingAddressesStore(),
        indexerServiceIsolate: FakeIndexerServiceIsolate(),
        appStateService: _FakeAppStateService(),
      );

      expect(
        await addressService.isAddressAlreadyAdded(
          address: '0x99fc8AD516FBCC9bA3123D56e63A35d05AA9EFB8',
          chain: Chain.ethereum,
        ),
        isTrue,
      );
    });

    test('treats Tezos addresses as case-sensitive', () async {
      SeedDatabaseGate.complete();

      final database = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);
      final databaseService = DatabaseService(database);

      await databaseService.ingestPlaylist(
        const Playlist(
          id: 'addr:TEZ:tz1ABC',
          name: 'Existing',
          type: PlaylistType.addressBased,
          channelId: 'my_collection',
          ownerAddress: 'tz1ABC',
          ownerChain: 'tez',
        ),
      );

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
        personalTokensSyncService: _FakePersonalTokensSyncService(),
        pendingAddressesStore: _FakePendingAddressesStore(),
        indexerServiceIsolate: FakeIndexerServiceIsolate(),
        appStateService: _FakeAppStateService(),
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
