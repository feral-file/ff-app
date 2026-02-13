// Reason: worker constructor/entrypoints are intentionally compact.
// ignore_for_file: public_member_api_docs, use_super_parameters

import 'package:app/infra/config/app_config.dart';
import 'package:app/infra/graphql/indexer_client.dart';
import 'package:app/infra/services/dp1_playlist_items_enrichment_service.dart';
import 'package:app/infra/services/indexer_service.dart';
import 'package:app/infra/workers/background_worker.dart';
import 'package:app/infra/workers/worker_database_session.dart';
import 'package:app/infra/workers/worker_state_service.dart';
import 'package:logging/logging.dart';

/// Worker that queries and enriches bare items from local database.
class ItemEnrichmentWorker extends BackgroundWorker {
  ItemEnrichmentWorker({
    required WorkerStateStore workerStateService,
    required WorkerDatabaseSession databaseSession,
    Logger? logger,
  }) : _databaseSession = databaseSession,
       _log = logger ?? Logger('ItemEnrichmentWorker'),
       super(
         workerId: _workerId,
         workerStateService: workerStateService,
         logger: logger,
       );

  static const String _workerId = 'item_enrichment_worker';

  final WorkerDatabaseSession _databaseSession;
  final Logger _log;

  DP1PlaylistItemsEnrichmentService? _enrichmentService;
  bool _hasPendingWork = false;
  bool _isDraining = false;

  @override
  bool get hasRemainingWork => _hasPendingWork || _isDraining;

  Future<void> notifyWorkAvailable() async {
    _hasPendingWork = true;
    await checkpoint();
    if (state == BackgroundWorkerState.started) {
      await _drainIfNeeded();
    }
  }

  @override
  Future<void> onStart() async {
    await _databaseSession.open();

    final client = IndexerClient(
      endpoint: AppConfig.indexerApiUrl,
      defaultHeaders: <String, String>{
        'Content-Type': 'application/json',
        if (AppConfig.indexerApiKey.isNotEmpty)
          'Authorization': 'ApiKey ${AppConfig.indexerApiKey}',
      },
    );
    final indexerService = IndexerService(client: client);

    _enrichmentService = DP1PlaylistItemsEnrichmentService(
      indexerService: indexerService,
      databaseService: _databaseSession.databaseService,
      shouldContinue: () => state == BackgroundWorkerState.started,
    );

    await _drainIfNeeded();
  }

  @override
  Future<void> onPause() async {
    await _databaseSession.checkpointAndClose();
    _enrichmentService = null;
  }

  @override
  Future<void> onStop() async {
    await _databaseSession.close();
    _enrichmentService = null;
  }

  @override
  Future<Map<String, dynamic>> buildCheckpoint() async {
    return <String, dynamic>{
      'hasPendingWork': _hasPendingWork,
    };
  }

  @override
  Future<void> restoreFromCheckpoint(Map<String, dynamic> checkpoint) async {
    _hasPendingWork = checkpoint['hasPendingWork'] == true;
  }

  @override
  Future<void> resetWorkState() async {
    _hasPendingWork = false;
    _isDraining = false;
  }

  Future<void> _drainIfNeeded() async {
    if (_isDraining ||
        !_hasPendingWork ||
        state != BackgroundWorkerState.started) {
      return;
    }

    _isDraining = true;
    try {
      while (_hasPendingWork && state == BackgroundWorkerState.started) {
        _hasPendingWork = false;
        final service = _enrichmentService;
        if (service == null) {
          return;
        }

        try {
          final completed = await service.processAll();
          if (!completed) {
            _hasPendingWork = true;
          }
        } on Object catch (e, stack) {
          _log.warning('Item enrichment worker failed', e, stack);
          _hasPendingWork = true;
          rethrow;
        } finally {
          await checkpoint();
        }
      }
    } finally {
      _isDraining = false;
    }
  }
}
