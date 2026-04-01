import 'dart:async';

import 'package:app/app/providers/ff1_bluetooth_device_providers.dart';
import 'package:app/app/providers/ff1_wifi_providers.dart';
import 'package:app/domain/models/ff1/ffp_ddc_panel_status.dart';
import 'package:app/domain/models/ff1_device.dart';
import 'package:app/infra/ff1/wifi_control/ff1_wifi_control.dart';
import 'package:app/infra/ff1/wifi_protocol/ff1_wifi_messages.dart';
import 'package:app/infra/ff1/wifi_transport/ff1_wifi_transport.dart';
import 'package:app/widgets/artwork_playing_controls/artwork_playing_controls.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'later relayer pushes replace optimistic FFP state in artwork controls',
    (tester) async {
      const device = FF1Device(
        name: 'FF1 Test',
        remoteId: 'remote-id',
        deviceId: 'device-id',
        topicId: 'topic-1',
      );
      final statuses = StreamController<FfpDdcPanelStatus>.broadcast();
      final control = _FakeWifiControl();

      addTearDown(statuses.close);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            activeFF1BluetoothDeviceProvider.overrideWith((ref) {
              return Stream.value(device);
            }),
            ff1WifiControlProvider.overrideWithValue(control),
            ff1FfpDdcPanelStatusStreamProvider(device.topicId).overrideWith((
              ref,
            ) {
              return statuses.stream;
            }),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: ArtworkPlayingControls(playingDevice: device),
            ),
          ),
        ),
      );

      statuses.add(
        const FfpDdcPanelStatus(
          brightness: 20,
          monitor: 'Test Monitor',
        ),
      );
      await tester.pump();
      await tester.pump();

      final sliderFinder = find.byType(Slider).at(1);
      expect(tester.widget<Slider>(sliderFinder).value, 20);

      final slider = tester.widget<Slider>(sliderFinder);
      slider.onChanged!(80);
      await tester.pump();

      statuses.add(
        const FfpDdcPanelStatus(
          brightness: 80,
          monitor: 'Test Monitor',
        ),
      );
      await tester.pump();
      await tester.pump();

      statuses.add(
        const FfpDdcPanelStatus(
          brightness: 65,
          monitor: 'Test Monitor',
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(
        tester.widget<Slider>(sliderFinder).value,
        65,
        reason:
            'Artwork quick controls must resume following relayer pushes after '
            'the optimistic value is confirmed.',
      );
    },
  );
}

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
