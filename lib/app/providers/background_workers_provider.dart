import 'dart:async';

import 'package:app/infra/config/app_config.dart';
import 'package:app/infra/database/database_provider.dart';
import 'package:app/infra/workers/worker_scheduler.dart';
import 'package:app/infra/workers/worker_state_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Coordinator for background workers.
///
/// Wires together the address-worker fleet used for personal-playlist indexing.
/// Feed-ingestion and enrichment workers have been removed; all curated feed
/// data is pre-loaded from the seed database downloaded on first install.
///
/// The main-isolate database service is injected so that address workers can
/// route their DB writes back to the main isolate.
final workerSchedulerProvider = Provider<WorkerScheduler>((ref) {
  final scheduler = WorkerScheduler(
    workerStateService: ref.read(workerStateServiceProvider),
    databaseService: ref.read(databaseServiceProvider),
    indexerEndpoint: AppConfig.indexerApiUrl,
    indexerApiKey: AppConfig.indexerApiKey,
  );

  ref.onDispose(() {
    unawaited(scheduler.stopAll());
  });

  return scheduler;
});
