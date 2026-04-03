import 'package:app/app/providers/ff1_bluetooth_device_providers.dart';
import 'package:app/app/providers/ff1_control_surface_providers.dart';
import 'package:app/app/providers/ff1_wifi_providers.dart';
import 'package:app/domain/models/ff1_device.dart';
import 'package:app/infra/ff1/wifi_protocol/ff1_wifi_messages.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'provider_test_helpers.dart';

void main() {
  group('FF1AudioControlNotifier.commitVolume', () {
    test(
      'zero-crossing to zero: setVolume failure after toggleMute undoes mute',
      () async {
        const topicId = 'topic-z1';
        const device = FF1Device(
          name: 'FF1',
          remoteId: 'r1',
          deviceId: 'd1',
          topicId: topicId,
        );

        final wifi = _VolumeCommitTestWifiControl()..failSetVolume = true;

        final container = ProviderContainer.test(
          overrides: [
            activeFF1BluetoothDeviceProvider.overrideWithValue(
              const AsyncData<FF1Device?>(device),
            ),
            ff1WifiControlProvider.overrideWithValue(wifi),
          ],
        );
        addTearDown(container.dispose);

        wifi.emitDeviceStatus(
          const FF1DeviceStatus(volume: 50, isMuted: false),
        );
        await Future<void>.delayed(Duration.zero);

        expect(
          container.read(ff1AudioControlProvider(topicId)).isTopicActive,
          isTrue,
        );
        final notifier = container.read(
          ff1AudioControlProvider(topicId).notifier,
        );

        await expectLater(
          notifier.commitVolume(0),
          throwsException,
        );

        expect(wifi.toggleMuteCount, 2);
        expect(wifi.setVolumeCallCount, 1);
      },
    );

    test(
      'zero-crossing from muted: setVolume failure after toggleMute undoes '
      'unmute',
      () async {
        const topicId = 'topic-z2';
        const device = FF1Device(
          name: 'FF1',
          remoteId: 'r2',
          deviceId: 'd2',
          topicId: topicId,
        );

        final wifi = _VolumeCommitTestWifiControl()..failSetVolume = true;

        final container = ProviderContainer.test(
          overrides: [
            activeFF1BluetoothDeviceProvider.overrideWithValue(
              const AsyncData<FF1Device?>(device),
            ),
            ff1WifiControlProvider.overrideWithValue(wifi),
          ],
        );
        addTearDown(container.dispose);

        wifi.emitDeviceStatus(
          const FF1DeviceStatus(volume: 50, isMuted: true),
        );
        await Future<void>.delayed(Duration.zero);

        expect(
          container.read(ff1AudioControlProvider(topicId)).isTopicActive,
          isTrue,
        );
        final notifier = container.read(
          ff1AudioControlProvider(topicId).notifier,
        );

        await expectLater(
          notifier.commitVolume(40),
          throwsException,
        );

        expect(wifi.toggleMuteCount, 2);
        expect(wifi.setVolumeCallCount, 1);
      },
    );

    test(
      'no zero-crossing: setVolume failure does not call toggleMute',
      () async {
        const topicId = 'topic-nz';
        const device = FF1Device(
          name: 'FF1',
          remoteId: 'r3',
          deviceId: 'd3',
          topicId: topicId,
        );

        final wifi = _VolumeCommitTestWifiControl()..failSetVolume = true;

        final container = ProviderContainer.test(
          overrides: [
            activeFF1BluetoothDeviceProvider.overrideWithValue(
              const AsyncData<FF1Device?>(device),
            ),
            ff1WifiControlProvider.overrideWithValue(wifi),
          ],
        );
        addTearDown(container.dispose);

        wifi.emitDeviceStatus(
          const FF1DeviceStatus(volume: 50, isMuted: false),
        );
        await Future<void>.delayed(Duration.zero);

        expect(
          container.read(ff1AudioControlProvider(topicId)).isTopicActive,
          isTrue,
        );
        final notifier = container.read(
          ff1AudioControlProvider(topicId).notifier,
        );

        await expectLater(
          notifier.commitVolume(60),
          throwsException,
        );

        expect(wifi.toggleMuteCount, 0);
        expect(wifi.setVolumeCallCount, 1);
      },
    );

    test(
      'toggleMute failure does not run undo path',
      () async {
        const topicId = 'topic-tf';
        const device = FF1Device(
          name: 'FF1',
          remoteId: 'r4',
          deviceId: 'd4',
          topicId: topicId,
        );

        final wifi = _VolumeCommitTestWifiControl()
          ..failToggleMute = true;

        final container = ProviderContainer.test(
          overrides: [
            activeFF1BluetoothDeviceProvider.overrideWithValue(
              const AsyncData<FF1Device?>(device),
            ),
            ff1WifiControlProvider.overrideWithValue(wifi),
          ],
        );
        addTearDown(container.dispose);

        wifi.emitDeviceStatus(
          const FF1DeviceStatus(volume: 50, isMuted: false),
        );
        await Future<void>.delayed(Duration.zero);

        expect(
          container.read(ff1AudioControlProvider(topicId)).isTopicActive,
          isTrue,
        );
        final notifier = container.read(
          ff1AudioControlProvider(topicId).notifier,
        );

        await expectLater(
          notifier.commitVolume(0),
          throwsException,
        );

        expect(wifi.toggleMuteCount, 1);
        expect(wifi.setVolumeCallCount, 0);
      },
    );
  });
}

/// Test double: records mute/volume calls and can fail each step independently.
final class _VolumeCommitTestWifiControl extends FakeWifiControl {
  int toggleMuteCount = 0;
  int setVolumeCallCount = 0;
  bool failSetVolume = false;
  bool failToggleMute = false;

  @override
  Future<FF1CommandResponse> toggleMute({required String topicId}) async {
    toggleMuteCount++;
    if (failToggleMute) {
      throw Exception('toggleMute failed');
    }
    return FF1CommandResponse(status: 'ok');
  }

  @override
  Future<FF1CommandResponse> setVolume({
    required String topicId,
    required int percent,
  }) async {
    setVolumeCallCount++;
    if (failSetVolume) {
      throw Exception('setVolume failed');
    }
    return FF1CommandResponse(status: 'ok');
  }
}
