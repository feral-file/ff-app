// Reason: base worker contract uses concise method names by design.
// ignore_for_file: public_member_api_docs, avoid_redundant_argument_values

import 'dart:async';
import 'dart:isolate';

import 'package:app/infra/workers/worker_message.dart';
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
  Future<void>? _startInFlight;

  // Isolate infrastructure (for isolate-backed workers).
  Isolate? _isolate;
  ReceivePort? _receivePort;
  ReceivePort? _errorPort;
  ReceivePort? _exitPort;
  SendPort? _sendPort;
  Completer<void>? _shutdownCompleter;

  BackgroundWorkerState get state => _state;

  /// Returns true if the isolate is running AND the handshake has completed
  /// (i.e. the main isolate has a [SendPort] to reach the worker).
  ///
  /// Checking only [_isolate] != null is insufficient because there is a brief
  /// window between [Isolate.spawn] returning and the handshake [SendPort]
  /// arriving during which [_isolate] is set but [_sendPort] is still null.
  bool get isIsolateRunning => _isolate != null && _sendPort != null;

  /// Returns true when this worker still has unprocessed work.
  bool get hasRemainingWork;

  /// Starts worker runtime.
  ///
  /// Resume behavior: restores checkpoint if resuming from pause on this
  /// instance. Fresh start: ignores checkpoint if this is a new worker
  /// instance.
  Future<void> start() async {
    final inFlight = _startInFlight;
    if (inFlight != null) {
      await inFlight;
      return;
    }

    final startFuture = _startInternal();
    _startInFlight = startFuture;
    try {
      await startFuture;
    } finally {
      if (identical(_startInFlight, startFuture)) {
        _startInFlight = null;
      }
    }
  }

  /// Resumes worker runtime from persisted paused checkpoint, if present.
  Future<void> resume() async {
    final snapshot = await _workerStateService.load(workerId);
    if (snapshot != null) {
      _state = _stateFromIndex(snapshot.stateIndex);
      if (_state == BackgroundWorkerState.paused) {
        final checkpoint = snapshot.checkpoint;
        if (checkpoint != null) {
          await restoreFromCheckpoint(checkpoint);
        }
      }
    }
    await start();
  }

  /// Clears persisted status/checkpoint and starts from a clean state.
  Future<void> freshStart() async {
    await onStop();
    await resetWorkState();
    _state = BackgroundWorkerState.idle;
    await _workerStateService.save(
      workerId: workerId,
      stateIndex: _state.index,
      checkpoint: null,
    );
    await start();
  }

  Future<void> _startInternal() async {
    if (_state == BackgroundWorkerState.started) {
      return;
    }

    // Only restore checkpoint if THIS instance was paused (not from storage).
    if (_state == BackgroundWorkerState.paused) {
      await restoreCheckpoint();
    }

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

  /// Sends a message to the worker isolate.
  ///
  /// Throws [StateError] if isolate is not running.
  void sendMessage(WorkerMessage message) {
    if (_sendPort == null) {
      final error = 'Cannot send message: isolate not ready for $workerId';
      throw StateError(error);
    }
    _sendPort!.send(message.toList());
  }

  /// Sends a raw list message to the worker isolate.
  ///
  /// For compatibility with simpler message formats.
  void sendRaw(List<Object?> message) {
    if (_sendPort == null) {
      final error = 'Cannot send message: isolate not ready for $workerId';
      throw StateError(error);
    }
    _sendPort!.send(message);
  }

  /// Spawns worker isolate with given entry point and arguments.
  ///
  /// Subclasses should call this in [onStart] to spawn their isolate.
  ///
  /// The [handshakeTimeout] is generous (30 s by default) because iOS
  /// simulator can delay isolate scheduling when several isolates start
  /// concurrently at app launch. If the isolate crashes before sending the
  /// handshake [SendPort], the error port fires and the completer is
  /// completed with an error immediately (no need to wait the full timeout).
  Future<void> spawnIsolate({
    required void Function(List<Object?>) entryPoint,
    required List<Object?> args,
    Duration handshakeTimeout = const Duration(seconds: 30),
  }) async {
    if (_isolate != null) {
      return;
    }

    _receivePort = ReceivePort();
    _errorPort = ReceivePort();
    _exitPort = ReceivePort();

    _receivePort!.listen(_handleIsolateMessage);
    _errorPort!.listen((dynamic error) {
      _log.warning('Isolate error for $workerId: $error');
      // If the isolate crashes before sending the handshake SendPort, fail
      // the handshake immediately rather than waiting for the full timeout.
      if (_handshakeCompleter != null && !_handshakeCompleter!.isCompleted) {
        _handshakeCompleter!.completeError(
          StateError('Isolate crashed before handshake for $workerId: $error'),
        );
      }
    });
    _exitPort!.listen((dynamic message) {
      _log.fine('Isolate exited for $workerId');
    });

    _isolate = await Isolate.spawn<List<Object?>>(
      entryPoint,
      <Object?>[
        _receivePort!.sendPort,
        ...args,
      ],
      errorsAreFatal: false,
      onError: _errorPort!.sendPort,
      onExit: _exitPort!.sendPort,
    );

    // Wait for handshake (isolate sends back its SendPort)
    await _waitForHandshake(handshakeTimeout);
  }

  Future<void> _waitForHandshake(Duration timeout) async {
    final completer = Completer<void>();
    Timer? timer;

    timer = Timer(timeout, () {
      if (!completer.isCompleted) {
        final error = 'Isolate handshake timeout for $workerId';
        completer.completeError(TimeoutException(error));
      }
    });

    // _handleIsolateMessage will complete this when SendPort arrives
    _handshakeCompleter = completer;

    try {
      await completer.future;
    } finally {
      timer.cancel();
      _handshakeCompleter = null;
    }
  }

  Completer<void>? _handshakeCompleter;

  void _handleIsolateMessage(dynamic message) {
    if (message is Map) {
      final type = message['type']?.toString() ?? '';
      if (type == 'lifecycleAck') {
        final completer = _shutdownCompleter;
        if (completer != null && !completer.isCompleted) {
          completer.complete();
        }
        return;
      }
    }

    // Handshake: isolate sends back its SendPort
    if (message is SendPort) {
      _sendPort = message;
      _handshakeCompleter?.complete();
      return;
    }

    // Delegate to subclass for message handling
    onIsolateMessage(message);
  }

  /// Kills worker isolate and cleans up ports.
  ///
  /// Subclasses should call this in [onStop] or [onPause] to kill isolate.
  Future<void> killIsolate() async {
    _isolate?.kill(priority: Isolate.immediate);
    _isolate = null;
    _sendPort = null;

    _receivePort?.close();
    _receivePort = null;

    _errorPort?.close();
    _errorPort = null;

    _exitPort?.close();
    _exitPort = null;
    _shutdownCompleter = null;
  }

  /// Requests a graceful isolate shutdown and waits for ack before killing.
  Future<void> shutdownIsolateGracefully({
    required WorkerOpcode opcode,
    Duration timeout = const Duration(seconds: 2),
  }) async {
    if (_isolate == null) {
      return;
    }

    final port = _sendPort;
    if (port != null) {
      final completer = Completer<void>();
      _shutdownCompleter = completer;
      try {
        port.send(
          WorkerMessage(
            opcode: opcode,
            workerId: workerId,
            payload: const <String, dynamic>{},
          ).toList(),
        );
        await completer.future.timeout(timeout);
      } on Object catch (e, stack) {
        _log.warning(
          'Graceful isolate shutdown timed out for $workerId',
          e,
          stack,
        );
      } finally {
        if (identical(_shutdownCompleter, completer)) {
          _shutdownCompleter = null;
        }
      }
    }

    await killIsolate();
  }

  /// Called when isolate sends a message to main isolate.
  ///
  /// Subclasses override this to handle worker-specific messages.
  void onIsolateMessage(dynamic message) {
    _log.warning('Unhandled isolate message for $workerId: $message');
  }

  Future<void> onStart();
  Future<void> onPause();
  Future<void> onStop();

  Future<Map<String, dynamic>> buildCheckpoint();

  Future<void> restoreFromCheckpoint(Map<String, dynamic> checkpoint);

  Future<void> resetWorkState();
}
