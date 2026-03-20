import 'package:app/app/providers/database_service_provider.dart';
import 'package:app/app/providers/services_provider.dart';
import 'package:app/infra/config/app_state_service.dart';
import 'package:app/infra/database/app_database.dart';
import 'package:app/infra/database/database_service.dart';
import 'package:app/infra/graphql/indexer_client_provider.dart';
import 'package:app/infra/services/address_service.dart';
import 'package:app/infra/services/domain_address_service.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../infra/services/fake_indexer_service_isolate.dart';
import 'provider_test_helpers.dart';

void main() {
  test('services providers assemble from dependency overrides', () async {
    await ensureDotEnvLoaded();
    // Verifies service-composition providers resolve with test doubles.
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final dbService = DatabaseService(db);
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
        indexerServiceIsolateProvider.overrideWithValue(
          FakeIndexerServiceIsolate(),
        ),
      ],
    );
    addTearDown(container.dispose);

    expect(container.read(addressServiceProvider), isA<AddressService>());
  });
}
