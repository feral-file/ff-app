import 'package:app/app/providers/seed_database_ready_provider.dart';
import 'package:app/app/providers/services_provider.dart';
import 'package:app/infra/database/seed_database_gate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(SeedDatabaseGate.resetForTesting);

  test(
    'setReady runs onReady before isSeedDatabaseReady becomes true',
    () async {
      SeedDatabaseGate.complete();

      bool? readyDuringOnReady;
      final container = ProviderContainer.test(
        overrides: [
          ensureTrackedAddressesHavePlaylistsAndResumeProvider.overrideWith(
            (ref) => () async {},
          ),
          seedDatabaseReadyActionsProvider.overrideWith((ref) {
            return SeedDatabaseReadyActions(
              onNotReady: () async {},
              onReady: () async {
                readyDuringOnReady = ref.read(isSeedDatabaseReadyProvider);
              },
            );
          }),
        ],
      );
      addTearDown(container.dispose);

      container
          .read(isSeedDatabaseReadyProvider.notifier)
          .seedReadyDirect = false;
      await container.read(isSeedDatabaseReadyProvider.notifier).setReady();

      expect(readyDuringOnReady, isFalse);
      expect(container.read(isSeedDatabaseReadyProvider), isTrue);
    },
  );

  test(
    'setReady runs ensureTrackedAddressesHavePlaylistsAndResume once',
    () async {
      SeedDatabaseGate.complete();

      var ensureCalls = 0;
      final container = ProviderContainer.test(
        overrides: [
          ensureTrackedAddressesHavePlaylistsAndResumeProvider.overrideWith(
            (ref) => () async {
              ensureCalls++;
            },
          ),
          seedDatabaseReadyActionsProvider.overrideWith((ref) {
            return SeedDatabaseReadyActions(
              onNotReady: () async {},
              // Production [onReady] invalidates providers instead of calling
              // ensure directly; this stub invokes ensure once to assert
              // [setReady] awaits [onReady] and the override is visible.
              onReady: () async {
                await ref.read(
                  ensureTrackedAddressesHavePlaylistsAndResumeProvider,
                )();
              },
            );
          }),
        ],
      );
      addTearDown(container.dispose);

      container
          .read(isSeedDatabaseReadyProvider.notifier)
          .seedReadyDirect = false;
      await container.read(isSeedDatabaseReadyProvider.notifier).setReady();

      expect(ensureCalls, 1);
    },
  );
}
