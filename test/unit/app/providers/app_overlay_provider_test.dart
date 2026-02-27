import 'package:app/app/providers/app_overlay_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppOverlayNotifier', () {
    test('showToast adds a loading toast with tap-through mode by default', () {
      final container = ProviderContainer.test();
      addTearDown(container.dispose);

      final overlayId = container
          .read(appOverlayProvider.notifier)
          .showToast(message: 'Updating feed...');

      final overlays = container.read(appOverlayProvider);
      expect(overlays, hasLength(1));
      expect(overlays.first.id, overlayId);
      expect(overlays.first.isDismissing, isFalse);
      expect(overlays.first.interactionMode, OverlayInteractionMode.tapThrough);

      final toast = overlays.first as AppToastOverlayItem;
      expect(toast.message, 'Updating feed...');
      expect(toast.iconPreset, ToastOverlayIconPreset.loading);
      expect(toast.autoDismissAfter, isNull);
    });

    test(
      'showToast supports info icon, blocking mode, and auto-dismiss duration',
      () {
        final container = ProviderContainer.test();
        addTearDown(container.dispose);

        container
            .read(appOverlayProvider.notifier)
            .showToast(
              message: 'Metadata rebuilt.',
              iconPreset: ToastOverlayIconPreset.information,
              isTapThroughable: false,
              autoDismissAfter: const Duration(seconds: 3),
            );

        final toast =
            container.read(appOverlayProvider).single as AppToastOverlayItem;
        expect(toast.iconPreset, ToastOverlayIconPreset.information);
        expect(toast.interactionMode, OverlayInteractionMode.blocking);
        expect(toast.autoDismissAfter, const Duration(seconds: 3));
      },
    );

    test(
      'dismissOverlay marks item dismissing and removeOverlay deletes it',
      () {
        final container = ProviderContainer.test();
        addTearDown(container.dispose);

        final overlayId = container
            .read(appOverlayProvider.notifier)
            .showToast(message: 'Cleaning local data...');

        container.read(appOverlayProvider.notifier).dismissOverlay(overlayId);
        final dismissingOverlay = container.read(appOverlayProvider).single;
        expect(dismissingOverlay.isDismissing, isTrue);

        container.read(appOverlayProvider.notifier).removeOverlay(overlayId);
        expect(container.read(appOverlayProvider), isEmpty);
      },
    );
  });
}
