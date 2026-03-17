import 'package:app/app/providers/app_overlay_provider.dart';
import 'package:app/app/providers/bootstrap_provider.dart';

/// Toast presentation derived from bootstrap status.
class BootstrapToastPresentation {
  /// Creates a bootstrap toast presentation.
  const BootstrapToastPresentation({
    required this.message,
    required this.iconPreset,
    this.autoDismissAfter,
  });

  /// User-facing toast message.
  final String message;

  /// Visual preset for the toast icon.
  final ToastOverlayIconPreset iconPreset;

  /// Optional auto-dismiss duration.
  final Duration? autoDismissAfter;
}

/// Returns toast presentation for a bootstrap status, or null when no toast
/// should be shown.
BootstrapToastPresentation? bootstrapToastForStatus(BootstrapStatus status) {
  if (status.phase.isInProgress) {
    return BootstrapToastPresentation(
      message: status.message ?? _bootstrapPhaseMessage(status.phase),
      iconPreset: ToastOverlayIconPreset.loading,
    );
  }

  if (status.phase == BootstrapPhase.failed) {
    return BootstrapToastPresentation(
      message: status.message ?? 'Startup failed. Some data may be outdated.',
      iconPreset: ToastOverlayIconPreset.information,
      autoDismissAfter: const Duration(seconds: 5),
    );
  }

  return null;
}

String _bootstrapPhaseMessage(BootstrapPhase phase) {
  return switch (phase) {
    BootstrapPhase.validatingConfiguration => 'Validating configuration...',
    BootstrapPhase.settingUpCollection => 'Setting up collection...',
    BootstrapPhase.activatingAutoConnectWatcher =>
      'Activating device auto-connect...',
    BootstrapPhase.idle ||
    BootstrapPhase.completed ||
    BootstrapPhase.failed => 'Initializing app...',
  };
}
