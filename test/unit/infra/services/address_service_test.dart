import 'package:app/domain/constants/indexer_constants.dart';
import 'package:app/domain/models/models.dart';
import 'package:app/domain/utils/address_deduplication.dart';
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
  final List<String> trackedAddresses = [];
  final List<String> addTrackedAddressCalls = [];
  final Map<String, int?> personalTokensOffsets = {};
  final List<int?> personalTokensOffsetWrites = [];
  final Map<String, AddressIndexingProcessStatus> indexingStatuses = {};

  String _key(String address) => address.toNormalizedAddress();

  @override
  Future<void> setAddressIndexingStatus({
    required String address,
    required AddressIndexingProcessStatus status,
  }) async {
    indexingStatuses[_key(address)] = status;
  }

  @override
  Future<void> addTrackedAddress(String address, {String alias = ''}) async {
    addTrackedAddressCalls.add(address);
    if (!trackedAddresses.contains(address)) {
      trackedAddresses.add(address);
    }
  }

  @override
  Future<List<String>> getTrackedPersonalAddresses() async =>
      List.unmodifiable(trackedAddresses);

  @override
  Stream<AddressIndexingProcessStatus?> watchAddressIndexingStatus(
    String address,
  ) => Stream.value(null);

  @override
  Future<int?> getPersonalTokensListFetchOffset(String address) async =>
      personalTokensOffsets[_key(address)];

  @override
  Future<void> setPersonalTokensListFetchOffset({
    required String address,
    required int? nextFetchOffset,
  }) async {
    final k = _key(address);
    personalTokensOffsetWrites.add(nextFetchOffset);
    if (nextFetchOffset == null) {
      personalTokensOffsets.remove(k);
    } else {
      personalTokensOffsets[k] = nextFetchOffset;
    }
  }

  @override
  Future<void> clearAllPersonalTokensListFetchOffsets() async {
    personalTokensOffsets.clear();
    personalTokensOffsetWrites.clear();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakePersonalTokensSyncService implements PersonalTokensSyncService {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Mirrors [AppStateService.setPersonalTokensListFetchOffset]: cursor writes
/// require a tracked address so stale sync work cannot recreate app-state rows
/// after [AppStateService.clearAddressState].
class _FakeAppStateServiceWithTrackedGuard extends _FakeAppStateService {
  @override
  Future<void> setPersonalTokensListFetchOffset({
    required String address,
    required int? nextFetchOffset,
  }) async {
    final k = _key(address);
    final hasTracked = trackedAddresses.any((a) => _key(a) == k);
    if (!hasTracked) {
      return;
    }
    await super.setPersonalTokensListFetchOffset(
      address: address,
      nextFetchOffset: nextFetchOffset,
    );
  }
}

void main() {
  late AppDatabase database;
  late DatabaseService databaseService;
  late AddressService addressService;
  late _FakeAppStateService fakeAppState;

  setUpAll(() {
    dotenv.testLoad(fileInput: 'INDEXER_API_URL=https://example.invalid');
  });

  setUp(() {
    SeedDatabaseGate.complete();

    database = AppDatabase.forTesting(NativeDatabase.memory());
    databaseService = DatabaseService(database);
    fakeAppState = _FakeAppStateService();

    final indexerSyncService = IndexerSyncService(
      indexerService: IndexerService(
        client: IndexerClient(endpoint: 'https://example.invalid'),
      ),
      databaseService: databaseService,
    );

    addressService = AddressService(
      databaseService: databaseService,
      indexerSyncService: indexerSyncService,
      domainAddressService: DomainAddressService(
        resolverUrl: '',
        resolverApiKey: '',
      ),
      personalTokensSyncService: _FakePersonalTokensSyncService(),
      indexerServiceIsolate: FakeIndexerServiceIsolate(),
      appStateService: fakeAppState,
    );
  });

  tearDown(() async {
    await database.close();
    SeedDatabaseGate.resetForTesting();
  });

  test('addAddress writes to ObjectBox and sets idle status', () async {
    final walletAddress = WalletAddress(
      address: '0x99fc8AD516FBCC9bA3123D56e63A35d05AA9EFB8',
      name: 'My Address',
      createdAt: DateTime.now(),
    );

    await addressService.addAddress(walletAddress: walletAddress);

    expect(fakeAppState.addTrackedAddressCalls, hasLength(1));
    expect(
      fakeAppState.addTrackedAddressCalls.single,
      equals('0x99fc8ad516fbcc9ba3123d56e63a35d05aa9efb8'),
    );
  });

  test(
    'syncTokens preserves persisted cursor when playlist itemCount is zero',
    () async {
      const addr = '0x99fc8ad516fbcc9ba3123d56e63a35d05aa9efb8';
      await databaseService.ingestPlaylist(
        const Playlist(
          id: 'addr:eth:0x99fc8ad516fbcc9ba3123d56e63a35d05aa9efb8',
          name: 'Personal',
          type: PlaylistType.addressBased,
          channelId: Channel.myCollectionId,
          ownerAddress: addr,
          ownerChain: 'eth',
        ),
      );
      fakeAppState.personalTokensOffsets[addr.toNormalizedAddress()] = 500;

      final fakeIsolate = FakeIndexerServiceIsolate()
        ..fetchTokensPageSequence = [
          const TokensPage(tokens: []),
        ];

      final indexerSyncService = IndexerSyncService(
        indexerService: IndexerService(
          client: IndexerClient(endpoint: 'https://example.invalid'),
        ),
        databaseService: databaseService,
      );

      final service = AddressService(
        databaseService: databaseService,
        indexerSyncService: indexerSyncService,
        domainAddressService: DomainAddressService(
          resolverUrl: '',
          resolverApiKey: '',
        ),
        personalTokensSyncService: _FakePersonalTokensSyncService(),
        indexerServiceIsolate: fakeIsolate,
        appStateService: fakeAppState,
      );

      await service.syncTokens(addr);
      expect(fakeIsolate.fetchTokensPageOffsets.single, 500);
      expect(
        fakeAppState.personalTokensOffsets[addr.toNormalizedAddress()],
        isNull,
      );
    },
  );

  test('syncTokens follows nextOffset until null', () async {
    final fakeIsolate = FakeIndexerServiceIsolate()
      ..fetchTokensPageSequence = [
        TokensPage(
          tokens: [
            AssetToken(
              id: 1,
              cid: 'cid1',
              chain: 'eip155:1',
              standard: 'ERC-721',
              contractAddress: '0xabc',
              tokenNumber: '1',
            ),
          ],
          nextOffset: 42,
        ),
        TokensPage(
          tokens: [
            AssetToken(
              id: 2,
              cid: 'cid2',
              chain: 'eip155:1',
              standard: 'ERC-721',
              contractAddress: '0xabc',
              tokenNumber: '2',
            ),
          ],
        ),
      ];

    final indexerSyncService = IndexerSyncService(
      indexerService: IndexerService(
        client: IndexerClient(endpoint: 'https://example.invalid'),
      ),
      databaseService: databaseService,
    );

    final service = AddressService(
      databaseService: databaseService,
      indexerSyncService: indexerSyncService,
      domainAddressService: DomainAddressService(
        resolverUrl: '',
        resolverApiKey: '',
      ),
      personalTokensSyncService: _FakePersonalTokensSyncService(),
      indexerServiceIsolate: fakeIsolate,
      appStateService: fakeAppState,
    );

    final total = await service.syncTokens('0xabc');
    expect(total, 2);
    expect(
      fakeIsolate.callSequence.where((e) => e == 'fetchTokens').length,
      2,
    );
    expect(
      fakeIsolate.fetchTokensPageLimits,
      equals(<int?>[indexerTokensPageSize, indexerTokensPageSize]),
    );
    expect(
      fakeIsolate.fetchTokensPageOffsets,
      equals(<int?>[0, 42]),
    );
    expect(fakeAppState.personalTokensOffsetWrites, equals(<int?>[42, null]));
  });

  test(
    'syncTokens resumes first request from persisted indexer cursor',
    () async {
    const addr = '0xabc';
    fakeAppState.personalTokensOffsets[addr.toNormalizedAddress()] = 500;

    final fakeIsolate = FakeIndexerServiceIsolate()
      ..fetchTokensPageSequence = [
        const TokensPage(tokens: []),
      ];

    final indexerSyncService = IndexerSyncService(
      indexerService: IndexerService(
        client: IndexerClient(endpoint: 'https://example.invalid'),
      ),
      databaseService: databaseService,
    );

    final service = AddressService(
      databaseService: databaseService,
      indexerSyncService: indexerSyncService,
      domainAddressService: DomainAddressService(
        resolverUrl: '',
        resolverApiKey: '',
      ),
      personalTokensSyncService: _FakePersonalTokensSyncService(),
      indexerServiceIsolate: fakeIsolate,
      appStateService: fakeAppState,
    );

    await service.syncTokens(addr);
    expect(fakeIsolate.fetchTokensPageOffsets.single, 500);
  });

  test(
    'syncTokens resume uses persisted cursor for mixed-case 0x (canonical key '
    'matches playlist / app state)',
    () async {
      const mixed = '0x49Fc8AD516FBCC9bA3123D56e63A35d05AA9EFB8';
      final canonical = mixed.toNormalizedAddress();
      fakeAppState.personalTokensOffsets[canonical] = 701;

      final fakeIsolate = FakeIndexerServiceIsolate()
        ..fetchTokensPageSequence = [
          const TokensPage(tokens: []),
        ];

      final indexerSyncService = IndexerSyncService(
        indexerService: IndexerService(
          client: IndexerClient(endpoint: 'https://example.invalid'),
        ),
        databaseService: databaseService,
      );

      final service = AddressService(
        databaseService: databaseService,
        indexerSyncService: indexerSyncService,
        domainAddressService: DomainAddressService(
          resolverUrl: '',
          resolverApiKey: '',
        ),
        personalTokensSyncService: _FakePersonalTokensSyncService(),
        indexerServiceIsolate: fakeIsolate,
        appStateService: fakeAppState,
      );

      await service.syncTokens(mixed);
      expect(fakeIsolate.fetchTokensPageOffsets.single, 701);
      expect(fakeIsolate.fetchTokensAddresses.single, <String>[canonical]);
    },
  );

  test(
    'syncTokens preserves persisted cursor when playlist is empty but resume '
    'cursor is valid',
    () async {
      const address = '0xabc';
      await databaseService.ingestPlaylist(
        const Playlist(
          id: 'addr:eth:0xabc',
          name: 'Personal',
          type: PlaylistType.addressBased,
          channelId: Channel.myCollectionId,
          ownerAddress: address,
          ownerChain: 'eth',
        ),
      );

      fakeAppState.personalTokensOffsets[address] = 42;

      final fakeIsolate = FakeIndexerServiceIsolate()
        ..fetchTokensPageSequence = [
          TokensPage(
            tokens: [
              AssetToken(
                id: 1,
                cid: 'cid1',
                chain: 'eip155:1',
                standard: 'ERC-721',
                contractAddress: '0xabc',
                tokenNumber: '1',
              ),
            ],
          ),
        ];

      final indexerSyncService = IndexerSyncService(
        indexerService: IndexerService(
          client: IndexerClient(endpoint: 'https://example.invalid'),
        ),
        databaseService: databaseService,
      );

      final service = AddressService(
        databaseService: databaseService,
        indexerSyncService: indexerSyncService,
        domainAddressService: DomainAddressService(
          resolverUrl: '',
          resolverApiKey: '',
        ),
        personalTokensSyncService: _FakePersonalTokensSyncService(),
        indexerServiceIsolate: fakeIsolate,
        appStateService: fakeAppState,
      );

      await service.syncTokens(address);

      expect(
        fakeIsolate.fetchTokensPageOffsets,
        equals(const <int?>[42]),
      );
    },
  );

  test(
    'syncTokens does not persist indexer cursor after address removed from '
    'tracking (mirrors AppStateService tracked guard)',
    () async {
      final guardedFake = _FakeAppStateServiceWithTrackedGuard();
      await guardedFake.addTrackedAddress('0xabc');
      guardedFake.trackedAddresses.clear();

      final fakeIsolate = FakeIndexerServiceIsolate()
        ..fetchTokensPageSequence = [
          const TokensPage(tokens: []),
        ];

      final indexerSyncService = IndexerSyncService(
        indexerService: IndexerService(
          client: IndexerClient(endpoint: 'https://example.invalid'),
        ),
        databaseService: databaseService,
      );

      final service = AddressService(
        databaseService: databaseService,
        indexerSyncService: indexerSyncService,
        domainAddressService: DomainAddressService(
          resolverUrl: '',
          resolverApiKey: '',
        ),
        personalTokensSyncService: _FakePersonalTokensSyncService(),
        indexerServiceIsolate: fakeIsolate,
        appStateService: guardedFake,
      );

      await service.syncTokens('0xabc');
      expect(guardedFake.personalTokensOffsets, isEmpty);
      expect(guardedFake.personalTokensOffsetWrites, isEmpty);
    },
  );

  test(
    'status writes are preserved before tracking while cursor writes stay '
    'guarded',
    () async {
      final guardedFake = _FakeAppStateServiceWithTrackedGuard();
      const address = '0xAbC';
      final normalized = address.toNormalizedAddress();

      await guardedFake.setAddressIndexingStatus(
        address: address,
        status: AddressIndexingProcessStatus.indexingTriggeredPending(),
      );
      await guardedFake.setPersonalTokensListFetchOffset(
        address: address,
        nextFetchOffset: 255,
      );

      expect(
        guardedFake.indexingStatuses[normalized]?.state,
        AddressIndexingProcessState.indexingTriggered,
        reason:
            'reset recovery writes status before the address is re-tracked',
      );
      expect(
        guardedFake.personalTokensOffsets,
        isEmpty,
        reason:
            'cursor writes stay guarded so stale sync work cannot recreate '
            'address state rows after tracking was removed',
      );
    },
  );

  test(
    'syncTokens continues when page has no tokens but nextOffset is set',
    () async {
      final fakeIsolate = FakeIndexerServiceIsolate()
        ..fetchTokensPageSequence = [
          const TokensPage(tokens: [], nextOffset: 7),
          TokensPage(
            tokens: [
              AssetToken(
                id: 1,
                cid: 'cid1',
                chain: 'eip155:1',
                standard: 'ERC-721',
                contractAddress: '0xabc',
                tokenNumber: '1',
              ),
            ],
          ),
        ];

      final indexerSyncService = IndexerSyncService(
        indexerService: IndexerService(
          client: IndexerClient(endpoint: 'https://example.invalid'),
        ),
        databaseService: databaseService,
      );

      final service = AddressService(
        databaseService: databaseService,
        indexerSyncService: indexerSyncService,
        domainAddressService: DomainAddressService(
          resolverUrl: '',
          resolverApiKey: '',
        ),
        personalTokensSyncService: _FakePersonalTokensSyncService(),
        indexerServiceIsolate: fakeIsolate,
        appStateService: fakeAppState,
      );

      final total = await service.syncTokens('0xabc');
      expect(total, 1);
      expect(
        fakeIsolate.callSequence.where((e) => e == 'fetchTokens').length,
        2,
      );
      expect(fakeIsolate.fetchTokensPageOffsets, equals(<int?>[0, 7]));
    },
  );
}
