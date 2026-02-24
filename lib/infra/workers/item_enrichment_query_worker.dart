// Reason: worker constructor/entrypoints are intentionally compact.
// ignore_for_file: public_member_api_docs, use_super_parameters

import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:app/infra/database/app_database.dart';
import 'package:app/infra/database/database_service.dart';
import 'package:app/infra/workers/background_worker.dart';
import 'package:app/infra/workers/worker_message.dart';
import 'package:app/infra/workers/worker_state_service.dart';
import 'package:drift/isolate.dart';
import 'package:drift/native.dart';
import 'package:logging/logging.dart';

/// Queries DB for bare items and drives the enrichment drain loop.
///
/// Lifecycle:
/// 1. Scheduler calls [onQueryNeeded] to start a round (clears [isFinished]).
/// 2. Isolate queries high- then low-priority bare items.
/// 3a. Items found → sends [WorkerOpcode.batchesReady] to scheduler.
///     Scheduler dispatches batches and calls onBatchesDispatched.
///     As each EnrichItemWorker finishes, scheduler calls onBatchComplete.
///     When all in-flight batches settle, the next round starts automatically.
/// 3b. No items → sets [isFinished] = true (persisted to ObjectBox); stops.
///
/// The [isFinished] flag is persisted so the scheduler can skip re-triggering
/// on app restart when all bare items have already been enriched.
/// It is reset whenever [onQueryNeeded] is called (e.g. after a new feed
/// ingestion), ensuring new items are always picked up.
class ItemEnrichmentQueryWorker extends BackgroundWorker {
  ItemEnrichmentQueryWorker({
    required String workerId,
    required WorkerStateStore workerStateService,
    required String databasePath,
    SendPort? databaseConnectPort,
    void Function(WorkerMessage)? onMessageSent,
    Logger? logger,
  }) : _databasePath = databasePath,
       _databaseConnectPort = databaseConnectPort,
       _onMessageSent = onMessageSent,
       super(
         workerId: workerId,
         workerStateService: workerStateService,
         logger: logger,
       );

  final String _databasePath;

  /// [SendPort] for the shared [DriftIsolate].
  ///
  /// Injected by the scheduler via [updateConnectPort] before [start].
  /// Null until set; falls back to direct [NativeDatabase] in tests.
  SendPort? _databaseConnectPort;

  /// Updates the shared DriftIsolate [SendPort].
  // ignore: use_setters_to_change_properties
  void updateConnectPort(SendPort port) => _databaseConnectPort = port;
  final void Function(WorkerMessage)? _onMessageSent;

  // True when a query has been requested but not yet dispatched to the isolate,
  // OR while waiting for the isolate to respond. Persisted so a query pending
  // at pause/stop is re-run on the next foreground session.
  bool _hasPendingQuery = false;

  // True while the isolate is actively processing a query (between dispatch and
  // the batchesReady / noBareItems response). Not persisted: transient per run.
  bool _queryInFlight = false;

  // True when the last query returned 0 bare items — all items are enriched.
  // Persisted to ObjectBox so the scheduler can skip re-triggering on restart.
  bool _isFinished = false;

  // Number of enrichment batches currently in-flight in EnrichItemWorkers.
  // Not persisted: resets to 0 on pause/stop so the next foreground start
  // begins a clean round rather than carrying stale counts.
  int _inFlightBatchCount = 0;

  /// True when every bare item in the DB has been enriched.
  ///
  /// Persisted across restarts. Reset to false by [onQueryNeeded].
  bool get isFinished => _isFinished;

  /// Number of enrichment batches currently being processed.
  int get inFlightBatchCount => _inFlightBatchCount;

  @override
  bool get hasRemainingWork => _hasPendingQuery;

  /// Starts (or resumes) the enrichment drain loop.
  ///
  /// Resets [isFinished] so that new bare items added since the last
  /// finished round are processed. Called by the scheduler on foreground
  /// start and after every new feed ingestion.
  ///
  /// Calls are coalesced: if a query is already in-flight, this marks
  /// [_hasPendingQuery] and returns without dispatching a second concurrent
  /// query. The pending query is dispatched once the in-flight one responds.
  Future<void> onQueryNeeded() async {
    if (state == BackgroundWorkerState.stopped) {
      return;
    }

    // A new query cycle means there may be new items — clear finished flag.
    _isFinished = false;
    _hasPendingQuery = true;
    await checkpoint();
    _maybeSendQuery();
  }

