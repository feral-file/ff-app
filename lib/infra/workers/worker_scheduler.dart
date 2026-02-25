import 'dart:async';
import 'dart:io';

import 'package:app/infra/database/database_service.dart';
import 'package:app/infra/workers/background_worker.dart';
import 'package:app/infra/workers/ingest_feed_worker.dart';
import 'package:app/infra/workers/item_enrichment_query_worker.dart';
import 'package:app/infra/workers/worker_fleet.dart';
import 'package:app/infra/workers/worker_message.dart';
import 'package:app/infra/workers/worker_state_service.dart';
import 'package:drift/isolate.dart';
import 'package:drift/native.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:logging/logging.dart';

/// Central coordinator for background workers.
///
/// Responsibilities:
/// - App lifecycle management (foreground/background/stop)
/// - Event-driven worker triggering (address added, feed ingested)
/// - Message routing between workers
/// - Round-robin work distribution to [EnrichItemWorkersFleet]
///
/// Workers are initialised lazily on the first scheduling call so that
/// [databasePathResolver] is only invoked when needed.
class WorkerScheduler {
  /// Creates a scheduler.
  ///
  /// [databasePathResolver] is called once when the query worker first starts;
  /// it should return the absolute path of the shared SQLite database file.
  /// [databaseService] is the main-isolate [DatabaseService] passed to enrich
  /// and address workers so their DB writes stay on the main isolate.
  WorkerScheduler({
    required this.databasePathResolver,
    required this.workerStateService,
    required this.databaseService,
    required this.indexerEndpoint,
    required this.indexerApiKey,
    required this.maxEnrichmentWorkers,
  });

  /// Resolves the on-disk database path the first time the query worker starts.
  final Future<String> Function() databasePathResolver;

  /// Shared checkpoint store for all workers.
  final WorkerStateStore workerStateService;

  /// Main-isolate database service forwarded to enrich/address worker fleets.
  ///
  /// Enrich and address workers no longer open DB connections in their
  /// isolates; instead they send write payloads back to the main isolate
  /// where this service persists them.
  final DatabaseService databaseService;

  /// Indexer API endpoint forwarded to worker isolates.
  final String indexerEndpoint;

  /// Indexer API key forwarded to worker isolates.
  final String indexerApiKey;

  /// Maximum concurrent enrichment workers in the pool.
  final int maxEnrichmentWorkers;

  late final Logger _log = Logger('WorkerScheduler');

  // Memoises the initialization future so concurrent callers await the same
  // promise. Avoids two problems:
  // 1. Double-entry: _databasePath was set mid-init but workers weren't yet
  //    assigned, causing LateInitializationError on guards that only check
  //    _databasePath.isEmpty.
  // 2. Double-init: two concurrent callers both enter before _databasePath
  //    was set, running full init twice and orphaning the first set of workers.
  // Reset to null in stopAll() so a re-start after stop re-initialises cleanly.
  Future<void>? _initFuture;

  String _databasePath = '';

  // Shared Drift-managed database isolate for all worker DB operations.
  //
  // A single DriftIsolate serialises all cross-worker writes through one
  // executor, avoiding concurrent SQLite write-lock contention.
  // Null until _ensureInitialized() runs.
  DriftIsolate? _workerDriftIsolate;

  // Workers — assigned once in _ensureInitialized(); always set before access.
  late IngestFeedWorker _ingestFeedWorker;
  late ItemEnrichmentQueryWorker _queryWorker;
  late IndexAddressWorkersFleet _indexAddressFleet;
  late EnrichItemWorkersFleet _enrichFleet;

  /// Forwards the query worker's in-flight batch count.
  ///
  /// Exposed for testing only; do not read in production code.
  @visibleForTesting
  int get inFlightBatchCount => _queryWorker.inFlightBatchCount;

  // ── Initialization ───────────────────────────────────────────────────────

