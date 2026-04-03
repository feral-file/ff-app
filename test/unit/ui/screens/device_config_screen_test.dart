import 'dart:async';

import 'package:app/app/providers/ff1_bluetooth_device_providers.dart';
import 'package:app/app/providers/ff1_control_surface_providers.dart';
import 'package:app/app/providers/ff1_device_provider.dart';
import 'package:app/app/providers/ff1_wifi_providers.dart';
import 'package:app/domain/models/ff1/ffp_ddc_panel_status.dart';
import 'package:app/domain/models/ff1_device.dart';
import 'package:app/infra/ff1/wifi_control/ff1_wifi_control.dart';
import 'package:app/infra/ff1/wifi_protocol/ff1_wifi_messages.dart';
import 'package:app/infra/ff1/wifi_transport/ff1_wifi_transport.dart';
import 'package:app/ui/screens/device_config_screen.dart';
import 'package:app/widgets/device_configuration/ffp_status_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'shows FFP monitor controls during setup once relayer status arrives',
    (tester) async {
      await tester.pumpWidget(
        _wrapScreen(
          isInSetupProcess: true,
          deviceData: FF1DeviceData(
            deviceStatus: const FF1DeviceStatus(
              volume: 40,
              isMuted: false,
            ),
            playerStatus: null,
            isConnected: true,
          ),
          currentDeviceStatus: const FF1DeviceStatus(
            volume: 40,
            isMuted: false,
          ),
          currentPlayerStatus: null,
          panelStatus: const FfpDdcPanelStatus(
            brightness: 25,
            contrast: 60,
            power: FfpDdcPanelPower.off,
            monitor: 'Test Monitor',
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.dragUntilVisible(
        find.text('FFP Status'),
        find.byType(CustomScrollView),
        const Offset(0, -300),
      );
      await tester.pumpAndSettle();

      expect(find.text('FFP Status'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('ffp_brightness_slider')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byType(FfpStatusSection),
          matching: find.byType(IconButton),
        ),
        findsWidgets,
        reason:
            'The setup flow should still expose monitor power controls when '
            'the relayer has status for the display.',
      );
    },
  );

  testWidgets(
    'keeps monitor power controls visible when the player is sleeping',
    (tester) async {
      await tester.pumpWidget(
        _wrapScreen(
          isInSetupProcess: false,
          deviceData: FF1DeviceData(
            deviceStatus: const FF1DeviceStatus(
              volume: 40,
              isMuted: false,
            ),
            playerStatus: FF1PlayerStatus(
              playlistId: 'playlist-1',
              sleepMode: true,
            ),
            isConnected: true,
          ),
          currentDeviceStatus: const FF1DeviceStatus(
            volume: 40,
            isMuted: false,
          ),
          currentPlayerStatus: FF1PlayerStatus(
            playlistId: 'playlist-1',
            sleepMode: true,
          ),
          panelStatus: const FfpDdcPanelStatus(
            brightness: 25,
            contrast: 60,
            power: FfpDdcPanelPower.off,
            monitor: 'Test Monitor',
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.dragUntilVisible(
        find.text('FFP Status'),
        find.byType(CustomScrollView),
        const Offset(0, -300),
      );
      await tester.pumpAndSettle();

      expect(find.text('FFP Status'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(FfpStatusSection),
          matching: find.byType(IconButton),
        ),
        findsWidgets,
        reason:
            'Sleeping/off should not hide the monitor power buttons because '
            'users need them to wake the display.',
      );
    },
  );

  testWidgets(
    'hides the monitor section until relayer status is available',
    (tester) async {
      await tester.pumpWidget(
        _wrapScreen(
          isInSetupProcess: true,
          deviceData: FF1DeviceData(
            deviceStatus: const FF1DeviceStatus(
              volume: 40,
              isMuted: false,
            ),
            playerStatus: null,
            isConnected: true,
          ),
          currentDeviceStatus: const FF1DeviceStatus(
            volume: 40,
            isMuted: false,
          ),
          currentPlayerStatus: null,
          panelStatus: null,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('FFP Status'), findsNothing);
      expect(find.byKey(const ValueKey('ffp_brightness_slider')), findsNothing);
    },
  );
}

Widget _wrapScreen({
  required bool isInSetupProcess,
  required FF1DeviceData deviceData,
  required FF1DeviceStatus currentDeviceStatus,
  required FF1PlayerStatus? currentPlayerStatus,
  required FfpDdcPanelStatus? panelStatus,
}) {
  return ProviderScope(
    overrides: [
      activeFF1BluetoothDeviceProvider.overrideWithValue(
        const AsyncData(device),
      ),
      ff1WifiControlProvider.overrideWithValue(_FakeWifiControl()),
      ff1DeviceDataProvider.overrideWithValue(deviceData),
      ff1CurrentDeviceStatusProvider.overrideWithValue(currentDeviceStatus),
      ff1CurrentPlayerStatusProvider.overrideWithValue(currentPlayerStatus),
      ff1DeviceConnectedProvider.overrideWithValue(false),
      if (panelStatus != null)
        ff1FfpDdcPanelStatusStreamProvider(
          device.topicId,
        ).overrideWithValue(AsyncData(panelStatus))
      else
        ff1FfpDdcPanelStatusStreamProvider(
          device.topicId,
        ).overrideWithValue(const AsyncLoading<FfpDdcPanelStatus>()),
    ],
    child: MaterialApp(
      home: DeviceConfigScreen(
        payload: DeviceConfigPayload(isInSetupProcess: isInSetupProcess),
      ),
    ),
  );
}

const device = FF1Device(
  name: 'FF1 Test',
  remoteId: 'remote-id',
  deviceId: 'device-id',
  topicId: 'topic-1',
);

class _FakeWifiControl extends FF1WifiControl {
  _FakeWifiControl()
    : super(
        transport: _FakeWifiTransport(),
        restClient: null,
      );
}

class _FakeWifiTransport implements FF1WifiTransport {
  @override
  Stream<bool> get connectionStateStream => const Stream<bool>.empty();

  @override
  Stream<FF1WifiTransportError> get errorStream =>
      const Stream<FF1WifiTransportError>.empty();

  @override
  bool get isConnected => true;

  @override
  bool get isConnecting => false;

  @override
  Stream<FF1NotificationMessage> get notificationStream =>
      const Stream<FF1NotificationMessage>.empty();

  @override
  Future<void> connect({
    required FF1Device device,
    required String userId,
    required String apiKey,
    bool forceReconnect = false,
  }) async {}

  @override
  void dispose() {}

  @override
  Future<void> disconnect() async {}

  @override
  Future<void> disposeFuture() async {}

  @override
  void pauseConnection() {}

  @override
  Future<void> sendCommand(Map<String, dynamic> command) async {}
}