  /// Resets in-flight batch and query state unconditionally.
  ///
  /// Called by the scheduler on pause/stop so that stale counts do not affect
  /// the next foreground session, even if the worker start was still pending.
  void clearInFlightState() {
    _inFlightBatchCount = 0;
    _queryInFlight = false;
  }

  /// Called by the scheduler after dispatching N enrichment batches.
  ///
  /// Tracks the number of in-flight batches so [onBatchComplete] can
  /// trigger the next query round when the last batch settles.
  void onBatchesDispatched(int count) {
    _inFlightBatchCount += count;
  }

  /// Called by the scheduler when an EnrichItemWorker completes or fails.
  ///
  /// When the last in-flight batch of a round settles and enrichment is not
  /// yet finished, automatically enqueues the next query to drain remaining
  /// bare items.
  void onBatchComplete() {
    if (_inFlightBatchCount > 0) {
      _inFlightBatchCount--;
      if (_inFlightBatchCount == 0 && !_isFinished) {
        // All batches for this round done — query DB for the next window.
        unawaited(onQueryNeeded());
      }
    }
    // _inFlightBatchCount already 0: spurious completion from a resumed
    // worker whose batch predates this session. Ignore to avoid cascading
    // untracked re-queries; startOnForeground already kicked a fresh round.
  }

  /// Dispatches a query to the isolate if one is pending and none is in-flight.
  ///
  /// Guards against concurrent queries: only one query may be in-flight at a
  /// time. Extra [onQueryNeeded] calls coalesce into [_hasPendingQuery] and
  /// are dispatched here once the current query responds.
  void _maybeSendQuery() {
    if (!_hasPendingQuery) return;
    if (_queryInFlight) return;
    if (state != BackgroundWorkerState.started || !isIsolateRunning) return;

    _queryInFlight = true;
    _hasPendingQuery = false;
    sendMessage(
      WorkerMessage(
        opcode: WorkerOpcode.enqueueWork,
        workerId: workerId,
        payload: <String, dynamic>{'query': 'bareItems'},
      ),
    );
  }

  @override
  Future<void> onStart() async {
    await spawnIsolate(
      entryPoint: _isolateEntry,
      args: <Object?>[
        _databaseConnectPort, // SendPort? — null in tests
        _databasePath, // fallback path used when connectPort is null
      ],
    );

    // Dispatch any query that was requested before the isolate was ready.
    _maybeSendQuery();
  }

  @override
  Future<void> onPause() async {
    // Reset counts so resumed enrich workers don't confuse the re-query
    // trigger on the next foreground transition.
    _inFlightBatchCount = 0;
    _queryInFlight = false;
    await shutdownIsolateGracefully(opcode: WorkerOpcode.pause);
  }

  @override
  Future<void> onStop() async {
    _inFlightBatchCount = 0;
    _queryInFlight = false;
    await shutdownIsolateGracefully(opcode: WorkerOpcode.stop);
  }

  @override
  Future<Map<String, dynamic>> buildCheckpoint() async {
    return <String, dynamic>{
      'hasPendingQuery': _hasPendingQuery,
      'isFinished': _isFinished,
    };
  }

  @override
  Future<void> restoreFromCheckpoint(Map<String, dynamic> checkpoint) async {
    final pending = checkpoint['hasPendingQuery'];
    _hasPendingQuery = switch (pending) {
      final bool v => v,
      final String v => v == 'true',
      _ => false,
    };
    final finished = checkpoint['isFinished'];
    _isFinished = switch (finished) {
      final bool v => v,
      final String v => v == 'true',
      _ => false,
    };
  }

  @override
  Future<void> resetWorkState() async {
    _hasPendingQuery = false;
    _queryInFlight = false;
    _isFinished = false;
    _inFlightBatchCount = 0;
  }

