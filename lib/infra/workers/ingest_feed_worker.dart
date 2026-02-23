// Reason: worker constructor/entrypoints are intentionally compact.
// ignore_for_file: public_member_api_docs, use_super_parameters

import 'dart:async';
import 'dart:isolate';

import 'package:app/infra/workers/background_worker.dart';
import 'package:app/infra/workers/worker_message.dart';
import 'package:app/infra/workers/worker_state_service.dart';
import 'package:logging/logging.dart';

/// Lightweight signal handler for feed ingestion events.
///
/// Pipeline:
/// 1. Receive feedIngested signal from scheduler
/// 2. Send queryNeeded message to scheduler (routed to QueryWorker)
/// 3. Done
class IngestFeedWorker extends BackgroundWorker {
  IngestFeedWorker({
    required String workerId,
    required WorkerStateStore workerStateService,
    void Function(WorkerMessage)? onMessageSent,
    Logger? logger,
  }) : _onMessageSent = onMessageSent,
       super(
         workerId: workerId,
         workerStateService: workerStateService,
         logger: logger,
       );

  final void Function(WorkerMessage)? _onMessageSent;

  int _pendingSignalsCount = 0;

  @override
  bool get hasRemainingWork => _pendingSignalsCount > 0;

  /// Signal that a feed channel was ingested and items need enrichment.
  Future<void> onFeedIngested() async {
    _pendingSignalsCount++;
    await checkpoint();

    if (state == BackgroundWorkerState.started && isIsolateRunning) {
      _sendQuerySignalToIsolate();
    }
  }

  void _sendQuerySignalToIsolate() {
    if (_pendingSignalsCount <= 0) {
      return;
    }

    sendMessage(
      WorkerMessage(
        opcode: WorkerOpcode.enqueueWork,
        workerId: workerId,
        payload: <String, dynamic>{'signal': 'feedIngested'},
      ),
    );
  }

  @override
  Future<void> onStart() async {
    await spawnIsolate(
      entryPoint: _isolateEntry,
      args: const <Object?>[],
    );

    // Process pending signals
    while (_pendingSignalsCount > 0 && state == BackgroundWorkerState.started) {
      _sendQuerySignalToIsolate();
    }
  }

  @override
  Future<void> onPause() async {
    await killIsolate();
  }

  @override
  Future<void> onStop() async {
    await killIsolate();
  }

  @override
  Future<Map<String, dynamic>> buildCheckpoint() async {
    return <String, dynamic>{
      'pendingSignals': _pendingSignalsCount,
    };
  }

  @override
  Future<void> restoreFromCheckpoint(Map<String, dynamic> checkpoint) async {
    final pending = checkpoint['pendingSignals'];
    _pendingSignalsCount = switch (pending) {
      final int v => v,
      final String v => int.tryParse(v) ?? 0,
      _ => 0,
    };
  }

  @override
  Future<void> resetWorkState() async {
    _pendingSignalsCount = 0;
  }

  @override
  void onIsolateMessage(dynamic message) {
    if (message is! Map) {
      return;
    }

    final type = message['type']?.toString() ?? '';

    if (type == 'queryNeeded') {
      // Decrement pending count for the processed signal.
      _pendingSignalsCount =
          (_pendingSignalsCount - 1).clamp(0, _pendingSignalsCount);
      unawaited(checkpoint());

      // Only forward queryNeeded once ALL pending signals are processed.
      // This ensures the full DB state (publishers, channels, playlists,
      // playlist items, bare item entries) is written before enrichment
      // queries begin.
      if (_pendingSignalsCount == 0) {
        _onMessageSent?.call(
          WorkerMessage(
            opcode: WorkerOpcode.queryNeeded,
            workerId: workerId,
            payload: <String, dynamic>{},
          ),
        );
      }
    }
  }

  // ----------------
  // Isolate entry point
  // ----------------

  static late SendPort _mainSendPort;
  static late Logger _isolateLog;

  static void _isolateEntry(List<Object?> args) {
    final sendPort = args[0]! as SendPort;

    _isolateLog = Logger('IngestFeedWorker[Isolate]');
    _mainSendPort = sendPort;

    // Send handshake
    final isolateReceivePort = ReceivePort()
      ..listen(_handleMessageInIsolate);
    _mainSendPort.send(isolateReceivePort.sendPort);
  }

  static void _handleMessageInIsolate(dynamic message) {
    if (message is! List || message.length < 3) {
      return;
    }

    try {
      final workerMessage = WorkerMessage.fromList(message);

      if (workerMessage.opcode == WorkerOpcode.enqueueWork) {
        // Signal received, send queryNeeded back
        _mainSendPort.send(<String, Object>{
          'type': 'queryNeeded',
        });
      }
    } on Object catch (e, stack) {
      _isolateLog.warning('Failed to handle message in isolate', e, stack);
    }
  }
}
