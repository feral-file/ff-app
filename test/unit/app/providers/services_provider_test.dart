import 'package:app/app/providers/indexer_provider.dart';
import 'package:app/app/providers/services_provider.dart';
import 'package:app/infra/config/app_state_service.dart';
import 'package:app/infra/database/app_database.dart';
import 'package:app/infra/database/database_provider.dart';
import 'package:app/infra/database/database_service.dart';
import 'package:app/infra/services/address_indexing_process_service.dart';
import 'package:app/infra/services/address_service.dart';
import 'package:app/infra/services/domain_address_service.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'provider_test_helpers.dart';

void main() {
  test('services providers assemble from dependency overrides', () {
    // Unit test: verifies service-composition providers resolve with test doubles.
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final dbService = DatabaseService(db);
    final container = ProviderContainer.test(
      overrides: [
        databaseServiceProvider.overrideWith((ref) => dbService),
        indexerServiceProvider.overrideWithValue(FakeIndexerService()),
        indexerSyncServiceProvider.overrideWithValue(FakeIndexerSyncService()),
        appStateServiceProvider.overrideWithValue(MockAppStateService()),
        domainAddressServiceProvider.overrideWithValue(
          DomainAddressService(
            resolverUrl: '',
            resolverApiKey: '',
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    expect(
      container.read(addressIndexingProcessServiceProvider),
      isA<AddressIndexingProcessService>(),
    );
    expect(container.read(addressServiceProvider), isA<AddressService>());
  });
}
