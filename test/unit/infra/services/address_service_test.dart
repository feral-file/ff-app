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
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _DelayedPersonalTokensSyncService extends PersonalTokensSyncService {
  _DelayedPersonalTokensSyncService({
    required this.delay,
  }) : super(
         indexerService: IndexerService(
           client: IndexerClient(endpoint: 'https://example.invalid'),
         ),
         databaseService: DatabaseService(
           AppDatabase.forTesting(NativeDatabase.memory()),
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
    );
  });

  tearDown(() async {
    await database.close();
    // Reset the gate for subsequent test files in the same process.
    SeedDatabaseGate.resetForTesting();
  });

  test(
    'addAddress persists playlist without waiting for worker scheduling',
    () async {
      final walletAddress = WalletAddress(
        address: '0x99fc8AD516FBCC9bA3123D56e63A35d05AA9EFB8',
        name: 'My Address',
        createdAt: DateTime.now(),
      );

      final stopwatch = Stopwatch()..start();
      final playlist = await addressService.addAddress(
        walletAddress: walletAddress,
      );
      stopwatch.stop();

      expect(stopwatch.elapsedMilliseconds, lessThan(300));
      expect(
        playlist.ownerAddress,
        equals('0x99fc8ad516fbcc9ba3123d56e63a35d05aa9efb8'),
      );

      final playlists = await databaseService.getAddressPlaylists();
      expect(playlists, hasLength(1));
      expect(playlists.first.ownerAddress, equals(playlist.ownerAddress));

      await Future<void>.delayed(const Duration(milliseconds: 400));
      expect(personalTokensSyncService.addedAddresses, hasLength(1));
      expect(
        personalTokensSyncService.addedAddresses.first,
        equals('0x99fc8AD516FBCC9bA3123D56e63A35d05AA9EFB8'),
      );
    },
  );

  test(
    'addAddress existing playlist returns quickly and still schedules worker',
    () async {
      final walletAddress = WalletAddress(
        address: '0x99fc8AD516FBCC9bA3123D56e63A35d05AA9EFB8',
        name: 'My Address',
        createdAt: DateTime.now(),
      );

      await databaseService.ingestPlaylist(
        const Playlist(
          id: 'addr:eth:0x99fc8ad516fbcc9ba3123d56e63a35d05aa9efb8',
          name: 'Existing',
          type: PlaylistType.addressBased,
          channelId: 'my_collection',
          ownerAddress: '0x99fc8ad516fbcc9ba3123d56e63a35d05aa9efb8',
          ownerChain: 'eth',
        ),
      );

      final stopwatch = Stopwatch()..start();
      final playlist = await addressService.addAddress(
        walletAddress: walletAddress,
      );
      stopwatch.stop();

      expect(stopwatch.elapsedMilliseconds, lessThan(300));
      expect(
        playlist.id,
        equals('addr:eth:0x99fc8ad516fbcc9ba3123d56e63a35d05aa9efb8'),
      );

      await pumpEventQueue();
      expect(personalTokensSyncService.addedAddresses, hasLength(1));
      expect(
        personalTokensSyncService.addedAddresses.first,
        equals('0x99fc8AD516FBCC9bA3123D56e63A35d05AA9EFB8'),
      );
    },
  );

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
