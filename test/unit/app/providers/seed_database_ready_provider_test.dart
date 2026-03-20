import 'package:app/app/providers/seed_database_ready_provider.dart';
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

      container.read(isSeedDatabaseReadyProvider.notifier).setStateDirectly(
            false,
          );
      await container.read(isSeedDatabaseReadyProvider.notifier).setReady();

      expect(readyDuringOnReady, isFalse);
      expect(container.read(isSeedDatabaseReadyProvider), isTrue);
    },
  );
}
