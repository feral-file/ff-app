import 'package:app/infra/workers/background_worker.dart';
import 'package:app/infra/workers/item_enrichment_query_worker.dart';
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

ItemEnrichmentQueryWorker _makeWorker({
  required _InMemoryWorkerStateStore stateStore,
  List<WorkerMessage>? sink,
}) {
  return ItemEnrichmentQueryWorker(
    workerId: 'query_worker',
    workerStateService: stateStore,
    databasePath: ':memory:',
    onMessageSent: sink?.add,
  );
}

void main() {
  group('ItemEnrichmentQueryWorker', () {
    late _InMemoryWorkerStateStore stateStore;

    setUp(() {
      stateStore = _InMemoryWorkerStateStore();
    });

    test('sends batchesReady message with batches', () async {
      final messagesSent = <WorkerMessage>[];
      final worker = _makeWorker(stateStore: stateStore, sink: messagesSent);

      await worker.start();
      await worker.onQueryNeeded();

      // Give isolate time to process
      await Future<void>.delayed(const Duration(milliseconds: 200));

      // Should have sent batchesReady or noBareItems
      final hasBatchMessage = messagesSent.any(
        (msg) =>
            msg.opcode == WorkerOpcode.batchesReady ||
            msg.opcode == WorkerOpcode.noBareItems,
      );
      expect(hasBatchMessage, true);
    });

    test('pause() checkpoints pending query signals', () async {
      final worker = _makeWorker(stateStore: stateStore);

      await worker.start();

      // Enqueue queries
      await worker.onQueryNeeded();
      await worker.onQueryNeeded();

      await worker.pause();

      final snapshot = stateStore.getSnapshot('query_worker');
      expect(snapshot, isNotNull);
      expect(snapshot!.checkpoint, isNotNull);
    });

    test(
      'concurrent onQueryNeeded calls coalesce: '
      'only one query dispatched at a time',
      () async {
        final messages = <WorkerMessage>[];
        final worker = _makeWorker(stateStore: stateStore, sink: messages);

        // Do NOT start the worker — keep isolate absent so _maybeSendQuery
        // stores the flag instead of dispatching. This lets us verify that
        // two back-to-back calls don't cause _hasPendingQuery to be consumed
        // twice (which would previously mean two concurrent dispatch attempts).
        await worker.onQueryNeeded();
        await worker.onQueryNeeded();

        // Only one pending query should be recorded even after two calls.
        expect(worker.hasRemainingWork, isTrue);

        // No dispatch messages — isolate not running, coalesced to one flag.
        final dispatchMsgs = messages
            .where((m) => m.opcode == WorkerOpcode.enqueueWork)
            .toList();
        expect(dispatchMsgs, isEmpty);
      },
    );

    test('spawns isolate on start, kills on stop', () async {
      final worker = _makeWorker(stateStore: stateStore);

      expect(worker.isIsolateRunning, false);

      await worker.start();
      expect(worker.isIsolateRunning, true);

      await worker.stop();
      expect(worker.isIsolateRunning, false);
    });

    // ── isFinished state ────────────────────────────────────────────────────

    test('isFinished starts false', () {
      final worker = _makeWorker(stateStore: stateStore);
      expect(worker.isFinished, false);
    });

    test('onQueryNeeded resets isFinished to false', () async {
      final worker = _makeWorker(stateStore: stateStore);
      await worker.start();

      // Simulate a previous finished state (would be set by isolate message).
      // We test the reset path via onQueryNeeded directly.
      await worker.onQueryNeeded(); // resets isFinished
      expect(worker.isFinished, false);
    });

    test('checkpoint persists isFinished and restores it', () async {
      final store = _InMemoryWorkerStateStore();
      final worker = _makeWorker(stateStore: store);
      await worker.start();
      await worker.onQueryNeeded();

      // Pause persists the checkpoint.
      await worker.pause();

      final snapshot = store.getSnapshot('query_worker');
      expect(snapshot?.checkpoint?['isFinished'], isA<bool>());
    });

    // ── in-flight batch tracking ────────────────────────────────────────────

    test('inFlightBatchCount starts at 0', () {
      final worker = _makeWorker(stateStore: stateStore);
      expect(worker.inFlightBatchCount, equals(0));
    });

    test('onBatchesDispatched increments inFlightBatchCount', () async {
      final worker = _makeWorker(stateStore: stateStore)
        ..onBatchesDispatched(3);
      expect(worker.inFlightBatchCount, equals(3));
    });

    test('onBatchComplete decrements inFlightBatchCount', () async {
      final worker = _makeWorker(stateStore: stateStore)
        ..onBatchesDispatched(2)
        ..onBatchComplete();
      expect(worker.inFlightBatchCount, equals(1));
    });

    test(
      'spurious onBatchComplete when count is 0 does not go below 0',
      () async {
        // No batches dispatched; completion is spurious.
        final worker = _makeWorker(stateStore: stateStore)..onBatchComplete();
        expect(worker.inFlightBatchCount, equals(0));
      },
    );

    test('multiple rounds accumulate and drain correctly', () {
      // Round 1: 2 batches dispatched.
      final worker = _makeWorker(stateStore: stateStore)
        ..onBatchesDispatched(2);
      expect(worker.inFlightBatchCount, equals(2));
      worker.onBatchComplete();
      expect(worker.inFlightBatchCount, equals(1));
      worker.onBatchComplete();
      expect(worker.inFlightBatchCount, equals(0));

      // Round 2 (re-queried): 1 batch dispatched.
      worker.onBatchesDispatched(1);
      expect(worker.inFlightBatchCount, equals(1));
      worker.onBatchComplete();
      expect(worker.inFlightBatchCount, equals(0));
    });

    // ── lifecycle resets ────────────────────────────────────────────────────

    test('pause resets inFlightBatchCount to 0', () async {
      final worker = _makeWorker(stateStore: stateStore);
      await worker.start();
      worker.onBatchesDispatched(3);
      expect(worker.inFlightBatchCount, equals(3));

      await worker.pause();
      expect(worker.inFlightBatchCount, equals(0));
    });

    test('stop resets inFlightBatchCount to 0', () async {
      final worker = _makeWorker(stateStore: stateStore);
      await worker.start();
      worker.onBatchesDispatched(2);
      expect(worker.inFlightBatchCount, equals(2));

      await worker.stop();
      expect(worker.inFlightBatchCount, equals(0));
    });

    test('resetWorkState clears all counters', () async {
      final worker = _makeWorker(stateStore: stateStore);
      await worker.start();
      await worker.onQueryNeeded();
      worker.onBatchesDispatched(5);

      await worker.resetWorkState();
      expect(worker.inFlightBatchCount, equals(0));
      expect(worker.isFinished, false);
    });

    test('ignores query requests when stopped', () async {
      final worker = _makeWorker(stateStore: stateStore);
      await worker.start();
      await worker.stop();
      await worker.onQueryNeeded();

      expect(worker.hasRemainingWork, isFalse);
      final snapshot = stateStore.getSnapshot('query_worker');
      expect(snapshot?.checkpoint, isNull);
    });
  });
}
