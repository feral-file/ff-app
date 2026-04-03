import 'dart:async';

import 'package:app/app/providers/ff1_bluetooth_device_providers.dart';
import 'package:app/app/providers/ff1_wifi_providers.dart';
import 'package:app/domain/models/ff1_device.dart';
import 'package:app/infra/config/app_state_service.dart';
import 'package:app/infra/ff1/wifi_protocol/ff1_wifi_messages.dart';
import 'package:app/ui/screens/device_config_screen.dart';
import 'package:app/widgets/buttons/primary_button.dart';
import 'package:app/widgets/device_configuration/options_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../app/providers/provider_test_helpers.dart';

void main() {
  const updateDescription =
      'Update your FF1 to the latest version. Keep the device connected and '
      'powered on during the update. It will restart automatically when the '
      'update is complete.';

  testWidgets(
    'DeviceConfigScreen Later waits for dismissal to persist before closing',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 12000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final dismissalGate = Completer<void>();
      final appState = _BlockingAppStateService(dismissalGate);
      final wifiControl = FakeWifiControl();

      const device = FF1Device(
        name: 'FF1',
        remoteId: 'remote-1',
        deviceId: 'device-1',
        topicId: 'topic-1',
      );
      const deviceStatus = FF1DeviceStatus(
        installedVersion: '1.0.0',
        latestVersion: '2.0.0',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            activeFF1BluetoothDeviceProvider.overrideWithValue(
              const AsyncData(device),
            ),
            ff1CurrentDeviceStatusProvider.overrideWithValue(deviceStatus),
            ff1DeviceConnectedProvider.overrideWithValue(true),
            ff1WifiControlProvider.overrideWithValue(wifiControl),
            appStateServiceProvider.overrideWithValue(appState),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: DeviceConfigScreen(
                payload: DeviceConfigPayload(isInSetupProcess: false),
              ),
            ),
          ),
        ),
      );

      await _pumpUntilVisible(tester, 'Update Available');

      final laterButton = _primaryAsyncButton('Later');
      final laterAction =
          tester.widget<PrimaryAsyncButton>(laterButton).onTap!();
      await tester.pump();

      expect(appState.calls, 1);
      expect(appState.lastDeviceId, device.deviceId);
      expect(appState.lastVersion, deviceStatus.latestVersion);
      expect(find.text('Update Available'), findsOneWidget);

      dismissalGate.complete();
      await tester.pumpAndSettle();

      expect(find.text('Update Available'), findsNothing);
      expect(
        appState.dismissedVersions[device.deviceId],
        deviceStatus.latestVersion,
      );
      await laterAction;
    },
  );

  testWidgets(
    'OptionsButton Cancel does not persist a dismissed firmware version',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 12000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final appState = _BlockingAppStateService(Completer<void>());
      final wifiControl = FakeWifiControl();

      const device = FF1Device(
        name: 'FF1',
        remoteId: 'remote-1',
        deviceId: 'device-1',
        topicId: 'topic-1',
      );
      const deviceStatus = FF1DeviceStatus(
        installedVersion: '1.0.0',
        latestVersion: '2.0.0',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            activeFF1BluetoothDeviceProvider.overrideWithValue(
              const AsyncData(device),
            ),
            ff1CurrentDeviceStatusProvider.overrideWithValue(deviceStatus),
            ff1DeviceConnectedProvider.overrideWithValue(true),
            ff1WifiControlProvider.overrideWithValue(wifiControl),
            appStateServiceProvider.overrideWithValue(appState),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: Center(child: OptionsButton()),
            ),
          ),
        ),
      );

      await tester.tap(find.byType(SvgPicture));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Update FF1').first);
      await tester.pumpAndSettle();

      expect(find.text(updateDescription), findsOneWidget);

      final cancelButton = _primaryAsyncButton('Cancel');
      await tester.widget<PrimaryAsyncButton>(cancelButton).onTap!();
      await tester.pumpAndSettle();

      expect(appState.calls, 0);
      expect(appState.lastDeviceId, isNull);
      expect(appState.lastVersion, isNull);
      expect(
        appState.dismissedVersions[device.deviceId],
        isNull,
      );
      expect(find.text(updateDescription), findsNothing);
    },
  );

  testWidgets(
    'OptionsButton hides Update FF1 until version info is available',
    (tester) async {
      final wifiControl = FakeWifiControl();

      const device = FF1Device(
        name: 'FF1',
        remoteId: 'remote-1',
        deviceId: 'device-1',
        topicId: 'topic-1',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            activeFF1BluetoothDeviceProvider.overrideWithValue(
              const AsyncData(device),
            ),
            ff1CurrentDeviceStatusProvider.overrideWith((ref) => null),
            ff1DeviceConnectedProvider.overrideWithValue(true),
            ff1WifiControlProvider.overrideWithValue(wifiControl),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: Center(child: OptionsButton()),
            ),
          ),
        ),
      );

      await tester.tap(find.byType(SvgPicture));
      await tester.pumpAndSettle();

      expect(find.text('Send Log'), findsOneWidget);
      expect(find.text('Update FF1'), findsNothing);
    },
  );

  testWidgets(
    'DeviceConfigScreen ignores blank firmware versions for auto-prompt',
    (tester) async {
      final appState = _BlockingAppStateService(Completer<void>());
      final wifiControl = FakeWifiControl();

      const device = FF1Device(
        name: 'FF1',
        remoteId: 'remote-1',
        deviceId: 'device-1',
        topicId: 'topic-1',
      );
      const deviceStatus = FF1DeviceStatus(
        installedVersion: '   ',
        latestVersion: '2.0.0',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            activeFF1BluetoothDeviceProvider.overrideWithValue(
              const AsyncData(device),
            ),
            ff1CurrentDeviceStatusProvider.overrideWithValue(deviceStatus),
            ff1DeviceConnectedProvider.overrideWithValue(true),
            ff1WifiControlProvider.overrideWithValue(wifiControl),
            appStateServiceProvider.overrideWithValue(appState),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: DeviceConfigScreen(
                payload: DeviceConfigPayload(isInSetupProcess: false),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Update Available'), findsNothing);
    },
  );
}

Future<void> _pumpUntilVisible(WidgetTester tester, String text) async {
  for (var i = 0; i < 20; i++) {
    if (find.text(text).evaluate().isNotEmpty) {
      return;
    }
    await tester.pump(const Duration(milliseconds: 50));
  }
  fail('Timed out waiting for "$text" to appear.');
}

Finder _primaryAsyncButton(String label) {
  return find.byWidgetPredicate(
    (widget) => widget is PrimaryAsyncButton && widget.text == label,
    description: 'PrimaryAsyncButton("$label")',
  );
}

class _BlockingAppStateService implements AppStateService {
  _BlockingAppStateService(this.dismissalGate);

  final Completer<void> dismissalGate;
  final Map<String, String> dismissedVersions = <String, String>{};
  int calls = 0;
  String? lastDeviceId;
  String? lastVersion;

  @override
  String getDismissedUpdateVersion(String deviceId) {
    return dismissedVersions[deviceId] ?? '';
  }

  @override
  Future<void> setDismissedUpdateVersion({
    required String deviceId,
    required String version,
  }) async {
    calls++;
    lastDeviceId = deviceId;
    lastVersion = version;
    await dismissalGate.future;
    dismissedVersions[deviceId] = version;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
