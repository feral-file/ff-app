import 'package:app/domain/models/indexer/asset_token.dart';
import 'package:app/domain/models/indexer/workflow.dart';
import 'package:app/infra/services/indexer_service.dart';
import 'package:app/infra/workers/background_worker.dart';
import 'package:app/infra/workers/index_address_worker.dart';
import 'package:app/infra/workers/worker_state_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// In-memory fake for WorkerStateStore.
class _InMemoryWorkerStateStore implements WorkerStateStore {
  final Map<String, WorkerStateSnapshot> _rows =
      <String, WorkerStateSnapshot>{};

  @override
  Future<void> clearCheckpoint(String workerId) async {
    final current = _rows[workerId];
    _rows[workerId] = WorkerStateSnapshot(
      stateIndex: current?.stateIndex ?? BackgroundWorkerState.idle.index,
    );
  }

  @override
  Future<WorkerStateSnapshot?> load(String workerId) async => _rows[workerId];

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

  WorkerStateSnapshot? getSnapshot(String workerId) => _rows[workerId];
}

/// Fake IndexerService for testing.
class _FakeIndexerService implements IndexerService {
  _FakeIndexerService({
    this.tokensToReturn = const <AssetToken>[],
    this.shouldFailIndexing = false,
    this.shouldFailFetchTokens = false,
    this.indexingWorkflowStatus = IndexingJobStatus.completed,
  });

  final List<AssetToken> tokensToReturn;
  final bool shouldFailIndexing;
  final bool shouldFailFetchTokens;
  final IndexingJobStatus indexingWorkflowStatus;

  final List<String> indexedAddresses = <String>[];
  final List<String> fetchedAddresses = <String>[];

  @override
  Future<List<AddressIndexingResult>> indexAddressesList(
    List<String> addresses,
  ) async {
    if (shouldFailIndexing) {
      throw Exception('Indexing failed');
    }
    indexedAddresses.addAll(addresses);
    return addresses
        .map(
          (addr) => AddressIndexingResult(
            address: addr,
            workflowId: 'workflow_$addr',
          ),
        )
        .toList();
  }

  @override
  Future<AddressIndexingJobResponse> getAddressIndexingJobStatus({
    required String workflowId,
  }) async {
    return AddressIndexingJobResponse(
      workflowId: workflowId,
      address: 'test_address',
      status: indexingWorkflowStatus,
      totalTokensIndexed: 0,
      totalTokensViewable: 0,
    );
  }

