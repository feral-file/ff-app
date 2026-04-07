import 'package:app/app/providers/local_data_cleanup_provider.dart';
import 'package:app/app/providers/seed_database_ready_provider.dart';
import 'package:app/infra/database/app_database.dart';
import 'package:app/infra/database/database_provider.dart';
import 'package:app/infra/services/local_data_cleanup_service.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riverpod/riverpod.dart';

/// Delays [close] so we can assert readiness stays false until close finishes.
class _SlowClosingAppDatabase extends AppDatabase {
  _SlowClosingAppDatabase({required this.closeDelay})
    : super.forTesting(NativeDatabase.memory());

  final Duration closeDelay;
  bool isCloseFullyDone = false;

  @override
  Future<void> close() async {
    await Future<void>.delayed(closeDelay);
    await super.close();
    isCloseFullyDone = true;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'restoreReadinessAfterResetRetryFailed: close and invalidations '
    'before readiness true (PR 342 review)',
    () async {
      const slowClose = Duration(milliseconds: 40);
      final db = _SlowClosingAppDatabase(closeDelay: slowClose);
      addTearDown(() async {
        try {
          await db.close();
        } on Object catch (_) {}
      });

      final events = <String>[];

      final cleanupSpy = LocalDataCleanupService(
        closeAndDeleteDatabase: () async {},
        clearObjectBoxData: () async {},
        clearCachedImages: () async {},
        recreateDatabaseFromSeed: (_) async {},
        runBootstrap: () async {},
        pauseFeedWork: () {},
        pauseTokenPolling: () {},
        invalidateProvidersForRebind: () => events.add('rebind'),
        invalidateReconnectInfraProviders: () => events.add('reconnect'),
      );

      final container = ProviderContainer.test(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          localDataCleanupServiceProvider.overrideWithValue(cleanupSpy),
        ],
      );
      addTearDown(container.dispose);

      final ref = container.read(Provider<Ref>((r) => r));

      // Warm up so appDatabaseProvider exists (matches production).
      expect(container.read(appDatabaseProvider), same(db));

      container
          .read(isSeedDatabaseReadyProvider.notifier)
          .setStateDirectly(false);
      expect(container.read(isSeedDatabaseReadyProvider), isFalse);

      final restoreFuture = restoreReadinessAfterResetRetryFailedForTesting(
        ref,
      );

      await Future<void>.delayed(const Duration(milliseconds: 15));
      expect(container.read(isSeedDatabaseReadyProvider), isFalse);
      expect(db.isCloseFullyDone, isFalse);

      await restoreFuture;

      expect(db.isCloseFullyDone, isTrue);
      expect(container.read(isSeedDatabaseReadyProvider), isTrue);
      expect(events, ['rebind', 'reconnect']);
    },
  );
}
