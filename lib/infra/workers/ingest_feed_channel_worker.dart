// Reason: worker constructor/entrypoints are intentionally compact.
// ignore_for_file: public_member_api_docs, use_super_parameters

import 'package:app/infra/workers/background_worker.dart';
import 'package:app/infra/workers/item_enrichment_worker.dart';
import 'package:app/infra/workers/worker_state_service.dart';
import 'package:logging/logging.dart';

/// Worker that reacts to channel-ingested events and schedules item enrichment.
class IngestFeedChannelWorker extends BackgroundWorker {
  IngestFeedChannelWorker({
    required WorkerStateStore workerStateService,
    required ItemEnrichmentWorker itemEnrichmentWorker,
    Logger? logger,
  }) : _itemEnrichmentWorker = itemEnrichmentWorker,
       _log = logger ?? Logger('IngestFeedChannelWorker'),
       super(
         workerId: _workerId,
         workerStateService: workerStateService,
         logger: logger,
       );

  static const String _workerId = 'ingest_feed_channel_worker';

  final ItemEnrichmentWorker _itemEnrichmentWorker;
  final Logger _log;

  int _pendingIngestSignals = 0;
  bool _isDraining = false;

  @override
  bool get hasRemainingWork =>
      _pendingIngestSignals > 0 ||
      _isDraining ||
      _itemEnrichmentWorker.hasRemainingWork;

  Future<void> notifyChannelIngested() async {
    _pendingIngestSignals += 1;
    await checkpoint();
    if (state == BackgroundWorkerState.started) {
      await _drainSignals();
    }
  }

  @override
  Future<void> onStart() async {
    if (_itemEnrichmentWorker.state != BackgroundWorkerState.started) {
      await _itemEnrichmentWorker.start();
    }
    await _drainSignals();
  }

  @override
  Future<void> onPause() async {
    if (_itemEnrichmentWorker.state == BackgroundWorkerState.started) {
      await _itemEnrichmentWorker.pause();
    }
  }

  @override
  Future<void> onStop() async {
    if (_itemEnrichmentWorker.state != BackgroundWorkerState.stopped) {
      await _itemEnrichmentWorker.stop();
    }
  }

  @override
  Future<Map<String, dynamic>> buildCheckpoint() async {
    return <String, dynamic>{
      'pendingIngestSignals': _pendingIngestSignals,
    };
  }

  @override
  Future<void> restoreFromCheckpoint(Map<String, dynamic> checkpoint) async {
    _pendingIngestSignals = _asNonNegativeInt(
      checkpoint['pendingIngestSignals'],
    );
  }

  @override
  Future<void> resetWorkState() async {
    _pendingIngestSignals = 0;
    _isDraining = false;
  }

  Future<void> _drainSignals() async {
    if (_isDraining || state != BackgroundWorkerState.started) {
      return;
    }

    _isDraining = true;
    try {
      while (_pendingIngestSignals > 0 &&
          state == BackgroundWorkerState.started) {
        _pendingIngestSignals -= 1;
        try {
          await _itemEnrichmentWorker.notifyWorkAvailable();
        } on Object catch (e, stack) {
          _log.warning(
            'Failed to schedule item enrichment from channel ingest',
            e,
            stack,
          );
          _pendingIngestSignals += 1;
          await checkpoint();
          rethrow;
        }
        await checkpoint();
      }
    } finally {
      _isDraining = false;
    }
  }

  int _asNonNegativeInt(Object? value) {
    final parsed = switch (value) {
      final int v => v,
      final String v => int.tryParse(v) ?? 0,
      _ => 0,
    };
    return parsed < 0 ? 0 : parsed;
  }
}
