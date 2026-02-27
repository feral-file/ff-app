// ignore_for_file: public_member_api_docs // fleet wiring is self-descriptive

import 'package:app/infra/database/database_service.dart';
import 'package:app/infra/graphql/indexer_client.dart';
import 'package:app/infra/services/indexer_service.dart';
import 'package:app/infra/workers/background_worker.dart';
import 'package:app/infra/workers/index_address_worker.dart';
import 'package:app/infra/workers/worker_state_service.dart';

/// Lightweight fleet abstraction for managing multiple worker instances
/// of the same type.
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
