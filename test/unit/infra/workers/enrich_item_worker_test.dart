import 'package:app/infra/database/database_service.dart';
import 'package:app/infra/workers/background_worker.dart';
import 'package:app/infra/workers/enrich_item_worker.dart';
import 'package:app/infra/workers/worker_message.dart';
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

/// Minimal fake DatabaseService for tests.
///
/// In unit tests the indexer HTTP call always fails (endpoint 'http://test'),
/// so the isolate sends workFailed and the DatabaseService methods are never
/// reached. This fake satisfies the constructor without requiring a real DB.
class _FakeDatabaseService implements DatabaseService {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('EnrichItemWorker', () {
    late _InMemoryWorkerStateStore stateStore;

    setUp(() {
      stateStore = _InMemoryWorkerStateStore();
    });

    test('pause() checkpoints in-flight assignment', () async {
      final worker = EnrichItemWorker(
        workerId: 'enrich_worker_1',
        workerStateService: stateStore,
        databaseService: _FakeDatabaseService(),
        indexerEndpoint: 'http://test',
        indexerApiKey: '',
      );

      await worker.start();

      final batch = <String, String>{'cid1': 'item1', 'cid2': 'item2'};
      await worker.enqueueAssignment(batch);

      await Future<void>.delayed(const Duration(milliseconds: 50));

      await worker.pause();

      final snapshot = stateStore.getSnapshot('enrich_worker_1');
      expect(snapshot, isNotNull);
      expect(snapshot!.checkpoint, isNotNull);
    });

    test('sends workComplete or workFailed after processing', () async {
      final messagesSent = <WorkerMessage>[];

      final worker = EnrichItemWorker(
        workerId: 'enrich_worker_1',
        workerStateService: stateStore,
        databaseService: _FakeDatabaseService(),
        indexerEndpoint: 'http://test',
        indexerApiKey: '',
        onMessageSent: messagesSent.add,
      );

      await worker.start();
      await worker.enqueueAssignment(<String, String>{'cid1': 'item1'});

      await Future<void>.delayed(const Duration(seconds: 1));

      // HTTP call to 'http://test' fails → isolate sends workFailed.
      final hasCompleteMessage = messagesSent.any(
        (msg) =>
            msg.opcode == WorkerOpcode.workComplete ||
            msg.opcode == WorkerOpcode.workFailed,
      );
      expect(hasCompleteMessage, true);
    });

    test('spawns isolate on start, kills on stop', () async {
      final worker = EnrichItemWorker(
        workerId: 'enrich_worker_1',
        workerStateService: stateStore,
        databaseService: _FakeDatabaseService(),
        indexerEndpoint: 'http://test',
        indexerApiKey: '',
      );

      expect(worker.isIsolateRunning, false);

      await worker.start();
      expect(worker.isIsolateRunning, true);

      await worker.stop();
      expect(worker.isIsolateRunning, false);
    });

    test('ignores new assignments when stopped', () async {
      final worker = EnrichItemWorker(
        workerId: 'enrich_worker_1',
        workerStateService: stateStore,
        databaseService: _FakeDatabaseService(),
        indexerEndpoint: 'http://test',
        indexerApiKey: '',
      );

      await worker.start();
      await worker.stop();
      await worker.enqueueAssignment(<String, String>{'cid1': 'item1'});

      expect(worker.hasRemainingWork, isFalse);
      final snapshot = stateStore.getSnapshot('enrich_worker_1');
      expect(snapshot?.checkpoint, isNull);
    });
  });
}
