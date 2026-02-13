import 'package:app/app/providers/app_lifecycle_provider.dart';
import 'package:app/app/providers/background_workers_provider.dart';
import 'package:app/infra/database/app_database.dart';
import 'package:app/infra/database/database_service.dart';
import 'package:app/infra/indexer/isolate/address_indexing_worker.dart';
import 'package:app/infra/workers/background_workers_manager.dart';
import 'package:app/infra/workers/index_single_address_worker.dart';
import 'package:app/infra/workers/ingest_feed_channel_worker.dart';
import 'package:app/infra/workers/item_enrichment_worker.dart';
import 'package:app/infra/workers/worker_database_session.dart';
import 'package:drift/native.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'provider_test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('appLifecycleProvider builds with a lifecycle state', () {
    // Unit test: verifies lifecycle notifier exposes current lifecycle value.
    final stateStore = InMemoryWorkerStateStore();
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final databaseService = DatabaseService(db);
    final itemEnrichmentWorker = ItemEnrichmentWorker(
      workerStateService: stateStore,
      databaseSession: WorkerDatabaseSession(
        openDatabaseService: () async => databaseService,
      ),
    );
    final ingestFeedWorker = IngestFeedChannelWorker(
      workerStateService: stateStore,
      itemEnrichmentWorker: itemEnrichmentWorker,
    );
    final indexSingleAddressWorker = IndexSingleAddressWorker(
      workerStateService: stateStore,
      worker: AddressIndexingWorker(
        endpoint: 'https://example.invalid',
        apiKey: '',
      ),
    );

    final container = ProviderContainer.test(
      overrides: [
        backgroundWorkersManagerProvider.overrideWithValue(
          BackgroundWorkersManager(
            indexSingleAddressWorker: indexSingleAddressWorker,
            ingestFeedChannelWorker: ingestFeedWorker,
          ),
        ),
      ],
    );
    addTearDown(indexSingleAddressWorker.stop);
    addTearDown(ingestFeedWorker.stop);
    addTearDown(itemEnrichmentWorker.stop);
    addTearDown(db.close);
    addTearDown(container.dispose);

    final state = container.read(appLifecycleProvider);
    expect(state, isA<AppLifecycleState>());
  });
}
