import 'package:app/app/providers/app_overlay_provider.dart';
import 'package:app/app/providers/ff1_wifi_providers.dart';
import 'package:app/app/providers/services_provider.dart';
import 'package:app/infra/config/app_config.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';

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

/// Convenience predicates and presentation helpers for startup phase status.
extension BootstrapPhaseX on BootstrapPhase {
  /// True while bootstrap is actively running startup work.
  bool get isInProgress {
    return switch (this) {
      BootstrapPhase.validatingConfiguration => true,
      BootstrapPhase.settingUpCollection => true,
      BootstrapPhase.activatingAutoConnectWatcher => true,
      BootstrapPhase.idle => false,
      BootstrapPhase.completed => false,
      BootstrapPhase.failed => false,
    };
  }

  /// User-facing message for this phase when shown in a toast.
  String get displayMessage {
    return switch (this) {
      BootstrapPhase.validatingConfiguration => 'Validating configuration...',
      BootstrapPhase.settingUpCollection => 'Setting up collection...',
      BootstrapPhase.activatingAutoConnectWatcher =>
        'Activating device auto-connect...',
      BootstrapPhase.idle => 'Initializing app...',
      BootstrapPhase.failed => 'Initializing app...',
      BootstrapPhase.completed => 'Ready',
    };
  }

  /// Icon preset for toast overlay when this phase shows a toast.
  ToastOverlayIconPreset get toastIconPreset {
    return switch (this) {
      BootstrapPhase.validatingConfiguration ||
      BootstrapPhase.settingUpCollection ||
      BootstrapPhase.activatingAutoConnectWatcher =>
        ToastOverlayIconPreset.loading,
      BootstrapPhase.failed ||
      BootstrapPhase.completed => ToastOverlayIconPreset.information,
      BootstrapPhase.idle => ToastOverlayIconPreset.loading,
    };
  }
}

/// Data class for bootstrap status.
class BootstrapStatus {
  /// Creates a BootstrapStatus.
  const BootstrapStatus({
    required this.phase,
    this.message,
    this.error,
  });

  /// Current typed bootstrap phase.
  final BootstrapPhase phase;

  /// Optional status message.
  final String? message;

  /// Optional error if bootstrap failed.
  final Object? error;

  /// Copy with new values.
  BootstrapStatus copyWith({
    BootstrapPhase? phase,
    String? message,
    Object? error,
  }) {
    return BootstrapStatus(
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
      phase: BootstrapPhase.idle,
    );
  }

  /// Run the bootstrap process.
  /// This creates the "My Collection" channel and fetches initial data.
  Future<void> bootstrap() async {
    if (state.phase.isInProgress) {
      _log.info('Bootstrap already in progress');
      return;
    }

    try {
      state = const BootstrapStatus(
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
        phase: BootstrapPhase.completed,
        message: 'Bootstrap completed successfully',
      );
    } on Exception catch (e, stack) {
      if (_isOperationCancelled(e)) {
        _log.info('Bootstrap cancelled');
        state = const BootstrapStatus(
          phase: BootstrapPhase.idle,
        );
        return;
      }
      _log.severe('Bootstrap failed', e, stack);
      state = BootstrapStatus(
        phase: BootstrapPhase.failed,
        message: 'Bootstrap failed: $e',
        error: e,
      );
    }
  }

  /// Reset bootstrap state.
  void reset() {
    state = const BootstrapStatus(
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
