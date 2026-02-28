import 'package:app/app/feed/feed_registry_provider.dart';
import 'package:app/app/providers/ff1_wifi_providers.dart';
import 'package:app/app/providers/services_provider.dart';
import 'package:app/infra/config/app_config.dart';
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
      _log.info(
        'Config flags: dp1FeedUrl=${AppConfig.dp1FeedUrl.isNotEmpty}, '
        'dp1FeedApiKey=${AppConfig.dp1FeedApiKey.isNotEmpty}, '
        'indexerApiUrl=${AppConfig.indexerApiUrl.isNotEmpty}, '
        'indexerApiKey=${AppConfig.indexerApiKey.isNotEmpty}, '
        'ff1RelayerUrl=${AppConfig.ff1RelayerUrl.isNotEmpty}, '
        'ff1RelayerApiKey=${AppConfig.ff1RelayerApiKey.isNotEmpty}',
      );

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

      // Initialize feed services used by lifecycle/reset flows.
      final feedManager = ref.read(feedManagerProvider);
      _log.info('Feed services configured: ${feedManager.feedServices.length}');
      if (feedManager.feedServices.isEmpty) {
        _log.warning('No feed services configured on startup');
      } else {
        for (final service in feedManager.feedServices) {
          _log.info(
            'Startup feed service: ${service.runtimeType} '
            'url=${service.baseUrl}, ',
          );
        }
      }
      _log.info('Initializing feed services...');
      await feedManager.init();
      _log.info('Reloading feed cache on startup...');
      await feedManager.reloadAllCache();
      _log.info('Feed cache reload on startup complete');

      // Keep the auto-connect watcher alive to automatically connect to relayer
      // when active FF1 device changes
      ref.watch(ff1AutoConnectWatcherProvider);

      state = const BootstrapStatus(
        state: BootstrapState.success,
        message: 'Bootstrap completed successfully',
      );
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
