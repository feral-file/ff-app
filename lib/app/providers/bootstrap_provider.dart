import 'package:app/app/feed/feed_registry_provider.dart';
import 'package:app/app/providers/remote_config_provider.dart';
import 'package:app/app/providers/services_provider.dart';
import 'package:app/infra/config/app_config.dart';
import 'package:app/infra/config/feed_config_store.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';

/// State for the bootstrap process.
enum BootstrapState {
  /// Initial state, not started.
  idle,

  /// Bootstrap is in progress.
  loading,

  /// Bootstrap completed successfully.
  success,

  /// Bootstrap failed with an error.
  error,
}

/// Data class for bootstrap status.
class BootstrapStatus {
  /// Creates a BootstrapStatus.
  const BootstrapStatus({
    required this.state,
    this.message,
    this.error,
  });

  /// Current state of bootstrap.
  final BootstrapState state;

  /// Optional status message.
  final String? message;

  /// Optional error if bootstrap failed.
  final Object? error;

  /// Copy with new values.
  BootstrapStatus copyWith({
    BootstrapState? state,
    String? message,
    Object? error,
  }) {
    return BootstrapStatus(
      state: state ?? this.state,
      message: message ?? this.message,
      error: error ?? this.error,
    );
  }
}

/// Notifier for managing the bootstrap process.
class BootstrapNotifier extends Notifier<BootstrapStatus> {
  late final Logger _log;

  @override
  BootstrapStatus build() {
    _log = Logger('BootstrapNotifier');
    return const BootstrapStatus(state: BootstrapState.idle);
  }

  /// Run the bootstrap process.
  /// This creates the "My Collection" channel and fetches initial data.
  Future<void> bootstrap() async {
    if (state.state == BootstrapState.loading) {
      _log.info('Bootstrap already in progress');
      return;
    }

    try {
      state = const BootstrapStatus(
        state: BootstrapState.loading,
        message: 'Initializing app...',
      );

      _log.info('Starting bootstrap');

      // Check configuration
      _log.info('Checking configuration validity...');
      if (!AppConfig.isValid) {
        _log.severe('Invalid configuration: missing required keys');
        throw Exception('Invalid configuration: missing required keys');
      }
      _log.info('Configuration is valid');

      // Step 1: Create "My Collection" channel
      state = state.copyWith(message: 'Setting up collection...');
      _log.info('Creating My Collection channel...');
      final bootstrapService = ref.read(bootstrapServiceProvider);
      await bootstrapService.bootstrap();
      _log.info('My Collection channel created');

      // Step 2: Setup and reload curated channels (matches old repo pattern).
      // This is intentionally additive to the default DP1_FEED_URL bootstrap.
      state = state.copyWith(message: 'Syncing curated feeds...');
      _log.info('Setting up curated channels and feed services...');

      final feedConfigStore = ref.read(feedConfigStoreProvider);
      final feedCacheDuration = ref.read(remoteFeedCacheDurationProvider);
      final feedLastUpdatedAt = ref.read(remoteFeedLastUpdatedAtProvider);
      await feedConfigStore.setCacheDuration(feedCacheDuration);
      await feedConfigStore.setLastFeedUpdatedAt(feedLastUpdatedAt);

      final curatedUrls = ref.read(curatedChannelUrlsProvider);
      final curatedSetupFuture = ref
          .read(feedRegistryProvider.notifier)
          .setupRemoteConfigChannels(
            curatedUrls,
          );

      await curatedSetupFuture;

      _log.info('✓ Curated feeds setup and reloaded');

      state = BootstrapStatus(
        state: BootstrapState.success,
        message:
            'Bootstrap completed: '
            '${curatedUrls.length} channels',
      );

      _log.info('Bootstrap completed successfully');
    } on Exception catch (e, stack) {
      if (_isOperationCancelled(e)) {
        _log.info('Bootstrap cancelled');
        state = const BootstrapStatus(state: BootstrapState.idle);
        return;
      }
      _log.severe('Bootstrap failed', e, stack);
      state = BootstrapStatus(
        state: BootstrapState.error,
        message: 'Bootstrap failed: $e',
        error: e,
      );
    }
  }

  /// Reset bootstrap state.
  void reset() {
    state = const BootstrapStatus(state: BootstrapState.idle);
  }
}

/// Provider for the bootstrap notifier.
final bootstrapProvider = NotifierProvider<BootstrapNotifier, BootstrapStatus>(
  BootstrapNotifier.new,
);

bool _isOperationCancelled(Object error) {
  return error.runtimeType.toString() == 'CancellationException' ||
      error.toString().contains('Operation was cancelled');
}
