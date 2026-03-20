import 'package:app/app/providers/database_service_provider.dart';
import 'package:app/app/providers/sync_provider.dart';
import 'package:app/infra/config/app_state_service.dart';
import 'package:app/infra/database/app_database.dart';
import 'package:app/infra/database/database_service.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// ignore_for_file: cascade_invocations // Reason: test flow favors readable notifier lifecycle steps.

class MockAppStateService implements AppStateService {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

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
