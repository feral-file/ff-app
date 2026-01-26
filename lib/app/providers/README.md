# Riverpod Providers with Automatic Retry

This directory implements Riverpod providers with automatic retry functionality following the official guide: [https://riverpod.dev/docs/concepts2/retry](https://riverpod.dev/docs/concepts2/retry)

## Overview

All API operations are wrapped in Riverpod providers that include intelligent retry logic for network errors.

## Files

### `api_retry_strategy.dart` - Custom Retry Logic

Defines retry strategies for API operations:

**`apiRetryStrategy`** - Standard retry for most API calls:
- Retries up to 5 times
- Exponential backoff: 200ms, 400ms, 800ms, 1.6s, 3.2s
- Retries network timeouts and 5xx errors
- Does NOT retry 4xx client errors
- Does NOT retry Errors (bugs in code)

**`aggressiveApiRetry`** - For critical user data:
- Retries up to 10 times
- Exponential backoff capped at 10 seconds
- Same error filtering as standard strategy

### `api_providers.dart` - Retryable API Providers

Provider wrappers for API operations with automatic retry:

```dart
// Fetch channel with automatic retry
final channel = await ref.watch(
  fetchChannelProvider(channelId).future,
);

// Fetch playlists with automatic retry
final count = await ref.watch(fetchPlaylistsProvider.future);

// Fetch tokens with automatic retry
final tokens = await ref.watch(
  fetchTokensByCIDsProvider(cids).future,
);
```

### `services_provider.dart` - Service Instances

Base service providers (no retry at this level):
- `dp1FeedServiceProvider` - Feed server API service
- `indexerServiceProvider` - Indexer API service
- `addressServiceProvider` - Address management
- `bootstrapServiceProvider` - App initialization

## How Retry Works

### Default Retry Behavior

By default, Riverpod providers retry:
- Up to 10 times
- Exponential backoff: 200ms to 6.4s
- Automatically skips Errors and ProviderExceptions

### Our Custom Strategy

```dart
Duration? apiRetryStrategy(int retryCount, Object error) {
  // Stop after 5 retries
  if (retryCount >= 5) return null;

  // Don't retry Errors (bugs)
  if (error is Error) return null;

  // Handle network errors
  if (error is DioException) {
    // Don't retry 4xx client errors
    if (statusCode >= 400 && statusCode < 500) {
      return null;
    }

    // Retry connection issues with exponential backoff
    if (shouldRetry) {
      return Duration(milliseconds: 200 * (1 << retryCount));
    }
  }

  return null;
}
```

## Usage Examples

### In Providers

```dart
final fetchPlaylistsProvider = FutureProvider.autoDispose<int>(
  (ref) async {
    final service = ref.watch(dp1FeedServiceProvider);
    return await service.fetchPlaylists(
      baseUrl: AppConfig.dp1FeedUrl,
      limit: 10,
    );
  },
  // Apply retry strategy
  retry: apiRetryStrategy,
);
```

### In App Code

```dart
class MyWidget extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Automatically retries on network errors
    final playlistsAsync = ref.watch(fetchPlaylistsProvider);

    return playlistsAsync.when(
      data: (count) => Text('Loaded $count playlists'),
      loading: () => CircularProgressIndicator(),
      error: (error, stack) => Text('Failed after retries: $error'),
    );
  }
}
```

### With Await

```dart
// In async function
final count = await ref.read(fetchPlaylistsProvider.future);

// The future waits through all retry attempts
// Only completes when either:
// 1. All retries exhausted, or
// 2. Provider succeeds
```

## Error Handling

### Network Errors (Retried)
- Connection timeout
- Send timeout
- Receive timeout
- Connection error
- Server errors (500-599)

### Client Errors (NOT Retried)
- Bad request (400)
- Unauthorized (401)
- Forbidden (403)
- Not found (404)
- Other 4xx errors

### Code Errors (NOT Retried)
- `Error` types (StateError, ArgumentError, etc.)
- These indicate bugs and should be fixed

## Testing

See `test/app/providers/api_retry_test.dart` for comprehensive retry tests:

```dart
test('retries network timeout errors', () {
  final error = DioException(
    type: DioExceptionType.connectionTimeout,
  );

  // Verify exponential backoff
  expect(apiRetryStrategy(0, error), Duration(milliseconds: 200));
  expect(apiRetryStrategy(1, error), Duration(milliseconds: 400));
  expect(apiRetryStrategy(2, error), Duration(milliseconds: 800));
  
  // Stops after 5 retries
  expect(apiRetryStrategy(5, error), isNull);
});
```

## Integration with Bootstrap

The bootstrap process uses retryable providers:

```dart
// In bootstrap_provider.dart
Future<void> bootstrap() async {
  // Uses fetchPlaylistsProvider with automatic retry
  final playlistCount = await ref.read(fetchPlaylistsProvider.future);
  
  // Network errors are automatically retried
  // Only fails if all retries exhausted
}
```

## Benefits

1. **Resilient**: Automatically handles transient network issues
2. **Smart**: Only retries recoverable errors
3. **Testable**: Easy to test retry logic in isolation
4. **Configurable**: Different strategies for different needs
5. **Transparent**: Works seamlessly with existing async patterns

## Advanced Usage

### Custom Retry Strategy

```dart
final myProvider = FutureProvider<Data>(
  (ref) => fetchData(),
  retry: (retryCount, error) {
    // Custom logic
    if (retryCount >= 3) return null;
    return Duration(seconds: 1);
  },
);
```

### Disable Retry

```dart
final noRetryProvider = FutureProvider<Data>(
  (ref) => fetchData(),
  retry: (retryCount, error) => null, // Never retry
);
```

### Global Retry Strategy

```dart
runApp(
  ProviderScope(
    retry: apiRetryStrategy, // Applied to all providers
    child: MyApp(),
  ),
);
```

## Best Practices

1. ✅ Use `apiRetryStrategy` for normal API calls
2. ✅ Use `aggressiveApiRetry` for critical user data
3. ✅ Don't retry 4xx client errors
4. ✅ Always retry network timeouts and 5xx errors
5. ✅ Let Errors bubble up (they're bugs to fix)
6. ✅ Use `.future` to await through all retries
7. ✅ Test retry logic independently

## References

- **Riverpod Retry Guide**: https://riverpod.dev/docs/concepts2/retry
- **Riverpod Providers**: https://riverpod.dev/docs/concepts2/providers
- **Riverpod Testing**: https://riverpod.dev/docs/how_to/testing
