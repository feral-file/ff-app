import 'dart:async';

import 'package:app/app/providers/ff1_bluetooth_device_providers.dart';
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
  testWidgets('later relayer pushes replace the initial device state', (
    tester,
  ) async {
    const topicId = 'topic-1';
    const device = FF1Device(
      name: 'FF1 Test',
      remoteId: 'remote-id',
      deviceId: 'device-id',
      topicId: topicId,
    );
    final statuses = StreamController<FfpDdcPanelStatus>.broadcast();

    addTearDown(statuses.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          activeFF1BluetoothDeviceProvider.overrideWith((ref) {
            return Stream.value(device);
          }),
          ff1WifiControlProvider.overrideWithValue(_FakeWifiControl()),
          ff1FfpDdcPanelStatusStreamProvider(topicId).overrideWith((ref) {
            return statuses.stream;
          }),
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

    statuses.add(
      const FfpDdcPanelStatus(
        brightness: 20,
        monitor: 'Test Monitor',
      ),
    );
    await tester.pump();
    await tester.pump();

    final sliderFinder = find.descendant(
      of: find.byKey(const ValueKey('ffp_brightness_slider')),
      matching: find.byType(Slider),
    );
    expect(tester.widget<Slider>(sliderFinder).value, 20);

    statuses.add(
      const FfpDdcPanelStatus(
        brightness: 55,
        monitor: 'Test Monitor',
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(
      tester.widget<Slider>(sliderFinder).value,
      55,
      reason: 'A later relayer push must replace the initial device state.',
    );
  });

  testWidgets(
    'brightness slider keeps the requested value when resync reads stale data',
    (tester) async {
      const topicId = 'topic-1';
      const device = FF1Device(
        name: 'FF1 Test',
        remoteId: 'remote-id',
        deviceId: 'device-id',
        topicId: topicId,
      );
      const oldStatus = FfpDdcPanelStatus(
        brightness: 20,
        monitor: 'Test Monitor',
      );
      final control = _FakeWifiControl();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            activeFF1BluetoothDeviceProvider.overrideWith((ref) {
              return Stream.value(device);
            }),
            ff1WifiControlProvider.overrideWithValue(control),
            ff1FfpDdcPanelStatusStreamProvider(topicId).overrideWith(
              (ref) => Stream.value(oldStatus),
            ),
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
            'the relayer-pushed status catches up.',
      );
    },
  );

  testWidgets(
    'relayer status resumes updating after the optimistic value is confirmed',
    (tester) async {
      const topicId = 'topic-1';
      const device = FF1Device(
        name: 'FF1 Test',
        remoteId: 'remote-id',
        deviceId: 'device-id',
        topicId: topicId,
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
            ff1FfpDdcPanelStatusStreamProvider(topicId).overrideWith((ref) {
              return statuses.stream;
            }),
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

      statuses.add(
        const FfpDdcPanelStatus(
          brightness: 20,
          monitor: 'Test Monitor',
        ),
      );
      await tester.pump();
      await tester.pump();

      final sliderFinder = find.descendant(
        of: find.byKey(const ValueKey('ffp_brightness_slider')),
        matching: find.byType(Slider),
      );
      final slider = tester.widget<Slider>(sliderFinder);
      slider.onChanged!(80);
      await tester.pump();
      slider.onChangeEnd!(80);
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
            'Once the device confirms the optimistic value, later relayer '
            'pushes must update the control again.',
      );
    },
  );

  testWidgets(
    'brightness commit failure rolls back to confirmed relayer value',
    (tester) async {
      const topicId = 'topic-1';
      const device = FF1Device(
        name: 'FF1 Test',
        remoteId: 'remote-id',
        deviceId: 'device-id',
        topicId: topicId,
      );
      final control = _FakeWifiControl()..brightnessShouldThrow = true;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            activeFF1BluetoothDeviceProvider.overrideWith((ref) {
              return Stream.value(device);
            }),
            ff1WifiControlProvider.overrideWithValue(control),
            ff1FfpDdcPanelStatusStreamProvider(topicId).overrideWith(
              (ref) => Stream.value(
                const FfpDdcPanelStatus(
                  brightness: 20,
                  contrast: 30,
                  volume: 40,
                  monitor: 'Test Monitor',
                ),
              ),
            ),
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
      final slider = tester.widget<Slider>(sliderFinder);
      slider.onChanged!(80);
      await tester.pump();
      expect(tester.widget<Slider>(sliderFinder).value, 80);

      slider.onChangeEnd!(80);
      await tester.pumpAndSettle();

      expect(control.lastBrightness, 80);
      expect(
        tester.widget<Slider>(sliderFinder).value,
        20,
        reason: 'Failed write must roll back to the last confirmed status.',
      );
    },
  );

  testWidgets(
    'contrast commit failure rolls back to confirmed relayer value',
    (tester) async {
      const topicId = 'topic-1';
      const device = FF1Device(
        name: 'FF1 Test',
        remoteId: 'remote-id',
        deviceId: 'device-id',
        topicId: topicId,
      );
      final control = _FakeWifiControl()..contrastShouldThrow = true;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            activeFF1BluetoothDeviceProvider.overrideWith((ref) {
              return Stream.value(device);
            }),
            ff1WifiControlProvider.overrideWithValue(control),
            ff1FfpDdcPanelStatusStreamProvider(topicId).overrideWith(
              (ref) => Stream.value(
                const FfpDdcPanelStatus(
                  brightness: 20,
                  contrast: 30,
                  volume: 40,
                  monitor: 'Test Monitor',
                ),
              ),
            ),
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
        of: find.byKey(const ValueKey('ffp_contrast_slider')),
        matching: find.byType(Slider),
      );
      final slider = tester.widget<Slider>(sliderFinder);
      slider.onChanged!(85);
      await tester.pump();
      expect(tester.widget<Slider>(sliderFinder).value, 85);

      slider.onChangeEnd!(85);
      await tester.pumpAndSettle();

      expect(control.lastContrast, 85);
      expect(
        tester.widget<Slider>(sliderFinder).value,
        30,
        reason: 'Failed write must roll back to the last confirmed status.',
      );
    },
  );

  testWidgets(
    'monitor-volume commit failure rolls back to confirmed relayer value',
    (tester) async {
      const topicId = 'topic-1';
      const device = FF1Device(
        name: 'FF1 Test',
        remoteId: 'remote-id',
        deviceId: 'device-id',
        topicId: topicId,
      );
      final control = _FakeWifiControl()..volumeShouldThrow = true;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            activeFF1BluetoothDeviceProvider.overrideWith((ref) {
              return Stream.value(device);
            }),
            ff1WifiControlProvider.overrideWithValue(control),
            ff1FfpDdcPanelStatusStreamProvider(topicId).overrideWith(
              (ref) => Stream.value(
                const FfpDdcPanelStatus(
                  brightness: 20,
                  contrast: 30,
                  volume: 40,
                  monitor: 'Test Monitor',
                ),
              ),
            ),
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
        of: find.byKey(const ValueKey('ffp_monitor_volume_slider')),
        matching: find.byType(Slider),
      );
      final slider = tester.widget<Slider>(sliderFinder);
      slider.onChanged!(90);
      await tester.pump();
      expect(tester.widget<Slider>(sliderFinder).value, 90);

      slider.onChangeEnd!(90);
      await tester.pumpAndSettle();

      expect(control.lastVolume, 90);
      expect(
        tester.widget<Slider>(sliderFinder).value,
        40,
        reason: 'Failed write must roll back to the last confirmed status.',
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

  int? lastBrightness;
  int? lastContrast;
  int? lastVolume;
  bool brightnessShouldThrow = false;
  bool contrastShouldThrow = false;
  bool volumeShouldThrow = false;

  @override
  Future<void> setFfpMonitorBrightness({
    required String topicId,
    required String monitorId,
    required int percent,
  }) async {
    lastBrightness = percent;
    if (brightnessShouldThrow) {
      throw Exception('brightness failed');
    }
  }

  @override
  Future<void> setFfpMonitorContrast({
    required String topicId,
    required String monitorId,
    required int percent,
  }) async {
    lastContrast = percent;
    if (contrastShouldThrow) {
      throw Exception('contrast failed');
    }
  }

  @override
  Future<void> setFfpMonitorVolume({
    required String topicId,
    required String monitorId,
    required int percent,
  }) async {
    lastVolume = percent;
    if (volumeShouldThrow) {
      throw Exception('volume failed');
    }
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
