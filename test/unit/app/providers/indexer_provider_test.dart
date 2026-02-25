import 'package:app/app/providers/services_provider.dart';
import 'package:app/infra/database/app_database.dart';
import 'package:app/infra/database/database_provider.dart';
import 'package:app/infra/database/database_service.dart';
import 'package:app/infra/graphql/indexer_client_provider.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'provider_test_helpers.dart';

void main() {
  setUpAll(() async {
    await ensureDotEnvLoaded();
  });

  test('indexer providers resolve from services_provider', () {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final container = ProviderContainer.test(
      overrides: [
        databaseServiceProvider.overrideWith((ref) => DatabaseService(db)),
        indexerClientProvider.overrideWithValue(FakeIndexerClient()),
      ],
    );
    addTearDown(container.dispose);

    expect(container.read(indexerServiceProvider), isA<Object>());
    expect(container.read(indexerSyncServiceProvider), isA<Object>());
  });
}
