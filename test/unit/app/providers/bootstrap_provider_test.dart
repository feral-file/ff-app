import 'package:app/app/providers/bootstrap_provider.dart';
import 'package:app/app/providers/services_provider.dart';
import 'package:app/infra/config/app_config.dart';
import 'package:app/infra/database/app_database.dart';
import 'package:app/infra/database/database_provider.dart';
import 'package:app/infra/database/database_service.dart';
import 'package:app/infra/services/bootstrap_service.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Unit tests for BootstrapProvider using Riverpod testing patterns.
///
/// Demonstrates proper mocking using provider overrides, following
/// the Riverpod testing guide: https://riverpod.dev/docs/how_to/testing
void main() {
  setUpAll(() async {
    // Initialize AppConfig once for all tests
    await AppConfig.initialize();
  });

  group('BootstrapProvider - Unit Tests with Mocks', () {
    test('bootstrap provider starts with idle state', () {
      // Create a container with no overrides
      final container = ProviderContainer.test();
      addTearDown(container.dispose);

      // Read the initial state
      final initialState = container.read(bootstrapProvider);

      expect(initialState.phase, equals(BootstrapPhase.idle));
      expect(initialState.message, isNull);
    });

    test('bootstrap provider can be read from container', () async {
      // Create fresh database for this test
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);

      // Create container with database service
      final dbService = DatabaseService(db);

      final container = ProviderContainer.test(
        overrides: [
          // Override the database service provider to use our test database
          databaseServiceProvider.overrideWith((ref) => dbService),
        ],
      );
      addTearDown(container.dispose);

      // Read the bootstrap provider
      final bootstrapState = container.read(bootstrapProvider);
      expect(bootstrapState.phase, equals(BootstrapPhase.idle));

      // Verify the database service is available
      expect(dbService, isNotNull);
    });

    test('bootstrap notifier can be triggered via container', () async {
      // Create fresh database for this test
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final dbService = DatabaseService(db);

      final container = ProviderContainer.test(
        overrides: [
          databaseServiceProvider.overrideWith((ref) => dbService),
        ],
      );
      addTearDown(container.dispose);

      // Trigger bootstrap
      await container.read(bootstrapProvider.notifier).bootstrap();

      // Read the final state
      final finalState = container.read(bootstrapProvider);

      expect(
        finalState.phase,
        anyOf([BootstrapPhase.completed, BootstrapPhase.failed]),
      );
    });

    test('container.listen can track bootstrap state changes', () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final dbService = DatabaseService(db);

      final container = ProviderContainer.test(
        overrides: [
          databaseServiceProvider.overrideWith((ref) => dbService),
        ],
      );
      addTearDown(container.dispose);

      final phaseChanges = <BootstrapPhase>[];

      // Listen to state changes
      container.listen<BootstrapStatus>(
        bootstrapProvider,
        (previous, next) {
          phaseChanges.add(next.phase);
        },
      );

      // Trigger bootstrap
      await container.read(bootstrapProvider.notifier).bootstrap();

      // Should have tracked phase changes
      expect(phaseChanges, isNotEmpty);
      expect(
        phaseChanges,
        containsAllInOrder([
          BootstrapPhase.validatingConfiguration,
          BootstrapPhase.settingUpCollection,
          BootstrapPhase.activatingAutoConnectWatcher,
        ]),
      );
      expect(
        phaseChanges,
        contains(anyOf([BootstrapPhase.completed, BootstrapPhase.failed])),
      );
    });

    test('demonstrates mocking BootstrapService', () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final dbService = DatabaseService(db);

      // Create a mock bootstrap service
      final mockBootstrapService = _MockBootstrapService();

      final container = ProviderContainer.test(
        overrides: [
          databaseServiceProvider.overrideWith((ref) => dbService),
          bootstrapServiceProvider.overrideWith(
            (ref) => mockBootstrapService,
          ),
        ],
      );
      addTearDown(container.dispose);

      // Read the mocked service
      final bootstrapService = container.read(bootstrapServiceProvider);
      expect(bootstrapService, equals(mockBootstrapService));
    });
  });

  group('BootstrapProvider - Best Practices', () {
    test('each test creates its own container', () {
      // ✅ Good: Create new container per test
      final container1 = ProviderContainer.test();
      addTearDown(container1.dispose);

      final state1 = container1.read(bootstrapProvider);
      expect(state1.phase, equals(BootstrapPhase.idle));

      // This test is isolated from other tests
    });

    test('always dispose containers with addTearDown', () {
      // ✅ Good: Use addTearDown for automatic cleanup
      final container = ProviderContainer.test();
      addTearDown(container.dispose);

      // Test code here...
      expect(container.read(bootstrapProvider), isNotNull);

      // Container will be automatically disposed after test
    });

    test('use overrides to inject dependencies', () async {
      // ✅ Good: Override providers for testing
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final dbService = DatabaseService(db);

      final container = ProviderContainer.test(
        overrides: [
          databaseServiceProvider.overrideWith((ref) => dbService),
        ],
      );
      addTearDown(container.dispose);

      // Now tests use the overridden database
      expect(dbService, isNotNull);
    });

    test('use container.listen for auto-dispose providers', () async {
      final container = ProviderContainer.test();
      addTearDown(container.dispose);

      // For auto-dispose providers, use listen to keep them alive
      final futureProvider = FutureProvider.autoDispose<int>((ref) async {
        return 42;
      });

      // Keep the provider alive during the test
      final subscription = container.listen<AsyncValue<int>>(
        futureProvider,
        (_, _) {},
      );

      // Wait for completion
      await container.read(futureProvider.future);

      // Read through subscription
      expect(subscription.read().value, equals(42));
    });
  });
}

/// Mock BootstrapService for testing.
class _MockBootstrapService implements BootstrapService {
  @override
  Future<void> bootstrap() async {
    // Mock implementation
    return;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
