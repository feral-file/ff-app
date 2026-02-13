// Reason: base worker contract uses concise method names by design.
// ignore_for_file: public_member_api_docs, avoid_redundant_argument_values

import 'package:app/infra/workers/worker_state_service.dart';
import 'package:logging/logging.dart';

/// Lifecycle state for background workers.
enum BackgroundWorkerState {
  idle,
  started,
  paused,
  stopped,
}

/// Shared contract for lifecycle-managed background workers.
abstract class BackgroundWorker {
  BackgroundWorker({
    required this.workerId,
    required WorkerStateStore workerStateService,
    Logger? logger,
  }) : _workerStateService = workerStateService,
       _log = logger ?? Logger('BackgroundWorker.$workerId');

  final String workerId;
  final WorkerStateStore _workerStateService;
  final Logger _log;

  BackgroundWorkerState _state = BackgroundWorkerState.idle;

  BackgroundWorkerState get state => _state;

  /// Returns true when this worker still has unprocessed work.
  bool get hasRemainingWork;

  /// Starts worker runtime and resumes processing from restored checkpoint.
  Future<void> start() async {
    if (_state == BackgroundWorkerState.started) {
      return;
    }

    await restoreCheckpoint();
    await onStart();
    _state = BackgroundWorkerState.started;
    await _workerStateService.save(
      workerId: workerId,
      stateIndex: _state.index,
      checkpoint: await buildCheckpoint(),
    );
  }

  /// Pauses processing, persists checkpoint, and releases runtime resources.
  Future<void> pause() async {
    if (_state != BackgroundWorkerState.started) {
      return;
    }
    await checkpoint();
    await onPause();
    _state = BackgroundWorkerState.paused;
    await _workerStateService.save(
      workerId: workerId,
      stateIndex: _state.index,
      checkpoint: await buildCheckpoint(),
    );
  }

  /// Stops processing and clears checkpoint data.
  Future<void> stop() async {
    await onStop();
    _state = BackgroundWorkerState.stopped;
    await resetWorkState();
    await _workerStateService.save(
      workerId: workerId,
      stateIndex: _state.index,
      checkpoint: null,
    );
  }

  /// Persists checkpoint with current state.
  Future<void> checkpoint() async {
    final checkpointPayload = await buildCheckpoint();
    await _workerStateService.save(
      workerId: workerId,
      stateIndex: _state.index,
      checkpoint: checkpointPayload,
    );
  }

  /// Restores checkpoint payload and worker state.
  Future<void> restoreCheckpoint() async {
    final snapshot = await _workerStateService.load(workerId);
    if (snapshot == null) {
      return;
    }

    _state = _stateFromIndex(snapshot.stateIndex);
    final checkpoint = snapshot.checkpoint;
    if (checkpoint != null) {
      await restoreFromCheckpoint(checkpoint);
    }
  }

  BackgroundWorkerState _stateFromIndex(int index) {
    if (index < 0 || index >= BackgroundWorkerState.values.length) {
      _log.warning('Invalid worker state index: $index for $workerId');
      return BackgroundWorkerState.idle;
    }
    return BackgroundWorkerState.values[index];
  }

  Future<void> onStart();
  Future<void> onPause();
  Future<void> onStop();

  Future<Map<String, dynamic>> buildCheckpoint();
  Future<void> restoreFromCheckpoint(Map<String, dynamic> checkpoint);

  Future<void> resetWorkState();
}
