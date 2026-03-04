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
  final List<String> stored = <String>[];

  @override
  Future<List<String>> getAddresses() async => List.unmodifiable(stored);

  @override
  Future<void> addAddress(String address) async {
    if (!stored.any((a) => a.toLowerCase() == address.toLowerCase())) {
      stored.add(address);
    }
  }

  @override
  Future<void> clear() async => stored.clear();
}

class _FakeAppStateService implements AppStateService {
  @override
  Future<void> setAddressIndexingStatus({
    required String address,
    required AddressIndexingProcessStatus status,
  }) async {}

  @override
  Stream<AddressIndexingProcessStatus?> watchAddressIndexingStatus(
    String address,
  ) =>
      Stream.value(null);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _DelayedPersonalTokensSyncService extends PersonalTokensSyncService {
  _DelayedPersonalTokensSyncService({
    required this.delay,
    required super.databaseService,
  }) : super(
         indexerService: IndexerService(
           client: IndexerClient(endpoint: 'https://example.invalid'),
         ),
         appStateService: _FakeAppStateService(),
       );

  final Duration delay;
  final List<String> addedAddresses = <String>[];
  int syncCalls = 0;

  @override
  Future<void> trackAddress(String address) async {
    addedAddresses.add(address);
    await Future<void>.delayed(delay);
  }

  @override
  Future<void> syncAddresses({required List<String> addresses}) async {
    syncCalls += 1;
  }
}

void main() {
  late AppDatabase database;
  late DatabaseService databaseService;
  late AddressService addressService;
  late _DelayedPersonalTokensSyncService personalTokensSyncService;

  setUpAll(() {
    dotenv.testLoad(fileInput: 'INDEXER_API_URL=https://example.invalid');
  });

  setUp(() {
    // The gate must be open so AddressService uses the normal SQLite path.
    SeedDatabaseGate.complete();

    database = AppDatabase.forTesting(NativeDatabase.memory());
    databaseService = DatabaseService(database);

    personalTokensSyncService = _DelayedPersonalTokensSyncService(
      delay: const Duration(milliseconds: 350),
      databaseService: databaseService,
    );

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
      personalTokensSyncService: personalTokensSyncService,
      pendingAddressesStore: _FakePendingAddressesStore(),
      indexerServiceIsolate: FakeIndexerServiceIsolate(),
      appStateService: _FakeAppStateService(),
    );
  });

  tearDown(() async {
    await database.close();
    // Reset the gate for subsequent test files in the same process.
    SeedDatabaseGate.resetForTesting();
  });

  test(
    'addAddress with syncNow false waits for objectbox tracking and skips sync',
    () async {
      final walletAddress = WalletAddress(
        address: '0x99fc8AD516FBCC9bA3123D56e63A35d05AA9EFB8',
        name: 'My Address',
        createdAt: DateTime.now(),
      );

      final stopwatch = Stopwatch()..start();
      await addressService.addAddress(
        walletAddress: walletAddress,
        syncNow: false,
      );
      stopwatch.stop();

      expect(stopwatch.elapsedMilliseconds, greaterThanOrEqualTo(300));
      expect(personalTokensSyncService.addedAddresses, hasLength(1));
      expect(personalTokensSyncService.syncCalls, equals(0));
    },
  );
}