  @override
  void onIsolateMessage(dynamic message) {
    if (message is! Map) {
      return;
    }

    final type = message['type']?.toString() ?? '';

    // Query response received: clear the in-flight guard before any dispatch so
    // _maybeSendQuery can immediately send the next coalesced query if needed.
    if (type == 'batchesReady' || type == 'noBareItems') {
      _queryInFlight = false;
    }

    if (type == 'batchesReady') {
      final batches = message['batches'] as List?;
      if (batches != null) {
        _onMessageSent?.call(
          WorkerMessage(
            opcode: WorkerOpcode.batchesReady,
            workerId: workerId,
            payload: <String, dynamic>{'batches': batches},
          ),
        );
      }
      unawaited(checkpoint());
      // Dispatch any pending query that arrived while this one was running.
      _maybeSendQuery();
    } else if (type == 'noBareItems') {
      // All bare items enriched — mark finished and persist to ObjectBox.
      // The scheduler will not re-trigger until new feeds are ingested.
      _isFinished = true;
      _onMessageSent?.call(
        WorkerMessage(
          opcode: WorkerOpcode.noBareItems,
          workerId: workerId,
          payload: <String, dynamic>{},
        ),
      );
      unawaited(checkpoint());
      // If a new feed was ingested while this query was running, dispatch it.
      _maybeSendQuery();
    }
  }

  // ----------------
  // Isolate entry point
  // ----------------

  static late SendPort _mainSendPort;
  static late Logger _isolateLog;
  static DatabaseService? _dbService;
  static bool _isShuttingDown = false;
  static ReceivePort? _isolateReceivePort;

  // ── Enrichment batch tuning ───────────────────────────────────────────────
  //
  // High-priority: top _maxPerPlaylist items from EVERY playlist with
  // unenriched items, ordered newest-playlist-first (matching UI order),
  // capped at _highBatchSize total rows. No fixed playlist count — the query
  // spans as many playlists as needed to fill the batch, so small single-work
  // playlists don't leave the batch under-populated.
  //
  // Low-priority: items beyond position _maxPerPlaylist per playlist, drained
  // in batches of _lowBatchSize once the high-priority window returns fewer
  // than _highBatchSize rows (meaning we are near the end of that phase).
  static const int _maxPerPlaylist = 8;
  static const int _highBatchSize = 48;
  static const int _lowBatchSize = 50;
  static const int _parallelBatchTarget = 6;
  static const int _highQueryLimit = _highBatchSize * _parallelBatchTarget;
  static const int _lowQueryLimit = _lowBatchSize * _parallelBatchTarget;

  static void _isolateEntry(List<Object?> args) {
    final sendPort = args[0]! as SendPort;
    final connectPort = args[1] as SendPort?;
    final databasePath = args[2]! as String;

    _isolateLog = Logger('ItemEnrichmentQueryWorker[Isolate]');
    _mainSendPort = sendPort;
    _isShuttingDown = false;

    unawaited(_connectAndHandshake(connectPort, databasePath));
  }

  static Future<void> _connectAndHandshake(
    SendPort? connectPort,
    String databasePath,
  ) async {
    _dbService = await _openDatabase(connectPort, databasePath);

    _isolateReceivePort = ReceivePort()..listen(_handleMessageInIsolate);
    _mainSendPort.send(_isolateReceivePort!.sendPort);
  }

  /// Opens a [DatabaseService] connection for bare-item queries.
  ///
  /// Prefers the shared [DriftIsolate] via [connectPort] so reads and writes
  /// are serialised through one executor. Falls back to a direct
  /// [NativeDatabase] when [connectPort] is null (tests).
  static Future<DatabaseService?> _openDatabase(
    SendPort? connectPort,
    String path,
  ) async {
    if (connectPort != null) {
      try {
        final connection = await DriftIsolate.fromConnectPort(
          connectPort,
        ).connect();
        _isolateLog.info('Connected to shared DriftIsolate');
        return DatabaseService(AppDatabase.fromConnection(connection));
      } on Object catch (e, stack) {
        _isolateLog.warning('DriftIsolate connect failed', e, stack);
        return null;
      }
    }
    if (path.isEmpty) {
      _isolateLog.warning('Empty database path — bare-item queries skipped');
      return null;
    }
    try {
      final db = AppDatabase.forTesting(
        NativeDatabase(
          File(path),
          setup: (rawDb) {
            rawDb
              ..execute('PRAGMA busy_timeout = 5000')
              ..execute('PRAGMA journal_mode = WAL');
          },
        ),
      );
      _isolateLog.info('Opened direct NativeDatabase at $path');
      return DatabaseService(db);
    } on Object catch (e, stack) {
      _isolateLog.warning('Failed to open NativeDatabase at $path', e, stack);
      return null;
    }
  }

