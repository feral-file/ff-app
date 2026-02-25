// ignore_for_file: public_member_api_docs // fleet wiring is self-descriptive

import 'package:app/infra/database/database_service.dart';
import 'package:app/infra/graphql/indexer_client.dart';
import 'package:app/infra/services/indexer_service.dart';
import 'package:app/infra/workers/background_worker.dart';
import 'package:app/infra/workers/enrich_item_worker.dart';
import 'package:app/infra/workers/index_address_worker.dart';
import 'package:app/infra/workers/worker_message.dart';
import 'package:app/infra/workers/worker_state_service.dart';

/// Lightweight fleet abstraction for managing multiple worker instances
/// of the same type.
///
/// Provides round-robin work distribution and lifecycle management for
/// worker pools.
abstract class WorkerFleet<T> {
  /// Creates a worker fleet with the given workers.
  WorkerFleet(this.workers);

  /// All workers in this fleet.
  final List<T> workers;

  /// Number of workers in the fleet.
  int get size => workers.length;

  /// Starts all workers in the fleet.
  Future<void> startAll();

  /// Pauses all workers in the fleet.
  Future<void> pauseAll();

  /// Stops all workers in the fleet.
  Future<void> stopAll();
}

/// Fleet for [IndexAddressWorker] instances.
///
/// Maintains one worker per address, created on-demand via [getOrCreateWorker].
/// Workers share a common [WorkerStateStore] so each checkpoints independently.
///
/// DB writes are routed to the main isolate via the injected [DatabaseService];
/// worker isolates carry no database connection.
class IndexAddressWorkersFleet {
  /// Creates a fleet using the given dependencies.
  ///
  /// [databaseService] is the main-isolate [DatabaseService] used to persist
  /// token results after each address-indexing round completes.
  IndexAddressWorkersFleet({
    required this.workerStateService,
    required this.databaseService,
    required this.indexerEndpoint,
    required this.indexerApiKey,
  });

  final WorkerStateStore workerStateService;

  /// Main-isolate database service for token ingestion writes.
  final DatabaseService databaseService;

  final String indexerEndpoint;
  final String indexerApiKey;

  final Map<String, IndexAddressWorker> _workers = {};

  /// Returns the worker for [address], creating it if it doesn't exist yet.
  IndexAddressWorker getOrCreateWorker(String address) {
    return _workers.putIfAbsent(
      address,
      () => IndexAddressWorker(
        workerId: 'index_address_worker::$address',
        workerStateService: workerStateService,
        // Factory is satisfied; actual service is created inside the isolate
        // from endpoint/apiKey args (see IndexAddressWorker._isolateEntry).
        indexerServiceFactory: () => IndexerService(
          client: IndexerClient(
            endpoint: indexerEndpoint,
            defaultHeaders: <String, String>{
              'Content-Type': 'application/json',
              if (indexerApiKey.isNotEmpty)
                'Authorization': _formatApiKeyHeaderValue(indexerApiKey),
            },
          ),
        ),
        databaseService: databaseService,
        indexerEndpoint: indexerEndpoint,
        indexerApiKey: indexerApiKey,
      ),
    );
  }

  /// Starts all workers that were previously paused (have pending work).
  Future<void> startAll() async {
    for (final worker in _workers.values) {
      if (worker.state == BackgroundWorkerState.paused) {
        await worker.resume();
      }
    }
  }

  /// Pauses all currently running workers, checkpointing their queues.
  Future<void> pauseAll() async {
    for (final worker in _workers.values) {
      if (worker.state == BackgroundWorkerState.started) {
        await worker.pause();
      }
    }
  }

  /// Stops the worker for a specific address, clears its checkpoint, and
  /// removes it from the fleet.
  Future<void> stopWorker(String address) async {
    final worker = _workers[address];
    if (worker == null) return;

    await worker.stop();
    _workers.remove(address);
  }

  /// Stops all workers (clears checkpoints) and removes them from the fleet.
  Future<void> stopAll() async {
    for (final worker in _workers.values) {
      await worker.stop();
    }
    _workers.clear();
  }

  String _formatApiKeyHeaderValue(String apiKey) {
    if (apiKey.startsWith('ApiKey ')) {
      return apiKey;
    }
    return 'ApiKey $apiKey';
  }
}

/// Pool of [EnrichItemWorker] instances for parallel enrichment.
///
/// Workers are created eagerly in [initialize] up to [poolSize].
/// Work is distributed round-robin via [enqueueAssignment].
///
/// DB writes are routed to the main isolate via the injected [DatabaseService];
/// worker isolates carry no database connection.
class EnrichItemWorkersFleet {
  /// Creates the fleet.
  ///
  /// Call [initialize] before distributing work; [enqueueAssignment] will
  /// auto-initialize if needed.
  EnrichItemWorkersFleet({
    required this.workerStateService,
    required this.databaseService,
    required this.indexerEndpoint,
    required this.indexerApiKey,
    required this.poolSize,
    this.onMessage,
  });

  final WorkerStateStore workerStateService;

  /// Main-isolate database service for enrichment writes.
  final DatabaseService databaseService;

  final String indexerEndpoint;
  final String indexerApiKey;
  final int poolSize;

  /// Called when any worker in the pool sends a [WorkerMessage]
  /// (e.g., workComplete, workFailed).
  final void Function(WorkerMessage)? onMessage;

  final List<EnrichItemWorker> _workers = [];
  int _nextWorkerIndex = 0;

  /// Creates all [poolSize] worker instances.
  ///
  /// Safe to call multiple times; subsequent calls are no-ops.
  Future<void> initialize() async {
    if (_workers.isNotEmpty) return;
    for (var i = 0; i < poolSize; i++) {
      _workers.add(
        EnrichItemWorker(
          workerId: 'enrich_item_worker::$i',
          workerStateService: workerStateService,
          databaseService: databaseService,
          indexerEndpoint: indexerEndpoint,
          indexerApiKey: indexerApiKey,
          onMessageSent: onMessage,
        ),
      );
    }
  }

  /// Sends [batch] (CID → itemId map) to the next worker in the round-robin.
  ///
  /// Auto-initializes the pool if needed. Starts the selected worker if it
  /// isn't already running.
  Future<void> enqueueAssignment(Map<String, String> batch) async {
    if (_workers.isEmpty) {
      await initialize();
    }
    if (_workers.isEmpty) return;

    final worker = _workers[_nextWorkerIndex];
    _nextWorkerIndex = (_nextWorkerIndex + 1) % _workers.length;

    if (worker.state != BackgroundWorkerState.started) {
      await worker.start();
    }
    await worker.enqueueAssignment(batch);
  }

  /// Starts all paused workers (resumes pending enrichment work).
  Future<void> startAll() async {
    for (final worker in _workers) {
      if (worker.state == BackgroundWorkerState.paused) {
        await worker.resume();
      }
    }
  }

  /// Pauses all running workers (they checkpoint in-flight assignments).
  Future<void> pauseAll() async {
    for (final worker in _workers) {
      if (worker.state == BackgroundWorkerState.started) {
        await worker.pause();
      }
    }
  }

  /// Stops all workers and resets the pool.
  Future<void> stopAll() async {
    for (final worker in _workers) {
      await worker.stop();
    }
    _workers.clear();
    _nextWorkerIndex = 0;
  }
}
