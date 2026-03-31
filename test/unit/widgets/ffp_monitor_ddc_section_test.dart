import 'dart:async';

import 'package:app/app/providers/ff1_device_provider.dart';
import 'package:app/app/providers/ff1_wifi_providers.dart';
import 'package:app/domain/models/ff1/ffp_ddc_panel_status.dart';
import 'package:app/domain/models/ff1_device.dart';
import 'package:app/infra/ff1/wifi_control/ff1_wifi_control.dart';
import 'package:app/infra/ff1/wifi_protocol/ff1_wifi_messages.dart';
import 'package:app/infra/ff1/wifi_transport/ff1_wifi_transport.dart';
import 'package:app/widgets/device_configuration/ffp_monitor_ddc_section.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'brightness slider keeps the requested value when resync reads stale data',
    (tester) async {
      const topicId = 'topic-1';
      const oldStatus = FfpDdcPanelStatus(
        brightness: 20,
        monitor: 'Test Monitor',
      );
      const staleResync = FfpDdcPanelStatus(
        brightness: 20,
        monitor: 'Test Monitor',
      );
      final control = _FakeWifiControl(resyncedStatus: staleResync);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ff1WifiControlProvider.overrideWithValue(control),
            ff1FfpDdcPanelStatusStreamProvider(
              topicId,
            ).overrideWith((ref) => Stream.value(oldStatus)),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: FfpMonitorDdcSection(
                topicId: topicId,
                isConnected: true,
                isControllable: true,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final sliderFinder = find.descendant(
        of: find.byKey(const ValueKey('ffp_brightness_slider')),
        matching: find.byType(Slider),
      );
      expect(sliderFinder, findsOneWidget);
      expect(tester.widget<Slider>(sliderFinder).value, 20);

      final slider = tester.widget<Slider>(sliderFinder);
      slider.onChanged!(80);
      await tester.pump();
      expect(tester.widget<Slider>(sliderFinder).value, 80);

      slider.onChangeEnd!(80);
      await tester.pumpAndSettle();

      expect(control.lastBrightness, 80);
      expect(
        tester.widget<Slider>(sliderFinder).value,
        80,
        reason:
            'The immediate resync can still report the pre-write brightness. '
            'The widget must keep the requested value until '
            'polling catches up.',
      );
    },
  );
}

class _FakeWifiControl extends FF1WifiControl {
  _FakeWifiControl({required this.resyncedStatus})
    : super(
        transport: _FakeWifiTransport(),
        restClient: null,
      );

  final FfpDdcPanelStatus resyncedStatus;
  int? lastBrightness;

  @override
  Future<FfpDdcPanelStatus> getFfpDdcPanelStatus({
    required String topicId,
  }) async {
    return resyncedStatus;
  }

  @override
  Future<void> setFfpMonitorBrightness({
    required String topicId,
    required String monitorId,
    required int percent,
  }) async {
    lastBrightness = percent;
  }
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