  static void _handleMessageInIsolate(dynamic message) {
    if (message is! List || message.length < 3) {
      return;
    }

    try {
      final workerMessage = WorkerMessage.fromList(message);

      if (workerMessage.opcode == WorkerOpcode.pause ||
          workerMessage.opcode == WorkerOpcode.stop) {
        unawaited(_shutdownIsolate(workerMessage.opcode.name));
        return;
      }

      if (_isShuttingDown) {
        return;
      }

      if (workerMessage.opcode == WorkerOpcode.enqueueWork) {
        unawaited(_queryAndBuildBatches());
      }
    } on Object catch (e, stack) {
      _isolateLog.warning('Failed to handle message in isolate', e, stack);
    }
  }

  static Future<void> _queryAndBuildBatches() async {
    try {
      if (_isShuttingDown) {
        return;
      }

      final service = _dbService;
      if (service == null) {
        _isolateLog.warning('No DB service — cannot query bare items');
        if (!_isShuttingDown) {
          _mainSendPort.send(<String, Object>{'type': 'noBareItems'});
        }
        return;
      }

      // High priority: top _maxPerPlaylist items from every playlist with
      // unenriched items, newest-playlist-first, capped at _highBatchSize.
      // Database query excludes rows marked as enrichment-failed.
      final highRows = await service.loadHighPriorityBareItems(
        maxPerPlaylist: _maxPerPlaylist,
        maxItems: _highQueryLimit,
      );

      // When the high-priority window is below its full capacity, we're on
      // the last round of high-priority items. Start draining low-priority
      // items in parallel so there is no idle gap between phases.
      final nearEndOfHighPriority = highRows.length < _highQueryLimit;

      final lowRows = nearEndOfHighPriority
          ? await service.loadLowPriorityBareItems(
              maxPerPlaylist: _maxPerPlaylist,
              maxTotal: _lowQueryLimit,
            )
          : const <(String, String?, String, int)>[];

      final batches = <Map<String, String>>[];
      var totalRowsQueried = highRows.length + lowRows.length;
      var totalItemsSent = 0;
      var totalRowsWithCid = 0;

      void addBatches(
        List<(String, String?, String, int)> rows,
        int targetBatchSize,
      ) {
        var batch = <String, String>{};
        for (final row in rows) {
          final cid = service.buildTokenCidFromProvenanceJson(row.$2);
          if (cid != null && cid.isNotEmpty) {
            totalRowsWithCid++;
            batch[cid] = row.$1; // cid → itemId
            if (batch.length >= targetBatchSize) {
              totalItemsSent += batch.length;
              batches.add(batch);
              batch = <String, String>{};
            }
          }
        }
        if (batch.isNotEmpty) {
          totalItemsSent += batch.length;
          batches.add(batch);
        }
      }

      if (highRows.isNotEmpty) {
        addBatches(highRows, _highBatchSize);
      }
      if (lowRows.isNotEmpty) {
        addBatches(lowRows, _lowBatchSize);
      }

      if (batches.isEmpty) {
        _isolateLog.fine(
          'No CIDs extractable — high: ${highRows.length}, '
          'low: ${lowRows.length}',
        );
        if (!_isShuttingDown) {
          _mainSendPort.send(<String, Object>{'type': 'noBareItems'});
        }
        return;
      }

      _isolateLog.info(
        'Built ${batches.length} batch(es): '
        'queried=$totalRowsQueried (high=${highRows.length}, low=${lowRows.length}), '
        'sent=$totalItemsSent (rowsWithCid=$totalRowsWithCid)',
      );
      if (!_isShuttingDown) {
        _mainSendPort.send(<String, Object>{
          'type': 'batchesReady',
          'batches': batches,
        });
      }
    } on Object catch (e, stack) {
      _isolateLog.warning('Failed to query and build batches', e, stack);
      if (!_isShuttingDown) {
        _mainSendPort.send(<String, Object>{'type': 'noBareItems'});
      }
    }
  }

  static Future<void> _shutdownIsolate(String action) async {
    if (_isShuttingDown) {
      return;
    }
    _isShuttingDown = true;

    await _closeDatabase();
    _isolateReceivePort?.close();
    _isolateReceivePort = null;

    _mainSendPort.send(<String, Object>{
      'type': 'lifecycleAck',
      'action': action,
    });
  }

  static Future<void> _closeDatabase() async {
    final service = _dbService;
    _dbService = null;
    if (service == null) {
      return;
    }
    try {
      await service.checkpoint();
      await service.close();
    } on Object catch (e, stack) {
      _isolateLog.warning('Failed closing query worker database', e, stack);
    }
  }
}
