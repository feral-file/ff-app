import 'package:app/app/providers/database_service_provider.dart';
import 'package:app/app/providers/seed_database_ready_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Notifier that always reports not ready (for testing).
class _NotReadyNotifier extends SeedDatabaseReadyNotifier {
  @override
  bool build() => false;
}

/// Verifies the readiness-aware DB boundary: when not ready, no real DB
/// subscriptions are created; consumers get empty data from in-memory stub.
void main() {
  group('databaseServiceProvider readiness gate', () {
    test('when not ready, returns DatabaseService with empty data', () async {
      final container = ProviderContainer(
        overrides: [
          isSeedDatabaseReadyProvider.overrideWith(_NotReadyNotifier.new),
        ],
      );
      addTearDown(container.dispose);

      final db = container.read(databaseServiceProvider);
      final channels = await db.getChannels();

      expect(channels, isEmpty);
    });
  });
}
