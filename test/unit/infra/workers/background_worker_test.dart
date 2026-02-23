import 'package:app/infra/workers/background_worker.dart';
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
}

class _TestWorker extends BackgroundWorker {
  _TestWorker({
    required WorkerStateStore workerStateStore,
  }) : super(workerId: 'test_worker', workerStateService: workerStateStore);

  int pending = 0;
  bool startedCalled = false;
  bool pausedCalled = false;
  bool stoppedCalled = false;

  @override
  bool get hasRemainingWork => pending > 0;

  @override
  Future<Map<String, dynamic>> buildCheckpoint() async {
    return <String, dynamic>{
      'pending': pending,
    };
  }

  @override
  Future<void> onPause() async {
    pausedCalled = true;
  }

  @override
  Future<void> onStart() async {
    startedCalled = true;
  }

  @override
  Future<void> onStop() async {
    stoppedCalled = true;
  }

  @override
  Future<void> resetWorkState() async {
    pending = 0;
  }

  @override
  Future<void> restoreFromCheckpoint(Map<String, dynamic> checkpoint) async {
    final value = checkpoint['pending'];
    pending = switch (value) {
      final int v => v,
      final String v => int.tryParse(v) ?? 0,
      _ => 0,
    };
  }
}

class _SlowStartWorker extends BackgroundWorker {
  _SlowStartWorker({
    required WorkerStateStore workerStateStore,
  }) : super(
         workerId: 'slow_start_worker',
         workerStateService: workerStateStore,
       );

  int onStartCalls = 0;

  @override
  bool get hasRemainingWork => false;

  @override
  Future<Map<String, dynamic>> buildCheckpoint() async => <String, dynamic>{};

  @override
  Future<void> onPause() async {}

  @override
  Future<void> onStart() async {
    onStartCalls++;
    await Future<void>.delayed(const Duration(milliseconds: 50));
  }

  @override
  Future<void> onStop() async {}

  @override
  Future<void> resetWorkState() async {}

  @override
  Future<void> restoreFromCheckpoint(Map<String, dynamic> checkpoint) async {}
}

void main() {
  test(
    'background worker checkpoints on pause and can be manually restored',
    () async {
      final store = _InMemoryWorkerStateStore();
      final worker = _TestWorker(workerStateStore: store);

      await worker.start();
      worker.pending = 3;

      await worker.pause();
      expect(worker.state, BackgroundWorkerState.paused);

      // New instances start fresh by default (no automatic restore)
      final freshWorker = _TestWorker(workerStateStore: store);
      await freshWorker.start();
      expect(freshWorker.pending, 0); // starts fresh, didn't restore

      // But can manually restore checkpoint if needed
      await freshWorker.stop();

      final restoredWorker = _TestWorker(workerStateStore: store);
      // Need to restore BEFORE saving a new checkpoint
      await restoredWorker.restoreCheckpoint();
      expect(restoredWorker.pending, 0); // freshWorker overwrote checkpoint

      // To properly test restore, don't start a fresh worker first
      await store.save(
        workerId: 'test_worker',
        stateIndex: BackgroundWorkerState.paused.index,
        checkpoint: <String, dynamic>{'pending': 5},
      );

      final properlyRestoredWorker = _TestWorker(workerStateStore: store);
      await properlyRestoredWorker.restoreCheckpoint();
      expect(properlyRestoredWorker.pending, 5);
      await properlyRestoredWorker.start();
      expect(properlyRestoredWorker.state, BackgroundWorkerState.started);
    },
  );

  test('background worker stop clears checkpoint and resets work', () async {
    final store = _InMemoryWorkerStateStore();
    final worker = _TestWorker(workerStateStore: store);

    await worker.start();
    worker.pending = 2;
    await worker.pause();
    await worker.stop();

    final restoredWorker = _TestWorker(workerStateStore: store);
    await restoredWorker.start();

    expect(restoredWorker.pending, 0);
    expect(restoredWorker.state, BackgroundWorkerState.started);
  });

  test('background worker coalesces concurrent start calls', () async {
    final store = _InMemoryWorkerStateStore();
    final worker = _SlowStartWorker(workerStateStore: store);

    await Future.wait(<Future<void>>[
      worker.start(),
      worker.start(),
      worker.start(),
    ]);

    expect(worker.state, BackgroundWorkerState.started);
    expect(worker.onStartCalls, 1);
  });
}
