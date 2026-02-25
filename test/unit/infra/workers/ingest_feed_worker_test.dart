import 'package:app/infra/workers/background_worker.dart';
import 'package:app/infra/workers/ingest_feed_worker.dart';
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

void main() {
  group('IngestFeedWorker', () {
    late _InMemoryWorkerStateStore stateStore;

    setUp(() {
      stateStore = _InMemoryWorkerStateStore();
    });

    test('receives feedIngested and sends exactly one queryNeeded', () async {
      final messagesSent = <WorkerMessage>[];

      final worker = IngestFeedWorker(
        workerId: 'ingest_feed_worker',
        workerStateService: stateStore,
        onMessageSent: messagesSent.add,
      );

      await worker.start();
      await worker.onFeedIngested();

      // Give the Duration.zero debounce timer a chance to fire.
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final queryMessages = messagesSent
          .where((msg) => msg.opcode == WorkerOpcode.queryNeeded)
          .toList();
      expect(queryMessages, hasLength(1));
    });

    test('pause() saves pending signals to checkpoint', () async {
      final worker = IngestFeedWorker(
        workerId: 'ingest_feed_worker',
        workerStateService: stateStore,
      );

      await worker.start();

      // Enqueue multiple signals — timer has not fired yet when we pause.
      await worker.onFeedIngested();
      await worker.onFeedIngested();
      await worker.onFeedIngested();

      await worker.pause();

      // Checkpoint must record the pending signal count.
      final snapshot = stateStore.getSnapshot('ingest_feed_worker');
      expect(snapshot, isNotNull);
      expect(snapshot!.checkpoint, isNotNull);
      expect(snapshot.checkpoint!['pendingSignals'], isA<int>());
    });

    test(
      'start() after pause() restores pending signals from checkpoint',
      () async {
        final messagesSent = <WorkerMessage>[];

        final worker = IngestFeedWorker(
          workerId: 'ingest_feed_worker',
          workerStateService: stateStore,
          onMessageSent: messagesSent.add,
        );

        await stateStore.save(
          workerId: 'ingest_feed_worker',
          stateIndex: BackgroundWorkerState.paused.index,
          checkpoint: <String, dynamic>{'pendingSignals': 2},
        );
        await worker.restoreCheckpoint();

        // Resume — pending count restored, hasRemainingWork is true.
        await worker.start();
        expect(worker.hasRemainingWork, true);

        // Timer fires: one queryNeeded emitted for the restored batch.
        await Future<void>.delayed(const Duration(milliseconds: 50));
        final queryMessages = messagesSent
            .where((msg) => msg.opcode == WorkerOpcode.queryNeeded)
            .toList();
        expect(queryMessages, hasLength(1));
      },
    );

    test('stop() clears checkpoint', () async {
      final worker = IngestFeedWorker(
        workerId: 'ingest_feed_worker',
        workerStateService: stateStore,
      );

      await worker.start();
      await worker.onFeedIngested();

      await worker.stop();

      final snapshot = stateStore.getSnapshot('ingest_feed_worker');
      expect(snapshot, isNotNull);
      expect(snapshot!.checkpoint, isNull);
      expect(worker.hasRemainingWork, false);
    });

    test('runs on the main isolate — no background isolate spawned', () async {
      final worker = IngestFeedWorker(
        workerId: 'ingest_feed_worker',
        workerStateService: stateStore,
      );

      // IngestFeedWorker never spawns a background isolate.
      expect(worker.isIsolateRunning, false);

      await worker.start();
      expect(worker.state, BackgroundWorkerState.started);
      expect(worker.isIsolateRunning, false);

      await worker.stop();
      expect(worker.state, BackgroundWorkerState.stopped);
      expect(worker.isIsolateRunning, false);
    });

    test('batches multiple signals into a single queryNeeded', () async {
      final messagesSent = <WorkerMessage>[];

      final worker = IngestFeedWorker(
        workerId: 'ingest_feed_worker',
        workerStateService: stateStore,
        onMessageSent: messagesSent.add,
      );

      await worker.start();

      // 10 rapid signals: the debounce timer is cancelled and rescheduled on
      // each call, so it fires exactly once after all calls complete.
      for (var i = 0; i < 10; i++) {
        await worker.onFeedIngested();
      }

      await Future<void>.delayed(const Duration(milliseconds: 300));

      final queryCount = messagesSent
          .where((msg) => msg.opcode == WorkerOpcode.queryNeeded)
          .length;
      expect(queryCount, equals(1));
    });

    test('single feed ingested sends exactly one queryNeeded', () async {
      final messagesSent = <WorkerMessage>[];

      final worker = IngestFeedWorker(
        workerId: 'ingest_feed_worker',
        workerStateService: stateStore,
        onMessageSent: messagesSent.add,
      );

      await worker.start();
      await worker.onFeedIngested();
      await Future<void>.delayed(const Duration(milliseconds: 100));

      final queryCount = messagesSent
          .where((msg) => msg.opcode == WorkerOpcode.queryNeeded)
          .length;
      expect(queryCount, equals(1));
    });

    test('ignores feed signals when stopped', () async {
      final worker = IngestFeedWorker(
        workerId: 'ingest_feed_worker',
        workerStateService: stateStore,
      );

      await worker.start();
      await worker.stop();
      await worker.onFeedIngested();

      expect(worker.hasRemainingWork, false);
      final snapshot = stateStore.getSnapshot('ingest_feed_worker');
      expect(snapshot?.checkpoint, isNull);
    });
  });
}
