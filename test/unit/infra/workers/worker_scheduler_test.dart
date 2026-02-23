// Scheduler unit tests verify message routing and lifecycle behavior.
// In-flight batch counting lives in ItemEnrichmentQueryWorker; the scheduler
// exposes it via a forwarding getter for test assertions.

import 'package:app/infra/workers/background_worker.dart';
import 'package:app/infra/workers/worker_message.dart';
import 'package:app/infra/workers/worker_scheduler.dart';
import 'package:app/infra/workers/worker_state_service.dart';
import 'package:flutter_test/flutter_test.dart';

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
  Future<WorkerStateSnapshot?> load(String workerId) async =>
      _rows[workerId];

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

// ── helpers ──────────────────────────────────────────────────────────────────

WorkerMessage _batchesReadyMsg(int batchCount) => WorkerMessage(
  opcode: WorkerOpcode.batchesReady,
  workerId: 'item_enrichment_query_worker',
  payload: <String, dynamic>{
    'batches': <Map<String, String>>[
      for (var i = 0; i < batchCount; i++)
        <String, String>{'cid_$i': 'item_$i'},
    ],
  },
);

WorkerMessage _workCompleteMsg() => const WorkerMessage(
  opcode: WorkerOpcode.workComplete,
  workerId: 'enrich_item_worker::0',
  payload: <String, dynamic>{},
);

WorkerMessage _workFailedMsg() => const WorkerMessage(
  opcode: WorkerOpcode.workFailed,
  workerId: 'enrich_item_worker::0',
  payload: <String, dynamic>{},
);

void main() {
  group('WorkerScheduler', () {
    late _InMemoryWorkerStateStore stateStore;
    late WorkerScheduler scheduler;

    setUp(() {
      stateStore = _InMemoryWorkerStateStore();
      scheduler = WorkerScheduler(
        databasePathResolver: () async => ':memory:',
        workerStateService: stateStore,
        indexerEndpoint: '',
        indexerApiKey: '',
        maxEnrichmentWorkers: 1,
      );
    });

    tearDown(() async {
      await scheduler.stopAll();
    });

    group('in-flight batch tracking', () {
      test('batchesReady increments inFlightBatchCount by batch count',
          () async {
        await scheduler.startOnForeground();

        scheduler.handleWorkerMessage(_batchesReadyMsg(3));
        expect(scheduler.inFlightBatchCount, equals(3));
      });

      test('workComplete decrements inFlightBatchCount', () async {
        await scheduler.startOnForeground();

        scheduler.handleWorkerMessage(_batchesReadyMsg(2));
        expect(scheduler.inFlightBatchCount, equals(2));

        scheduler.handleWorkerMessage(_workCompleteMsg());
        expect(scheduler.inFlightBatchCount, equals(1));
      });

      test('workFailed also decrements inFlightBatchCount', () async {
        await scheduler.startOnForeground();

        scheduler.handleWorkerMessage(_batchesReadyMsg(1));
        expect(scheduler.inFlightBatchCount, equals(1));

        scheduler.handleWorkerMessage(_workFailedMsg());
        expect(scheduler.inFlightBatchCount, equals(0));
      });

      test('count does not go below zero on extra completions', () async {
        await scheduler.startOnForeground();
        // No batches dispatched, but spurious workComplete arrives.
        scheduler.handleWorkerMessage(_workCompleteMsg());
        expect(scheduler.inFlightBatchCount, equals(0));
      });

      test('multiple rounds accumulate and drain correctly', () async {
        await scheduler.startOnForeground();

        // Round 1: 2 batches dispatched
        scheduler.handleWorkerMessage(_batchesReadyMsg(2));
        expect(scheduler.inFlightBatchCount, equals(2));

        scheduler.handleWorkerMessage(_workCompleteMsg());
        expect(scheduler.inFlightBatchCount, equals(1));

        // Round 1 done → count hits 0, re-query triggered internally
        scheduler.handleWorkerMessage(_workCompleteMsg());
        expect(scheduler.inFlightBatchCount, equals(0));

        // Round 2: a new batchesReady arrives from the re-query
        scheduler.handleWorkerMessage(_batchesReadyMsg(1));
        expect(scheduler.inFlightBatchCount, equals(1));

        scheduler.handleWorkerMessage(_workCompleteMsg());
        expect(scheduler.inFlightBatchCount, equals(0));
      });
    });

    group('lifecycle resets', () {
      test('pauseOnBackground resets inFlightBatchCount', () async {
        await scheduler.startOnForeground();
        scheduler.handleWorkerMessage(_batchesReadyMsg(3));
        expect(scheduler.inFlightBatchCount, equals(3));

        await scheduler.pauseOnBackground();
        expect(scheduler.inFlightBatchCount, equals(0));
      });

      test('stopAll resets inFlightBatchCount', () async {
        await scheduler.startOnForeground();
        scheduler.handleWorkerMessage(_batchesReadyMsg(2));
        expect(scheduler.inFlightBatchCount, equals(2));

        await scheduler.stopAll();
        expect(scheduler.inFlightBatchCount, equals(0));
      });
    });
  });
}
