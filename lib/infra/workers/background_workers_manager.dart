// Reason: manager API is intentionally minimal and self-descriptive.
// ignore_for_file: public_member_api_docs

import 'package:app/infra/workers/background_worker.dart';
import 'package:app/infra/workers/index_single_address_worker.dart';
import 'package:app/infra/workers/ingest_feed_channel_worker.dart';
import 'package:logging/logging.dart';

/// Coordinates app-lifecycle start/pause/stop behavior for background workers.
class BackgroundWorkersManager {
  BackgroundWorkersManager({
    required IndexSingleAddressWorker indexSingleAddressWorker,
    required IngestFeedChannelWorker ingestFeedChannelWorker,
    Logger? logger,
  }) : _indexSingleAddressWorker = indexSingleAddressWorker,
       _ingestFeedChannelWorker = ingestFeedChannelWorker,
       _log = logger ?? Logger('BackgroundWorkersManager');

  final IndexSingleAddressWorker _indexSingleAddressWorker;
  final IngestFeedChannelWorker _ingestFeedChannelWorker;
  final Logger _log;

  IndexSingleAddressWorker get indexSingleAddressWorker =>
      _indexSingleAddressWorker;
  IngestFeedChannelWorker get ingestFeedChannelWorker =>
      _ingestFeedChannelWorker;

  Future<void> startPendingWorkOnForeground() async {
    await _indexSingleAddressWorker.restoreCheckpoint();
    await _ingestFeedChannelWorker.restoreCheckpoint();

    if (_indexSingleAddressWorker.hasRemainingWork ||
        _indexSingleAddressWorker.state == BackgroundWorkerState.paused) {
      await _indexSingleAddressWorker.start();
    }

    if (_ingestFeedChannelWorker.hasRemainingWork ||
        _ingestFeedChannelWorker.state == BackgroundWorkerState.paused) {
      await _ingestFeedChannelWorker.start();
    }

    _log.fine('Foreground worker startup completed');
  }

  Future<void> pauseOnBackground() async {
    if (_indexSingleAddressWorker.state == BackgroundWorkerState.started) {
      await _indexSingleAddressWorker.pause();
    }

    if (_ingestFeedChannelWorker.state == BackgroundWorkerState.started) {
      await _ingestFeedChannelWorker.pause();
    }

    _log.fine('Background worker pause completed');
  }

  Future<void> stopAll() async {
    await _indexSingleAddressWorker.stop();
    await _ingestFeedChannelWorker.stop();
    _log.fine('All workers stopped and checkpoints reset');
  }
}
