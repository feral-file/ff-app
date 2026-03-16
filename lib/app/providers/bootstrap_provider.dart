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

/// Explicit bootstrap execution phases for startup observability.
enum BootstrapPhase {
  /// No bootstrap work has started.
  idle,

  /// Validate required app configuration before side effects.
  validatingConfiguration,

  /// Create or verify local bootstrap data (e.g. My Collection channel).
  settingUpCollection,

  /// Keep FF1 auto-connect lifecycle watcher alive.
  activatingAutoConnectWatcher,

  /// Bootstrap completed successfully.
  completed,

  /// Bootstrap failed.
  failed,
}

/// Data class for bootstrap status.
class BootstrapStatus {
  /// Creates a BootstrapStatus.
  const BootstrapStatus({
    required this.state,
    required this.phase,
    this.message,
    this.error,
  });

  /// Current state of bootstrap.
  final BootstrapState state;

  /// Current typed bootstrap phase.
  final BootstrapPhase phase;

  /// Optional status message.
  final String? message;

  /// Optional error if bootstrap failed.
  final Object? error;

  /// Copy with new values.
  BootstrapStatus copyWith({
    BootstrapState? state,
    BootstrapPhase? phase,
    String? message,
    Object? error,
  }) {
    return BootstrapStatus(
      state: state ?? this.state,
      phase: phase ?? this.phase,
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
    return const BootstrapStatus(
      state: BootstrapState.idle,
      phase: BootstrapPhase.idle,
    );
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
        phase: BootstrapPhase.validatingConfiguration,
        message: 'Initializing app...',
      );

      _log
        ..info('Starting bootstrap')
        ..info(
          'Config flags: indexerApiUrl=${AppConfig.indexerApiUrl.isNotEmpty}, '
          'indexerApiKey=${AppConfig.indexerApiKey.isNotEmpty}, '
          'ff1RelayerUrl=${AppConfig.ff1RelayerUrl.isNotEmpty}, '
          'ff1RelayerApiKey=${AppConfig.ff1RelayerApiKey.isNotEmpty}',
        )
        ..info('Checking configuration validity...');

      // Check configuration
      if (!AppConfig.isValid) {
        _log.severe('Invalid configuration: missing required keys');
        throw Exception('Invalid configuration: missing required keys');
      }
      _log.info('Configuration is valid');

      // Step 1: Create "My Collection" channel
      state = state.copyWith(
        phase: BootstrapPhase.settingUpCollection,
        message: 'Setting up collection...',
      );
      _log.info('Creating My Collection channel...');
      final bootstrapService = ref.read(bootstrapServiceProvider);
      await bootstrapService.bootstrap();
      _log.info('My Collection channel created');

      // Keep the auto-connect watcher alive to automatically connect to relayer
      // when active FF1 device changes
      state = state.copyWith(
        phase: BootstrapPhase.activatingAutoConnectWatcher,
        message: 'Activating FF1 auto-connect watcher...',
      );
      ref.watch(ff1AutoConnectWatcherProvider);

      state = const BootstrapStatus(
        state: BootstrapState.success,
        phase: BootstrapPhase.completed,
        message: 'Bootstrap completed successfully',
      );
    } on Exception catch (e, stack) {
      if (_isOperationCancelled(e)) {
        _log.info('Bootstrap cancelled');
        state = const BootstrapStatus(
          state: BootstrapState.idle,
          phase: BootstrapPhase.idle,
        );
        return;
      }
      _log.severe('Bootstrap failed', e, stack);
      state = BootstrapStatus(
        state: BootstrapState.error,
        phase: BootstrapPhase.failed,
        message: 'Bootstrap failed: $e',
        error: e,
      );
    }
  }

  /// Reset bootstrap state.
  void reset() {
    state = const BootstrapStatus(
      state: BootstrapState.idle,
      phase: BootstrapPhase.idle,
    );
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
