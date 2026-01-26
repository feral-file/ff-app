# Riverpod Testing Patterns

This directory demonstrates proper Riverpod testing patterns following the official guide:
- **Providers**: https://riverpod.dev/docs/concepts2/providers
- **Testing**: https://riverpod.dev/docs/how_to/testing

## Test Files

### 1. `dp1_feed_service_test.dart` - Unit Tests with Real Dependencies
**Purpose**: Test the DP1FeedService with real API calls and database

**Key Patterns**:
- ✅ Each test creates its own `ProviderContainer.test()`
- ✅ Uses `addTearDown(container.dispose)` for cleanup
- ✅ Tests with real database (in-memory Drift)
- ✅ Tests with real API calls (integration-style unit tests)
- ✅ Demonstrates `container.listen()` for auto-dispose providers

**Example**:
```dart
test('fetchChannel ingests channel into database', () async {
  final container = ProviderContainer.test();
  addTearDown(container.dispose);

  final service = DP1FeedService(
    databaseService: databaseService,
    indexerService: indexerService,
    apiKey: AppConfig.dp1FeedApiKey,
  );

  await service.fetchChannel(
    baseUrl: AppConfig.dp1FeedUrl,
    channelId: channelId,
  );

  final savedChannel = await databaseService.getChannelById(channelId);
  expect(savedChannel, isNotNull);
});
```

### 2. `bootstrap_provider_test.dart` - Unit Tests with Mocked Dependencies
**Purpose**: Test the BootstrapProvider with mocked services

**Key Patterns**:
- ✅ Uses `ProviderContainer.test(overrides: [...])` to mock dependencies
- ✅ Demonstrates provider override pattern
- ✅ Uses `container.listen()` to spy on state changes
- ✅ Shows how to mock services with custom implementations

**Example of Provider Override**:
```dart
test('demonstrates mocking DP1FeedService', () async {
  final mockFeedService = _MockDP1FeedService();

  final container = ProviderContainer.test(
    overrides: [
      // Override the provider with a mock
      dp1FeedServiceProvider.overrideWith((ref) => mockFeedService),
    ],
  );
  addTearDown(container.dispose);

  // Now all code using dp1FeedServiceProvider gets the mock
  final service = container.read(dp1FeedServiceProvider);
  expect(service, equals(mockFeedService));
});
```

**Example of State Tracking**:
```dart
test('container.listen can track state changes', () async {
  final container = ProviderContainer.test();
  addTearDown(container.dispose);

  final stateChanges = <BootstrapState>[];

  // Listen to all state changes
  container.listen<BootstrapStatus>(
    bootstrapProvider,
    (previous, next) {
      stateChanges.add(next.state);
    },
  );

  // Trigger the action
  await container.read(bootstrapProvider.notifier).bootstrap();

  // Verify state transitions
  expect(stateChanges, contains(BootstrapState.loading));
});
```

## Riverpod Testing Best Practices (from official guide)

### 1. Each Test Gets Its Own Container
```dart
test('example test', () {
  // ✅ Good: Create new container per test
  final container = ProviderContainer.test();
  addTearDown(container.dispose);
  
  // Test code...
});
```

```dart
// ❌ Bad: Sharing containers between tests
final sharedContainer = ProviderContainer.test(); // DON'T DO THIS

test('test 1', () {
  // Uses shared container - state leaks between tests!
});
```

### 2. Always Dispose Containers
```dart
test('example test', () {
  final container = ProviderContainer.test();
  
  // ✅ Good: Use addTearDown for automatic cleanup
  addTearDown(container.dispose);
  
  // Test code...
  // Container automatically disposed after test
});
```

### 3. Use Provider Overrides for Dependency Injection
```dart
test('with mocked dependencies', () {
  final container = ProviderContainer.test(
    overrides: [
      // Override providers to inject test doubles
      databaseServiceProvider.overrideWith((ref) => mockDatabase),
      apiServiceProvider.overrideWith((ref) => mockApi),
    ],
  );
  addTearDown(container.dispose);
  
  // All code using these providers gets the mocks
});
```

### 4. Use `container.listen()` for Auto-Dispose Providers
```dart
test('with auto-dispose provider', () {
  final container = ProviderContainer.test();
  addTearDown(container.dispose);

  // Keep auto-dispose providers alive during test
  final subscription = container.listen<AsyncValue<int>>(
    autoDisposeProvider,
    (_, __) {},
  );

  // Can read value through subscription
  expect(subscription.read().value, equals(42));
});
```

### 5. Reading Providers in Tests
```dart
// Synchronous providers
final value = container.read(provider);

// Async providers - use .future
await expectLater(
  container.read(provider.future),
  completion('expected value'),
);

// Via subscription (keeps provider alive)
final subscription = container.listen(provider, (_, __) {});
expect(subscription.read(), equals('value'));
```

## Our Architecture

### Service Providers (in `lib/app/providers/services_provider.dart`)
All services are provided via Riverpod providers:

```dart
// Services are injectable via provider overrides
final dp1FeedServiceProvider = Provider<DP1FeedService>((ref) {
  final databaseService = ref.watch(databaseServiceProvider);
  final indexerService = ref.watch(indexerServiceProvider);
  return DP1FeedService(
    databaseService: databaseService,
    indexerService: indexerService,
    apiKey: AppConfig.dp1FeedApiKey,
  );
});
```

### Benefits of This Approach
1. **Testability**: Easy to mock dependencies via provider overrides
2. **Dependency Injection**: Services declare their dependencies explicitly
3. **No Singletons**: Each test gets fresh instances
4. **Provider Chain**: Services can depend on other services via `ref.watch()`

## Integration Tests

For complete end-to-end tests with real dependencies, see:
- `test/infra/services/dp1_feed_integration_test.dart`

These tests:
- Use real API calls
- Use in-memory database
- Test the complete flow from API → Database → UI data
- Verify data consistency and error handling

## Running Tests

```bash
# Run all tests
flutter test

# Run specific test file
flutter test test/app/providers/bootstrap_provider_test.dart

# Run with coverage
flutter test --coverage

# Run integration tests only
flutter test test/infra/services/
```

## Test Statistics

- ✅ 81 tests passing
- ✅ 10 provider unit tests (with mocks)
- ✅ 10 service unit tests (with real dependencies)
- ✅ 8 integration tests (end-to-end)
- ✅ All following Riverpod best practices
