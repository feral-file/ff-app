import 'dart:async';
import 'dart:math';

import 'package:app/infra/config/app_config.dart';
import 'package:app/infra/workers/worker_scheduler.dart';
import 'package:app/infra/workers/worker_state_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Coordinator for all background workers.
///
/// Wires together the IndexAddressWorkersFleet, IngestFeedWorker,
/// ItemEnrichmentQueryWorker, and EnrichItemWorkersFleet. Workers are
/// initialised lazily on the first lifecycle event.
final workerSchedulerProvider = Provider<WorkerScheduler>((ref) {
  final scheduler = WorkerScheduler(
    // Matches the path used by AppDatabase._openConnection().
    databasePathResolver: () async {
      final dir = await getApplicationDocumentsDirectory();
      return p.join(dir.path, 'playlist_cache.sqlite');
    },
    workerStateService: ref.read(workerStateServiceProvider),
    indexerEndpoint: AppConfig.indexerApiUrl,
    indexerApiKey: AppConfig.indexerApiKey,
    maxEnrichmentWorkers: max(1, AppConfig.indexerEnrichmentMaxThreads),
  );

  ref.onDispose(() {
    unawaited(scheduler.stopAll());
  });

  return scheduler;
});