  @override
  Future<List<AssetToken>> fetchTokensByAddresses({
    required List<String> addresses,
    int? limit,
    int? offset,
  }) async {
    if (shouldFailFetchTokens) {
      throw Exception('Fetch tokens failed');
    }
    fetchedAddresses.addAll(addresses);
    return tokensToReturn;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('IndexAddressWorker', () {
    late _InMemoryWorkerStateStore stateStore;

    setUp(() {
      stateStore = _InMemoryWorkerStateStore();
    });

    test('start() ignores existing checkpoint and starts fresh', () async {
      // Setup: Save old checkpoint with address queue
      await stateStore.save(
        workerId: 'index_address_worker::0xTEST',
        stateIndex: BackgroundWorkerState.paused.index,
        checkpoint: <String, dynamic>{
          'queue': <String>['0xOLD'],
        },
      );

      // Worker starts fresh (should not restore checkpoint on first start)
      final worker = IndexAddressWorker(
        workerId: 'index_address_worker::0xTEST',
        workerStateService: stateStore,
        indexerServiceFactory: _FakeIndexerService.new,
        databasePath: ':memory:',
        indexerEndpoint: 'http://test',
        indexerApiKey: '',
      );

      await worker.start();

      // Verify: Started with idle state, did NOT restore old queue
      expect(worker.state, BackgroundWorkerState.started);
      expect(worker.hasRemainingWork, false);
    });

    test('pause() stops processing and checkpoints queue', () async {
      final fakeService = _FakeIndexerService();
      final worker = IndexAddressWorker(
        workerId: 'index_address_worker::0xABC',
        workerStateService: stateStore,
        indexerServiceFactory: () => fakeService,
        databasePath: ':memory:',
        indexerEndpoint: 'http://test',
        indexerApiKey: '',
      );

      await worker.start();

      // Enqueue address
      await worker.enqueueAddress('0xABC');

      // Pause before completion
      await worker.pause();
      expect(worker.state, BackgroundWorkerState.paused);

      // Verify checkpoint saved with address in queue
      final snapshot = stateStore.getSnapshot('index_address_worker::0xABC');
      expect(snapshot, isNotNull);
      expect(snapshot!.checkpoint, isNotNull);
      expect(snapshot.checkpoint!['queue'], isA<List>());
    });

    test('start() after pause() restores checkpoint and resumes', () async {
      final fakeService = _FakeIndexerService();
      final worker = IndexAddressWorker(
        workerId: 'index_address_worker::0xABC',
        workerStateService: stateStore,
        indexerServiceFactory: () => fakeService,
        databasePath: ':memory:',
        indexerEndpoint: 'http://test',
        indexerApiKey: '',
      );

      await worker.start();
      await worker.enqueueAddress('0xABC');

      // Pause mid-work
      await worker.pause();

      // Restart and verify it resumes from checkpoint
      await worker.start();
      expect(worker.state, BackgroundWorkerState.started);
      expect(worker.hasRemainingWork, true);

      // Wait for work to complete
      await Future<void>.delayed(const Duration(milliseconds: 500));
    });

    test('stop() clears checkpoint and state completely', () async {
      final fakeService = _FakeIndexerService();
      final worker = IndexAddressWorker(
        workerId: 'index_address_worker::0xABC',
        workerStateService: stateStore,
        indexerServiceFactory: () => fakeService,
        databasePath: ':memory:',
        indexerEndpoint: 'http://test',
        indexerApiKey: '',
      );

      await worker.start();
      await worker.enqueueAddress('0xABC');

      await worker.stop();
      expect(worker.state, BackgroundWorkerState.stopped);

      // Verify checkpoint cleared
      final snapshot = stateStore.getSnapshot('index_address_worker::0xABC');
      expect(snapshot, isNotNull);
      expect(snapshot!.checkpoint, isNull);

      // Verify no remaining work
      expect(worker.hasRemainingWork, false);
    });

    test('spawns isolate on start and kills on stop', () async {
      final fakeService = _FakeIndexerService();
      final worker = IndexAddressWorker(
        workerId: 'index_address_worker::0xABC',
        workerStateService: stateStore,
        indexerServiceFactory: () => fakeService,
        databasePath: ':memory:',
        indexerEndpoint: 'http://test',
        indexerApiKey: '',
      );

      expect(worker.isIsolateRunning, false);

      await worker.start();
      expect(worker.isIsolateRunning, true);

      await worker.stop();
      expect(worker.isIsolateRunning, false);
    });

    test('enqueues multiple addresses and tracks pending work', () async {
      final fakeService = _FakeIndexerService(
        tokensToReturn: <AssetToken>[
          AssetToken(
            id: 1,
            cid: 'cid1',
            chain: 'ethereum',
            standard: 'ERC721',
            contractAddress: '0xContract',
            tokenNumber: '1',
          ),
        ],
      );

      final worker = IndexAddressWorker(
        workerId: 'index_address_worker::0xABC',
        workerStateService: stateStore,
        indexerServiceFactory: () => fakeService,
        databasePath: ':memory:',
        indexerEndpoint: 'http://test',
        indexerApiKey: '',
      );

      await worker.start();

      // Enqueue multiple addresses
      await worker.enqueueAddress('0xABC');
      await worker.enqueueAddress('0xDEF');

      expect(worker.hasRemainingWork, true);

      // Note: Actual isolate processing is integration-level testing
      // Unit tests verify queue management only
    });

    test('handles indexing failure gracefully', () async {
      final fakeService = _FakeIndexerService(shouldFailIndexing: true);
      final worker = IndexAddressWorker(
        workerId: 'index_address_worker::0xABC',
        workerStateService: stateStore,
        indexerServiceFactory: () => fakeService,
        databasePath: ':memory:',
        indexerEndpoint: 'http://test',
        indexerApiKey: '',
      );

      await worker.start();
      await worker.enqueueAddress('0xABC');

      // Wait for processing attempt
      await Future<void>.delayed(const Duration(milliseconds: 500));

      // Worker should still be running despite failure
      expect(worker.state, BackgroundWorkerState.started);
    });

    test('deduplicates addresses in queue', () async {
      final fakeService = _FakeIndexerService();
      final worker = IndexAddressWorker(
        workerId: 'index_address_worker::0xABC',
        workerStateService: stateStore,
        indexerServiceFactory: () => fakeService,
        databasePath: ':memory:',
        indexerEndpoint: 'http://test',
        indexerApiKey: '',
      );

      await worker.start();

      // Enqueue same address multiple times
      await worker.enqueueAddress('0xABC');
      expect(worker.hasRemainingWork, true);

      await worker.enqueueAddress('0xABC');
      await worker.enqueueAddress('0xABC');

      // Queue should still have work but deduplicated
      expect(worker.hasRemainingWork, true);

      // Note: Actual deduplication verification requires integration test
    });

    test('ignores new addresses when stopped', () async {
      final fakeService = _FakeIndexerService();
      final worker = IndexAddressWorker(
        workerId: 'index_address_worker::0xABC',
        workerStateService: stateStore,
        indexerServiceFactory: () => fakeService,
        databasePath: ':memory:',
        indexerEndpoint: 'http://test',
        indexerApiKey: '',
      );

      await worker.start();
      await worker.stop();
      await worker.enqueueAddress('0xDEF');

      expect(worker.hasRemainingWork, isFalse);
      final snapshot = stateStore.getSnapshot('index_address_worker::0xABC');
      expect(snapshot?.checkpoint, isNull);
    });
  });
}
