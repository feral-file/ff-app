import 'package:app/app/bootstrap/bootstrap_status_toast.dart';
import 'package:app/app/providers/app_overlay_provider.dart';
import 'package:app/app/providers/bootstrap_provider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('bootstrapToastForStatus', () {
    test('maps in-progress phase to loading toast', () {
      const status = BootstrapStatus(
        phase: BootstrapPhase.settingUpCollection,
      );

      final toast = bootstrapToastForStatus(status);

      expect(toast, isNotNull);
      expect(toast!.iconPreset, ToastOverlayIconPreset.loading);
      expect(toast.autoDismissAfter, isNull);
      expect(toast.message, 'Setting up collection...');
    });

    test('maps failed phase to informational auto-dismiss toast', () {
      const status = BootstrapStatus(
        phase: BootstrapPhase.failed,
      );

      final toast = bootstrapToastForStatus(status);

      expect(toast, isNotNull);
      expect(toast!.iconPreset, ToastOverlayIconPreset.information);
      expect(toast.autoDismissAfter, const Duration(seconds: 5));
      expect(toast.message, 'Startup failed. Some data may be outdated.');
    });

    test('returns null for completed phase', () {
      const status = BootstrapStatus(
        phase: BootstrapPhase.completed,
      );

      expect(bootstrapToastForStatus(status), isNull);
    });
  });
}
