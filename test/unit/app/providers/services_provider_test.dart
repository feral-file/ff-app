import 'package:app/app/providers/background_workers_provider.dart';
import 'package:app/app/providers/services_provider.dart';
import 'package:app/infra/config/app_state_service.dart';
import 'package:app/infra/database/app_database.dart';
import 'package:app/infra/database/database_provider.dart';
import 'package:app/infra/database/database_service.dart';
import 'package:app/infra/graphql/indexer_client_provider.dart';
import 'package:app/infra/services/address_service.dart';
import 'package:app/infra/services/domain_address_service.dart';
import 'package:app/infra/workers/worker_scheduler.dart';
import 'package:app/infra/workers/worker_state_service.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'provider_test_helpers.dart';

void main() {
  test('services providers assemble from dependency overrides', () {
    // Verifies service-composition providers resolve with test doubles.
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final dbService = DatabaseService(db);
    final stateStore = InMemoryWorkerStateStore();
    final container = ProviderContainer.test(
      overrides: [
        databaseServiceProvider.overrideWith((ref) => dbService),
        appStateServiceProvider.overrideWithValue(MockAppStateService()),
        indexerClientProvider.overrideWithValue(FakeIndexerClient()),
        domainAddressServiceProvider.overrideWithValue(
          DomainAddressService(
            resolverUrl: '',
            resolverApiKey: '',
          ),
        ),
        workerStateServiceProvider.overrideWithValue(stateStore),
        workerSchedulerProvider.overrideWith(
          (ref) => WorkerScheduler(
            workerStateService: ref.read(workerStateServiceProvider),
            databaseService: ref.read(databaseServiceProvider),
            indexerEndpoint: '',
            indexerApiKey: '',
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    expect(container.read(addressServiceProvider), isA<AddressService>());
  });
}
