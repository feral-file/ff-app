import 'dart:async';

import 'package:app/app/providers/ff1_bluetooth_device_providers.dart';
import 'package:app/app/providers/ff1_control_surface_providers.dart';
import 'package:app/app/providers/ff1_wifi_providers.dart';
import 'package:app/domain/models/ff1/ffp_ddc_panel_status.dart';
import 'package:app/domain/models/ff1_device.dart';
import 'package:app/infra/ff1/wifi_control/ff1_wifi_control.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'provider_test_helpers.dart';

void main() {
  group('FF1FfpDdcControlNotifier', () {
    test(
      'later brightness failure preserves an earlier optimistic write',
      () async {
        const topicId = 'topic-brightness';
        const device = FF1Device(
          name: 'FF1',
          remoteId: 'r1',
          deviceId: 'd1',
          topicId: topicId,
        );

        final wifi = _DdcCommitTestWifiControl();
        const initialStatus = FfpDdcPanelStatus(
          brightness: 20,
          contrast: 30,
          monitor: 'Test Monitor',
        );

        final container = ProviderContainer.test(
          overrides: [
            activeFF1BluetoothDeviceProvider.overrideWithValue(
              const AsyncData<FF1Device?>(device),
            ),
            ff1WifiControlProvider.overrideWithValue(wifi),
            ff1FfpDdcPanelStatusStreamProvider(topicId).overrideWith(
              (ref) => Stream.value(initialStatus),
            ),
          ],
        );
        addTearDown(container.dispose);

        final subscription = container.listen<FfpDdcPanelStatus>(
          ff1FfpDdcControlProvider(topicId),
          (_, _) {},
        );
        addTearDown(subscription.close);

        final notifier = container.read(
          ff1FfpDdcControlProvider(topicId).notifier,
        );
        await Future<void>.delayed(Duration.zero);

        await notifier.commitBrightness(80);
        expect(
          container.read(ff1FfpDdcControlProvider(topicId)).brightness,
          80,
        );

        wifi.brightnessShouldThrow = true;
        await expectLater(
          notifier.commitBrightness(60),
          throwsException,
        );

        expect(
          container.read(ff1FfpDdcControlProvider(topicId)).brightness,
          80,
          reason:
              'A later failed brightness write must preserve the earlier '
              'optimistic value.',
        );
      },
    );

    test(
      'later contrast failure preserves an earlier optimistic write',
      () async {
        const topicId = 'topic-contrast';
        const device = FF1Device(
          name: 'FF1',
          remoteId: 'r2',
          deviceId: 'd2',
          topicId: topicId,
        );

        final wifi = _DdcCommitTestWifiControl();
        const initialStatus = FfpDdcPanelStatus(
          brightness: 20,
          contrast: 30,
          monitor: 'Test Monitor',
        );

        final container = ProviderContainer.test(
          overrides: [
            activeFF1BluetoothDeviceProvider.overrideWithValue(
              const AsyncData<FF1Device?>(device),
            ),
            ff1WifiControlProvider.overrideWithValue(wifi),
            ff1FfpDdcPanelStatusStreamProvider(topicId).overrideWith(
              (ref) => Stream.value(initialStatus),
            ),
          ],
        );
        addTearDown(container.dispose);

        final subscription = container.listen<FfpDdcPanelStatus>(
          ff1FfpDdcControlProvider(topicId),
          (_, _) {},
        );
        addTearDown(subscription.close);

        final notifier = container.read(
          ff1FfpDdcControlProvider(topicId).notifier,
        );
        await Future<void>.delayed(Duration.zero);

        await notifier.commitContrast(85);
        expect(
          container.read(ff1FfpDdcControlProvider(topicId)).contrast,
          85,
        );

        wifi.contrastShouldThrow = true;
        await expectLater(
          notifier.commitContrast(55),
          throwsException,
        );

        expect(
          container.read(ff1FfpDdcControlProvider(topicId)).contrast,
          85,
          reason:
              'A later failed contrast write must preserve the earlier '
              'optimistic value.',
        );
      },
    );
  });
}

final class _DdcCommitTestWifiControl extends FF1WifiControl {
  _DdcCommitTestWifiControl()
    : super(
        transport: FakeWifiTransport(),
        restClient: null,
      );

  bool brightnessShouldThrow = false;
  bool contrastShouldThrow = false;

  @override
  Future<void> setFfpMonitorBrightness({
    required String topicId,
    required String monitorId,
    required int percent,
  }) async {
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
    if (contrastShouldThrow) {
      throw Exception('contrast failed');
    }
  }
}
