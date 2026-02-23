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
        onMessageSent: (msg) => messagesSent.add(msg),
      );

      await worker.start();
      await worker.onFeedIngested();

      // Give isolate time to process
      await Future<void>.delayed(const Duration(milliseconds: 100));

      // One signal → exactly one queryNeeded forwarded to scheduler.
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

      // Enqueue multiple signals
      await worker.onFeedIngested();
      await worker.onFeedIngested();
      await worker.onFeedIngested();

      await worker.pause();

      // Verify checkpoint saved with signal count
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
          onMessageSent: (msg) => messagesSent.add(msg),
        );

        await stateStore.save(
          workerId: 'ingest_feed_worker',
          stateIndex: BackgroundWorkerState.paused.index,
          checkpoint: <String, dynamic>{'pendingSignals': 2},
        );
        await worker.restoreCheckpoint();

        // Resume - worker should restore checkpoint
        await worker.start();

        // Verify worker indicates remaining work
        expect(worker.hasRemainingWork, true);

        // Unit test verifies checkpoint restore only.
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

      // Verify checkpoint cleared
      final snapshot = stateStore.getSnapshot('ingest_feed_worker');
      expect(snapshot, isNotNull);
      expect(snapshot!.checkpoint, isNull);
      expect(worker.hasRemainingWork, false);
    });

    test('spawns isolate on start, kills on stop', () async {
      final worker = IngestFeedWorker(
        workerId: 'ingest_feed_worker',
        workerStateService: stateStore,
      );

      expect(worker.isIsolateRunning, false);

      await worker.start();
      expect(worker.isIsolateRunning, true);

      await worker.stop();
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

      // Enqueue many signals rapidly (simulates multiple channels ingested)
      for (var i = 0; i < 10; i++) {
        await worker.onFeedIngested();
      }

      await Future<void>.delayed(const Duration(milliseconds: 300));

      // All signals processed → exactly ONE queryNeeded forwarded to scheduler.
      // Enrichment must not start until every channel is fully ingested.
      final queryMessages = messagesSent
          .where((msg) => msg.opcode == WorkerOpcode.queryNeeded)
          .length;

      expect(queryMessages, equals(1));
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

      final queryMessages = messagesSent
          .where((msg) => msg.opcode == WorkerOpcode.queryNeeded)
          .length;

      expect(queryMessages, equals(1));
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