  /// Resolves the database path and creates all worker instances.
  ///
  /// No isolates are spawned here; workers remain idle until started.
  /// Concurrent callers share a single in-flight future so initialization
  /// runs exactly once per lifecycle (reset by [stopAll]).
  Future<void> _ensureInitialized() => _initFuture ??= _doInitialize();

  Future<void> _doInitialize() async {
    _databasePath = await databasePathResolver();
    _log.info('Scheduler initialised. DB: $_databasePath');

    // Workers are created without a DriftIsolate connectPort here.
    // The shared DriftIsolate is spawned lazily in startOnForeground() so
    // that its Isolate.spawn call does not compete with other workers (e.g.
    // IndexerTokensWorker) that start during the same startup window.

    // Single-signal worker (no DB access in its isolate)
    _ingestFeedWorker = IngestFeedWorker(
      workerId: 'ingest_feed_worker',
      workerStateService: workerStateService,
      onMessageSent: handleWorkerMessage,
    );

    // Query worker — connectPort injected later via startOnForeground
    _queryWorker = ItemEnrichmentQueryWorker(
      workerId: 'item_enrichment_query_worker',
      workerStateService: workerStateService,
      databasePath: _databasePath,
      onMessageSent: handleWorkerMessage,
    );

    // Enrichment workers write via the main-isolate DatabaseService; no
    // DriftIsolate connect port needed.
    _enrichFleet = EnrichItemWorkersFleet(
      workerStateService: workerStateService,
      databaseService: databaseService,
      indexerEndpoint: indexerEndpoint,
      indexerApiKey: indexerApiKey,
      poolSize: maxEnrichmentWorkers,
      onMessage: handleWorkerMessage,
    );
    await _enrichFleet.initialize();

    // Address workers also write via the main-isolate DatabaseService.
    _indexAddressFleet = IndexAddressWorkersFleet(
      workerStateService: workerStateService,
      databaseService: databaseService,
      indexerEndpoint: indexerEndpoint,
      indexerApiKey: indexerApiKey,
    );
  }

  // ── Lifecycle ────────────────────────────────────────────────────────────

  /// Ensures the shared Drift isolate is running and its send port is
  /// injected into all workers.
  ///
  /// Spawned lazily (not in [_ensureInitialized]) so the internal
  /// Isolate.spawn call does not compete with other workers that start during
  /// the earliest app-startup window.
  Future<void> _ensureWorkerDriftIsolate() async {
    if (_workerDriftIsolate != null) return;

    // Capture in a local to avoid closing over `this`, which would drag in
    // the unsendable ObjectBox Store via workerStateService.
    final dbPath = _databasePath;
    _workerDriftIsolate = await DriftIsolate.spawn(
      () => NativeDatabase(
        File(dbPath),
        setup: (rawDb) {
          rawDb
            ..execute('PRAGMA busy_timeout = 5000')
            ..execute('PRAGMA journal_mode = WAL');
        },
      ),
    );
    _log.info('Worker DriftIsolate ready');

    // Only the query worker still reads from the shared Drift isolate.
    // Enrich and address workers no longer hold DB connections in isolates.
    _queryWorker.updateConnectPort(_workerDriftIsolate!.connectPort);
  }

  /// Resumes workers when the app returns to the foreground.
  ///
  /// Paused workers (with checkpointed pending work) are restarted.
  /// The scheduler probes whether unenriched items remain; when yes, it starts
  /// the query worker first, then starts enrichment workers.
  Future<void> startOnForeground() async {
    await _ensureInitialized();
    _log.info('startOnForeground');
    // DriftIsolate is ensured lazily inside _triggerEnrichmentQueryAsync.

    if (_ingestFeedWorker.state == BackgroundWorkerState.paused) {
      await _ingestFeedWorker.resume();
    }

    // Always trigger query worker on foreground. The worker itself no-ops when
    // no unenriched items remain, and this avoids creating extra AppDatabase
    // wrappers on the shared executor (Drift duplicate-db warning).
    await _triggerEnrichmentQueryAsync();

    await _indexAddressFleet.startAll();
    await _enrichFleet.startAll();
  }

