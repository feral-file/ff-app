// Scheduler unit tests verify lifecycle and address-worker delegation behavior.

import 'package:app/infra/database/database_service.dart';
import 'package:app/infra/workers/background_worker.dart';
import 'package:app/infra/workers/worker_scheduler.dart';
import 'package:app/infra/workers/worker_state_service.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeDatabaseService implements DatabaseService {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

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

WorkerScheduler _makeScheduler(_InMemoryWorkerStateStore stateStore) {
  return WorkerScheduler(
    workerStateService: stateStore,
    databaseService: _FakeDatabaseService(),
    indexerEndpoint: '',
    indexerApiKey: '',
  );
}

void main() {
  group('WorkerScheduler', () {
    late _InMemoryWorkerStateStore stateStore;
    late WorkerScheduler scheduler;

    setUp(() {
      stateStore = _InMemoryWorkerStateStore();
      scheduler = _makeScheduler(stateStore);
    });

    tearDown(() async {
      await scheduler.stopAll();
    });

    group('lifecycle', () {
      test('startOnForeground initialises without error', () async {
        // Should not throw even when no addresses are registered yet.
        await expectLater(scheduler.startOnForeground(), completes);
      });

      test('pauseOnBackground is a no-op before initialisation', () async {
        // Not yet initialised — should return without error.
        await expectLater(scheduler.pauseOnBackground(), completes);
      });

      test('stopAll is a no-op before initialisation', () async {
        await expectLater(scheduler.stopAll(), completes);
      });

      test('stopAll then startOnForeground re-initialises cleanly', () async {
        await scheduler.startOnForeground();
        await scheduler.stopAll();
        // A second start should succeed without stale state.
        await expectLater(scheduler.startOnForeground(), completes);
      });
    });

    group('address events', () {
      test('onAddressAdded does not throw', () async {
        await scheduler.startOnForeground();
        // IndexAddressWorker will attempt real network; just verify no throw
        // in the scheduler path up to worker creation.
        await expectLater(
          // Use a fresh scheduler with invalid endpoint to stay offline.
          _makeScheduler(stateStore).onAddressAdded('0xDEAD'),
          completes,
        );
      });

      test('onAddressRemoved is a no-op for unknown address', () async {
        await scheduler.startOnForeground();
        await expectLater(scheduler.onAddressRemoved('0xUNKNOWN'), completes);
      });

      test('onAddressRemoved before init does not throw', () async {
        await expectLater(scheduler.onAddressRemoved('0xUNKNOWN'), completes);
      });
    });
  });
}
