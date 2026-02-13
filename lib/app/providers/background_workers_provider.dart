// Reason: provider declarations are self-descriptive and match existing style.
// ignore_for_file: public_member_api_docs

import 'dart:async';

import 'package:app/infra/database/database_provider.dart';
import 'package:app/infra/workers/background_workers_manager.dart';
import 'package:app/infra/workers/index_single_address_worker.dart';
import 'package:app/infra/workers/ingest_feed_channel_worker.dart';
import 'package:app/infra/workers/item_enrichment_worker.dart';
import 'package:app/infra/workers/worker_database_session.dart';
import 'package:app/infra/workers/worker_state_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';

final itemEnrichmentWorkerProvider = Provider<ItemEnrichmentWorker>((ref) {
  final worker = ItemEnrichmentWorker(
    workerStateService: ref.read(workerStateServiceProvider),
    databaseSession: WorkerDatabaseSession(
      openDatabaseService: () async => ref.read(databaseServiceProvider),
    ),
    logger: Logger('ItemEnrichmentWorker'),
  );

  ref.onDispose(() {
    unawaited(worker.stop());
  });

  return worker;
});

final ingestFeedChannelWorkerProvider = Provider<IngestFeedChannelWorker>((
  ref,
) {
  final worker = IngestFeedChannelWorker(
    workerStateService: ref.read(workerStateServiceProvider),
    itemEnrichmentWorker: ref.read(itemEnrichmentWorkerProvider),
    logger: Logger('IngestFeedChannelWorker'),
  );

  ref.onDispose(() {
    unawaited(worker.stop());
  });

  return worker;
});

final indexSingleAddressWorkerProvider = Provider<IndexSingleAddressWorker>((
  ref,
) {
  final worker = IndexSingleAddressWorker(
    workerStateService: ref.read(workerStateServiceProvider),
    logger: Logger('IndexSingleAddressWorker'),
  );

  ref.onDispose(() {
    unawaited(worker.stop());
  });

  return worker;
});

final backgroundWorkersManagerProvider = Provider<BackgroundWorkersManager>((
  ref,
) {
  return BackgroundWorkersManager(
    indexSingleAddressWorker: ref.read(indexSingleAddressWorkerProvider),
    ingestFeedChannelWorker: ref.read(ingestFeedChannelWorkerProvider),
    logger: Logger('BackgroundWorkersManager'),
  );
});
