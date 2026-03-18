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

/// Returns toast presentation for a bootstrap status.
BootstrapToastPresentation? bootstrapToastForStatus(BootstrapStatus status) {
  if (status.phase.isInProgress) {
    final iconPreset = status.phase.toastIconPreset;
    return BootstrapToastPresentation(
      message: status.message ?? status.phase.displayMessage,
      iconPreset: iconPreset,
    );
  }

  if (status.phase == BootstrapPhase.failed) {
    final iconPreset = status.phase.toastIconPreset;
    return BootstrapToastPresentation(
      message: status.message ?? 'Startup failed. Some data may be outdated.',
      iconPreset: iconPreset,
      autoDismissAfter: const Duration(seconds: 5),
    );
  }

  if (status.phase == BootstrapPhase.idle) {
    final iconPreset = status.phase.toastIconPreset;
    return BootstrapToastPresentation(
      message: status.message ?? status.phase.displayMessage,
      iconPreset: iconPreset,
    );
  }

  if (status.phase == BootstrapPhase.completed) {
    final iconPreset = status.phase.toastIconPreset;
    return BootstrapToastPresentation(
      message: status.message ?? status.phase.displayMessage,
      iconPreset: iconPreset,
      autoDismissAfter: const Duration(seconds: 3),
    );
  }

  return null;
}
