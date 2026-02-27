import 'dart:async';

import 'package:app/infra/database/database_service.dart';
import 'package:app/infra/workers/background_worker.dart';
import 'package:app/infra/workers/worker_fleet.dart';
import 'package:app/infra/workers/worker_state_service.dart';
import 'package:logging/logging.dart';

/// Central coordinator for background workers.
///
/// Responsibilities:
/// - App lifecycle management (foreground/background/stop)
/// - Per-address personal-playlist indexing via [IndexAddressWorkersFleet]
///
/// Feed-ingestion and item-enrichment workers have been removed; their data
/// is now pre-loaded from the seed database downloaded on first install.
class WorkerScheduler {
  /// Creates a scheduler.
  ///
  /// [databaseService] is the main-isolate [DatabaseService] passed to address
  /// workers so their DB writes stay on the main isolate.
  WorkerScheduler({
    required this.workerStateService,
    required this.databaseService,
    required this.indexerEndpoint,
    required this.indexerApiKey,
  });

  /// Shared checkpoint store for all workers.
  final WorkerStateStore workerStateService;

  /// Main-isolate database service forwarded to address worker fleet.
  final DatabaseService databaseService;

  /// Indexer API endpoint forwarded to worker isolates.
  final String indexerEndpoint;

  /// Indexer API key forwarded to worker isolates.
  final String indexerApiKey;

  late final Logger _log = Logger('WorkerScheduler');

  // Memoises the initialization future so concurrent callers await the same
  // promise. Reset to null in stopAll() so a re-start after stop re-initialises
  // cleanly.
  Future<void>? _initFuture;

  // Workers — assigned once in _ensureInitialized(); always set before access.
  late IndexAddressWorkersFleet _indexAddressFleet;

  // ── Initialization ───────────────────────────────────────────────────────

  Future<void> _ensureInitialized() => _initFuture ??= _doInitialize();

  Future<void> _doInitialize() async {
    _log.info('Scheduler initialised');

    _indexAddressFleet = IndexAddressWorkersFleet(
      workerStateService: workerStateService,
      databaseService: databaseService,
      indexerEndpoint: indexerEndpoint,
      indexerApiKey: indexerApiKey,
    );
  }

  // ── Lifecycle ────────────────────────────────────────────────────────────

  /// Resumes workers when the app returns to the foreground.
  Future<void> startOnForeground() async {
    await _ensureInitialized();
    _log.info('startOnForeground');
    await _indexAddressFleet.startAll();
  }

  /// Checkpoints and pauses all running workers on app background.
  Future<void> pauseOnBackground() async {
    if (_initFuture == null) return;
    await _initFuture;
    _log.info('pauseOnBackground');
    await _indexAddressFleet.pauseAll();
  }

  /// Stops all workers completely, clearing their checkpoints.
  Future<void> stopAll() async {
    if (_initFuture == null) return;
    await _initFuture;
    _log.info('stopAll');
    await _indexAddressFleet.stopAll();
    _initFuture = null;
  }

  // ── Events ───────────────────────────────────────────────────────────────

  /// Called when a new address is added by the user.
  ///
  /// Gets or creates a per-address IndexAddressWorker, starts it if not
  /// already running, and enqueues the address for indexing.
  Future<void> onAddressAdded(String address) async {
    await _ensureInitialized();
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
}