  /// Checkpoints and pauses all running workers on app background.
  Future<void> pauseOnBackground() async {
    // Not yet initialised — nothing to pause.
    if (_initFuture == null) return;
    await _initFuture;
    _log.info('pauseOnBackground');

    // Clear in-flight count unconditionally. The query worker's start() may
    // still be pending (it is unawaited in _triggerEnrichmentQuery), so its
    // onPause() might not run; this ensures a clean count on next foreground.
    _queryWorker.clearInFlightState();

    await Future.wait(<Future<void>>[
      if (_ingestFeedWorker.state == BackgroundWorkerState.started)
        _ingestFeedWorker.pause(),
      if (_queryWorker.state == BackgroundWorkerState.started)
        _queryWorker.pause(),
      _indexAddressFleet.pauseAll(),
      _enrichFleet.pauseAll(),
    ]);
  }

  /// Stops all workers completely, clearing their checkpoints.
  ///
  /// Also shuts down the shared [DriftIsolate] used for worker DB access.
  Future<void> stopAll() async {
    if (_initFuture == null) return;
    await _initFuture;
    _log.info('stopAll');

    _queryWorker.clearInFlightState();

    await Future.wait(<Future<void>>[
      _ingestFeedWorker.stop(),
      _queryWorker.stop(),
      _indexAddressFleet.stopAll(),
      _enrichFleet.stopAll(),
    ]);

    await _workerDriftIsolate?.shutdownAll();
    _workerDriftIsolate = null;
    _databasePath = '';
    // Reset so _ensureInitialized() re-runs on next start after this stop.
    _initFuture = null;
  }

  // ── Events ───────────────────────────────────────────────────────────────

  /// Called when a new address is added by the user.
  ///
  /// Gets or creates a per-address IndexAddressWorker, starts it if not
  /// already running, and enqueues the address for indexing.
  Future<void> onAddressAdded(String address) async {
    await _ensureInitialized();
    // No DriftIsolate needed — IndexAddressWorker writes via DatabaseService.
    _log.fine('onAddressAdded: $address');

    final worker = _indexAddressFleet.getOrCreateWorker(address);
    if (worker.state != BackgroundWorkerState.started) {
      await worker.start();
    }
    await worker.enqueueAddress(address);
  }

  /// Called when an address is removed by the user.
  ///
  /// Stops the per-address IndexAddressWorker, clears its checkpoint, and
  /// removes it from the fleet.
  Future<void> onAddressRemoved(String address) async {
    if (_initFuture == null) return;
    await _initFuture;
    _log.fine('onAddressRemoved: $address');

    await _indexAddressFleet.stopWorker(address);
  }

  /// Called when a feed channel has been ingested and items need enrichment.
  Future<void> onFeedIngested({String? channelId}) async {
    await _ensureInitialized();
    // IngestFeedWorker runs on the main isolate — no DriftIsolate needed here.
    // The DriftIsolate is ensured lazily in _triggerEnrichmentQueryAsync when
    // the downstream queryNeeded arrives.
    _log.fine('onFeedIngested: $channelId');

    final worker = _ingestFeedWorker;
    if (worker.state != BackgroundWorkerState.started) {
      await worker.start();
    }
    await worker.onFeedIngested();
  }

  // ── Message routing ──────────────────────────────────────────────────────

