import 'package:app/domain/constants/indexer_constants.dart';
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
  final List<String> trackedAddresses = [];
  final List<String> addTrackedAddressCalls = [];

  @override
  Future<void> setAddressIndexingStatus({
    required String address,
    required AddressIndexingProcessStatus status,
  }) async {}

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
  Future<int?> getPersonalTokensListFetchOffset(String address) async => null;

  @override
  Future<void> setPersonalTokensListFetchOffset({
    required String address,
    required int? nextFetchOffset,
  }) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakePersonalTokensSyncService implements PersonalTokensSyncService {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
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
  });

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
    },
  );
}
