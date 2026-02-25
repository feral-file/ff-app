// Reason: worker constructor/entrypoints are intentionally compact.
// ignore_for_file: public_member_api_docs, use_super_parameters

import 'dart:async';

import 'package:app/infra/workers/background_worker.dart';
import 'package:app/infra/workers/worker_message.dart';
import 'package:app/infra/workers/worker_state_service.dart';
import 'package:logging/logging.dart';

/// Lightweight signal handler for feed ingestion events.
///
/// No isolate is spawned — all logic runs on the main isolate to avoid
/// competing for OS thread slots during the app-startup window.
///
/// Pipeline:
/// 1. Receive feedIngested signal from scheduler
/// 2. Debounce rapid signals (Timer(Duration.zero)) into one flush
/// 3. Emit a single queryNeeded to the scheduler once the queue drains
///
/// The debounce ensures that N rapid feed-ingested events (e.g. multiple
/// channels refreshed at once) produce exactly one queryNeeded, so
/// enrichment does not start before all feed writes are committed.
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

  // Timer used to coalesce back-to-back onFeedIngested() calls into one flush.
  // Duration.zero fires on the next event-loop turn, after all synchronous and
  // microtask work (including sequential await-chains in callers) completes.
  Timer? _queryNeededTimer;

  @override
  bool get hasRemainingWork => _pendingSignalsCount > 0;

  /// Signal that a feed channel was ingested and items need enrichment.
  Future<void> onFeedIngested() async {
    if (state == BackgroundWorkerState.stopped) {
      return;
    }

    _pendingSignalsCount++;
    await checkpoint();

    if (state == BackgroundWorkerState.started) {
      _scheduleQueryNeededFlush();
    }
  }

  /// Cancels any pending timer and schedules a new Duration.zero flush.
  ///
  /// Called after each [onFeedIngested] while started, and from [onStart]
  /// when there are pending signals. The timer fires once after the current
  /// async activity drains, coalescing all rapid signals into one emission.
  void _scheduleQueryNeededFlush() {
    _queryNeededTimer?.cancel();
    _queryNeededTimer = Timer(Duration.zero, _flushPendingSignals);
  }

  void _flushPendingSignals() {
    _queryNeededTimer = null;
    if (_pendingSignalsCount <= 0 || state != BackgroundWorkerState.started) {
      return;
    }
    _pendingSignalsCount = 0;
    _onMessageSent?.call(
      WorkerMessage(
        opcode: WorkerOpcode.queryNeeded,
        workerId: workerId,
        payload: const <String, dynamic>{},
      ),
    );
    unawaited(checkpoint());
  }

  @override
  Future<void> onStart() async {
    // No isolate to spawn. If signals arrived before start, schedule flush.
    if (_pendingSignalsCount > 0) {
      _scheduleQueryNeededFlush();
    }
  }

  @override
  Future<void> onPause() async {
    // Cancel pending flush so it does not fire after the worker is paused.
    // The pending count is preserved and saved by buildCheckpoint() before
    // this method is called by the base pause() flow.
    _queryNeededTimer?.cancel();
    _queryNeededTimer = null;
  }

  @override
  Future<void> onStop() async {
    _queryNeededTimer?.cancel();
    _queryNeededTimer = null;
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
    // No isolate — this method is never invoked.
  }
}
