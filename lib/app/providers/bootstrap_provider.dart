import 'package:app/app/providers/api_providers.dart';
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

      // Check configuration
      if (!AppConfig.isValid) {
        throw Exception('Invalid configuration: missing required keys');
      }

      // Step 1: Create "My Collection" channel
      state = state.copyWith(message: 'Setting up collection...');
      final bootstrapService = ref.read(bootstrapServiceProvider);
      await bootstrapService.bootstrap();

      // Step 2: Fetch playlists from feed server
      // Using retryable provider for automatic retry on network errors
      state = state.copyWith(message: 'Fetching playlists...');
      final playlistCount = await ref.read(fetchPlaylistsProvider.future);

      _log.info('Fetched $playlistCount playlists');

      state = BootstrapStatus(
        state: BootstrapState.success,
        message: 'Bootstrap completed: $playlistCount playlists loaded',
      );

      _log.info('Bootstrap completed successfully');
    } on Exception catch (e, stack) {
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
final bootstrapProvider =
    NotifierProvider<BootstrapNotifier, BootstrapStatus>(
  BootstrapNotifier.new,
);
