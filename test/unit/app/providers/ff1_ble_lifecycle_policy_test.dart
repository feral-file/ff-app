import 'package:app/app/providers/ff1_ble_lifecycle_policy.dart';
import 'package:app/app/routing/routes.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FF1 BLE lifecycle policy', () {
    test('shouldCloseBleForRoute returns true for home route', () {
      expect(shouldCloseBleForRoute(Routes.home), isTrue);
    });

    test('shouldCloseBleForRoute returns false for non-home routes', () {
      expect(shouldCloseBleForRoute(Routes.deviceConfiguration), isFalse);
      expect(shouldCloseBleForRoute(Routes.scanWifiNetworks), isFalse);
    });

    test('isBackgroundLifecycleState handles paused/inactive/detached', () {
      expect(isBackgroundLifecycleState(AppLifecycleState.paused), isTrue);
      expect(isBackgroundLifecycleState(AppLifecycleState.inactive), isTrue);
      expect(isBackgroundLifecycleState(AppLifecycleState.detached), isTrue);
      expect(isBackgroundLifecycleState(AppLifecycleState.resumed), isFalse);
      expect(isBackgroundLifecycleState(AppLifecycleState.hidden), isFalse);
    });

    test(
      'shouldReconnectBleOnLifecycle reconnects only on resumed non-home',
      () {
        expect(
          shouldReconnectBleOnLifecycle(
            state: AppLifecycleState.resumed,
            routePath: Routes.deviceConfiguration,
          ),
          isTrue,
        );
        expect(
          shouldReconnectBleOnLifecycle(
            state: AppLifecycleState.resumed,
            routePath: Routes.home,
          ),
          isFalse,
        );
        expect(
          shouldReconnectBleOnLifecycle(
            state: AppLifecycleState.paused,
            routePath: Routes.deviceConfiguration,
          ),
          isFalse,
        );
      },
    );
  });
}
