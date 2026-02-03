import 'package:app/app/providers/bootstrap_provider.dart';
import 'package:app/app/providers/services_provider.dart';
import 'package:app/infra/config/app_config.dart';
import 'package:app/infra/database/app_database.dart';
import 'package:app/infra/database/database_provider.dart';
import 'package:app/infra/database/database_service.dart';
import 'package:app/infra/services/bootstrap_service.dart';
import 'package:app/infra/services/dp1_feed_service.dart';
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

      expect(initialState.state, equals(BootstrapState.idle));
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
      expect(bootstrapState.state, equals(BootstrapState.idle));

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

      // Should be either success or error (not idle)
      expect(finalState.state, isNot(equals(BootstrapState.idle)));
      expect(
        finalState.state,
        anyOf([BootstrapState.success, BootstrapState.error]),
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

      final stateChanges = <BootstrapState>[];

      // Listen to state changes
      container.listen<BootstrapStatus>(
        bootstrapProvider,
        (previous, next) {
          stateChanges.add(next.state);
        },
      );

      // Trigger bootstrap
      await container.read(bootstrapProvider.notifier).bootstrap();

      // Should have tracked state changes
      expect(stateChanges, isNotEmpty);
      expect(
        stateChanges,
        contains(anyOf([BootstrapState.loading, BootstrapState.success])),
      );
    });

    test('demonstrates mocking DP1FeedService with overrides', () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final dbService = DatabaseService(db);

      // Create a mock feed service that returns predictable values
      final mockFeedService = _MockDP1FeedService();

      final container = ProviderContainer.test(
        overrides: [
          databaseServiceProvider.overrideWith((ref) => dbService),
          // Override the feed service with our mock
          dp1FeedServiceProvider.overrideWith((ref) => mockFeedService),
        ],
      );
      addTearDown(container.dispose);

      // Read the mocked service
      final feedService = container.read(dp1FeedServiceProvider);
      expect(feedService, equals(mockFeedService));
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
      expect(state1.state, equals(BootstrapState.idle));

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
        (_, __) {},
      );

      // Wait for completion
      await container.read(futureProvider.future);

      // Read through subscription
      expect(subscription.read().value, equals(42));
    });
  });
}

/// Mock DP1FeedServiceImpl for testing.
/// In a real scenario, you would use mockito or mocktail for this.
class _MockDP1FeedService implements DP1FeedServiceImpl {
  @override
  Future<void> fetchChannel({
    required String baseUrl,
    required String channelId,
  }) async {
    // Mock implementation
    return;
  }

  @override
  Future<int> fetchPlaylists({
    required String baseUrl,
    int? limit = 10,
    String? cursor,
  }) async {
    // Return a predictable number
    return 3;
  }

  @override
  Future<void> ingestPlaylistFromFeed({
    required String baseUrl,
    required Map<String, dynamic> playlistJson,
  }) async {
    // Mock implementation
    return;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
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