  /// Routes a [WorkerMessage] from any worker to its intended destination.
  ///
  /// Routing table:
  /// - [WorkerOpcode.queryNeeded] from IngestFeedWorker
  ///   → [ItemEnrichmentQueryWorker.onQueryNeeded] (resets isFinished)
  /// - [WorkerOpcode.batchesReady] from ItemEnrichmentQueryWorker
  ///   → distribute batches round-robin to [EnrichItemWorkersFleet]
  ///   → notify query worker of dispatched count via onBatchesDispatched
  /// - [WorkerOpcode.workComplete] / [WorkerOpcode.workFailed]
  ///   → notify query worker via onBatchComplete; the worker owns the
  ///     re-query loop and will drain remaining bare items automatically
  void handleWorkerMessage(WorkerMessage message) {
    _log.fine('message ${message.opcode} from ${message.workerId}');

    switch (message.opcode) {
      case WorkerOpcode.queryNeeded:
        // IngestFeedWorker finished all ingestion signals → start DB query.
        // Always trigger: new items were just ingested, regardless of whether
        // the query worker previously marked itself as finished.
        _triggerEnrichmentQuery();

      case WorkerOpcode.batchesReady:
        // ItemEnrichmentQueryWorker produced batches → distribute to pool.
        final raw = message.payload['batches'];
        if (raw is List) {
          var dispatched = 0;
          var totalItems = 0;
          for (final item in raw) {
            if (item is Map) {
              totalItems += item.length;
              unawaited(
                _enrichFleet.enqueueAssignment(Map<String, String>.from(item)),
              );
              dispatched++;
            }
          }
          // Tell the query worker how many batches were dispatched so it can
          // track when the full round settles and trigger the next query.
          _queryWorker.onBatchesDispatched(dispatched);
          _log.fine(
            'batchesReady: dispatched $dispatched batch(es), '
            'sent $totalItems item(s) to enrich workers',
          );
        }

      case WorkerOpcode.workComplete:
        final requested = message.payload['requestedCount'];
        final retrieved = message.payload['retrievedCount'];
        final matched = message.payload['matchedCount'];
        final failed = message.payload['failedCount'];
        final requestedByChain = message.payload['requestedByChain'];
        final retrievedByChain = message.payload['retrievedByChain'];
        final missingByChain = message.payload['missingByChain'];
        final missingCidSamples = message.payload['missingCidSamples'];
        if (requested != null || retrieved != null || matched != null) {
          _log.fine(
            'workComplete from ${message.workerId}: '
            'requested=$requested, retrieved=$retrieved, '
            'matched=$matched, failed=$failed, '
            'requestedByChain=$requestedByChain, '
            'retrievedByChain=$retrievedByChain, missingByChain=$missingByChain, '
            'missingCidSamples=$missingCidSamples, payload=${message.payload}',
          );
        } else {
          _log.fine(
            'workComplete from ${message.workerId}: ${message.payload}',
          );
        }
        // Query worker owns the re-query loop and isFinished flag.
        _queryWorker.onBatchComplete();

      case WorkerOpcode.workFailed:
        _log.warning(
          'workFailed from ${message.workerId}: ${message.payload}',
        );
        // Treat failure the same as completion to keep the drain loop moving.
        _queryWorker.onBatchComplete();

      // Opcodes sent scheduler→worker; logged if unexpectedly received here.
      case WorkerOpcode.start:
      case WorkerOpcode.pause:
      case WorkerOpcode.stop:
      case WorkerOpcode.enqueueWork:
      case WorkerOpcode.stateChanged:
      case WorkerOpcode.progressUpdate:
      case WorkerOpcode.noBareItems:
      case WorkerOpcode.enrichmentNeeded:
        _log.fine('unhandled opcode: ${message.opcode}');
    }
  }

  /// Ensures the DriftIsolate is ready, starts the query worker if needed,
  /// then enqueues a query.
  ///
  /// The worker's onQueryNeeded resets [ItemEnrichmentQueryWorker.isFinished]
  /// so that a fresh drain round is started even after a previous session
  /// marked everything as done.
  Future<void> _triggerEnrichmentQueryAsync() async {
    // Query worker still uses the shared DriftIsolate for reads.
    await _ensureWorkerDriftIsolate();
    if (_queryWorker.state != BackgroundWorkerState.started) {
      await _queryWorker.start();
    }
    await _queryWorker.onQueryNeeded();
  }

  void _triggerEnrichmentQuery() {
    unawaited(_triggerEnrichmentQueryAsync());
  }
}
