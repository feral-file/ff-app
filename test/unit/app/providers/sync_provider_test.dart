import 'package:app/app/providers/indexer_tokens_provider.dart';
import 'package:app/app/providers/sync_provider.dart';
import 'package:app/infra/config/app_state_service.dart';
import 'package:app/infra/database/app_database.dart';
import 'package:app/infra/database/database_provider.dart';
import 'package:app/infra/database/database_service.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'provider_test_helpers.dart';

void main() {
  test(
    'incrementalSyncProvider starts and stops with empty address set',
    () async {
      // Unit test: verifies incremental sync toggles running state for start/stop lifecycle.
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final container = ProviderContainer.test(
        overrides: [
          databaseServiceProvider.overrideWith((ref) => DatabaseService(db)),
          appStateServiceProvider.overrideWithValue(MockAppStateService()),
          indexerTokensWorkerProvider.overrideWithValue(
            FakeIndexerTokensWorker(),
          ),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(incrementalSyncProvider.notifier);
      notifier.start(interval: const Duration(hours: 1));
      expect(container.read(incrementalSyncProvider).isRunning, isTrue);
      await notifier.syncNow();
      notifier.stop();
      expect(container.read(incrementalSyncProvider).isRunning, isFalse);
    },
  );
}
