import 'package:app/app/now_displaying/now_displaying_visibility_sync.dart';
import 'package:app/app/providers/ff1_bluetooth_device_providers.dart';
import 'package:app/app/providers/ff1_wifi_providers.dart';
import 'package:app/app/providers/now_displaying_visibility_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  ProviderContainer buildContainer() {
    return ProviderContainer.test(
      overrides: [
        allFF1BluetoothDevicesProvider.overrideWith(
          (ref) => Stream.value([]),
        ),
        ff1CurrentPlayerStatusProvider.overrideWith((ref) => null),
      ],
    );
  }

  testWidgets(
    'startup sync reads keyboard visibility from view insets',
    (tester) async {
      final container = buildContainer();
      addTearDown(container.dispose);
      addTearDown(tester.view.resetViewInsets);

      tester.view.viewInsets = const FakeViewPadding(bottom: 120);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: NowDisplayingVisibilitySync(
              child: SizedBox.shrink(),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(
        container.read(nowDisplayingVisibilityProvider).keyboardVisibility,
        isTrue,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'metrics changes update keyboard visibility without plugin streams',
    (tester) async {
      final container = buildContainer();
      addTearDown(container.dispose);
      addTearDown(tester.view.resetViewInsets);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: NowDisplayingVisibilitySync(
              child: SizedBox.shrink(),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(
        container.read(nowDisplayingVisibilityProvider).keyboardVisibility,
        isFalse,
      );

      tester.view.viewInsets = const FakeViewPadding(bottom: 80);
      tester.binding.platformDispatcher.onMetricsChanged?.call();
      await tester.pump();

      expect(
        container.read(nowDisplayingVisibilityProvider).keyboardVisibility,
        isTrue,
      );

      tester.view.viewInsets = FakeViewPadding.zero;
      tester.binding.platformDispatcher.onMetricsChanged?.call();
      await tester.pump();

      expect(
        container.read(nowDisplayingVisibilityProvider).keyboardVisibility,
        isFalse,
      );
    },
  );
}
