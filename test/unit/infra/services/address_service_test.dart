import 'package:app/domain/models/models.dart';
import 'package:app/infra/database/app_database.dart';
import 'package:app/infra/database/database_service.dart';
import 'package:app/infra/graphql/indexer_client.dart';
import 'package:app/infra/services/address_service.dart';
import 'package:app/infra/services/domain_address_service.dart';
import 'package:app/infra/services/indexer_service.dart';
import 'package:app/infra/services/indexer_sync_service.dart';
import 'package:app/infra/workers/worker_scheduler.dart';
import 'package:app/infra/workers/worker_state_service.dart';
import 'package:drift/native.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';

class _InMemoryWorkerStateStore implements WorkerStateStore {
  final Map<String, WorkerStateSnapshot> _rows =
      <String, WorkerStateSnapshot>{};

  @override
  Future<void> clearCheckpoint(String workerId) async {
    final current = _rows[workerId];
    if (current == null) {
      _rows[workerId] = const WorkerStateSnapshot(stateIndex: 0);
      return;
    }
    _rows[workerId] = WorkerStateSnapshot(stateIndex: current.stateIndex);
  }

  @override
  Future<WorkerStateSnapshot?> load(String workerId) async {
    return _rows[workerId];
  }

  @override
  Future<void> save({
    required String workerId,
    required int stateIndex,
    Map<String, dynamic>? checkpoint,
  }) async {
    _rows[workerId] = WorkerStateSnapshot(
      stateIndex: stateIndex,
      checkpoint: checkpoint,
    );
  }
}

class _DelayedWorkerScheduler extends WorkerScheduler {
  _DelayedWorkerScheduler({
    required this.delay,
    required super.databaseService,
    required super.workerStateService,
  }) : super(
         databasePathResolver: () async => '',
         indexerEndpoint: '',
         indexerApiKey: '',
         maxEnrichmentWorkers: 1,
       );

  final Duration delay;
  final List<String> addedAddresses = <String>[];

  @override
  Future<void> onAddressAdded(String address) async {
    addedAddresses.add(address);
    await Future<void>.delayed(delay);
  }
}

void main() {
  late AppDatabase database;
  late DatabaseService databaseService;
  late AddressService addressService;
  late _DelayedWorkerScheduler workerScheduler;

  setUpAll(() {
    dotenv.testLoad(fileInput: 'INDEXER_API_URL=https://example.invalid');
  });

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    databaseService = DatabaseService(database);

    workerScheduler = _DelayedWorkerScheduler(
      delay: const Duration(milliseconds: 350),
      databaseService: databaseService,
      workerStateService: _InMemoryWorkerStateStore(),
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
      workerScheduler: workerScheduler,
    );
  });

  tearDown(() async {
    await database.close();
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

      await pumpEventQueue();
      expect(workerScheduler.addedAddresses, hasLength(1));
      expect(
        workerScheduler.addedAddresses.first,
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
      expect(workerScheduler.addedAddresses, hasLength(1));
      expect(
        workerScheduler.addedAddresses.first,
        equals('0x99fc8AD516FBCC9bA3123D56e63A35d05AA9EFB8'),
      );
    },
  );
}
