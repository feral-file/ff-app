import 'dart:async';

import 'package:app/app/providers/ff1_bluetooth_device_providers.dart';
import 'package:app/app/providers/ff1_wifi_providers.dart';
import 'package:app/domain/models/ff1_device.dart';
import 'package:app/infra/ff1/wifi_protocol/ff1_wifi_messages.dart';
import 'package:app/widgets/device_configuration/audio_control.dart';
import 'package:app/widgets/device_configuration/icon_slider_control.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../app/providers/provider_test_helpers.dart';

void main() {
  const device = FF1Device(
    name: 'FF1 Test',
    remoteId: 'remote-id',
    deviceId: 'device-id',
    topicId: 'topic-1',
  );
  const otherDevice = FF1Device(
    name: 'FF1 Other',
    remoteId: 'remote-id-2',
    deviceId: 'device-id-2',
    topicId: 'topic-2',
  );

  testWidgets('seeds muted icon state from device status', (tester) async {
    final control = _FakeAudioWifiControl();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ff1WifiControlProvider.overrideWithValue(control),
          activeFF1BluetoothDeviceProvider.overrideWith((ref) {
            return Stream.value(device);
          }),
          ff1CurrentDeviceStatusProvider.overrideWith(
            (ref) => const FF1DeviceStatus(
              volume: 25,
              isMuted: true,
            ),
          ),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: AudioControl(topicId: device.topicId),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final widget = tester.widget<IconSliderControl>(
      find.byType(IconSliderControl),
    );
    expect(widget.iconAsset, 'assets/images/icon_volume_muted.svg');
    expect(widget.value, 0);
  });

  testWidgets('tapping the icon routes to toggleMute', (tester) async {
    final control = _FakeAudioWifiControl();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ff1WifiControlProvider.overrideWithValue(control),
          activeFF1BluetoothDeviceProvider.overrideWith((ref) {
            return Stream.value(device);
          }),
          ff1CurrentDeviceStatusProvider.overrideWith(
            (ref) => const FF1DeviceStatus(
              volume: 40,
              isMuted: false,
            ),
          ),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: AudioControl(topicId: device.topicId),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final widget = tester.widget<IconSliderControl>(
      find.byType(IconSliderControl),
    );
    widget.onIconTap!.call();
    await tester.pump();

    expect(control.toggleMuteTopicId, device.topicId);
    expect(control.lastSetVolume, isNull);
    expect(
      tester.widget<IconSliderControl>(find.byType(IconSliderControl)).value,
      0,
      reason:
          'Muting should move the slider thumb to 0 to match the muted icon.',
    );
  });

  testWidgets(
    'shows the initial audio state before any device status arrives',
    (tester) async {
      final control = _FakeAudioWifiControl();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ff1WifiControlProvider.overrideWithValue(control),
            activeFF1BluetoothDeviceProvider.overrideWith((ref) {
              return Stream.value(device);
            }),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: AudioControl(topicId: device.topicId),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final widget = tester.widget<IconSliderControl>(
        find.byType(IconSliderControl),
      );
      expect(widget.iconAsset, 'assets/images/icon_volume.svg');
      expect(widget.value, 50);
      expect(widget.enabled, isTrue);
    },
  );

  testWidgets(
    'later device status updates replace optimistic audio state '
    'after confirmation',
    (tester) async {
      final control = _FakeAudioWifiControl();
      final activeDeviceStream = StreamController<FF1Device?>.broadcast();
      final container = ProviderContainer(
        overrides: [
          ff1WifiControlProvider.overrideWithValue(control),
          activeFF1BluetoothDeviceProvider.overrideWith((ref) {
            return activeDeviceStream.stream;
          }),
        ],
      );

      addTearDown(activeDeviceStream.close);
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: AudioControl(topicId: device.topicId),
            ),
          ),
        ),
      );

      activeDeviceStream.add(device);
      control.emitDeviceStatus(
        const FF1DeviceStatus(
          volume: 20,
          isMuted: false,
        ),
      );
      await tester.pump();
      await tester.pump();

      final controlWidget = tester.widget<IconSliderControl>(
        find.byType(IconSliderControl),
      );
      expect(controlWidget.value, 20);

      controlWidget.onChanged(80);
      await tester.pump();
      expect(
        tester.widget<IconSliderControl>(find.byType(IconSliderControl)).value,
        80,
      );

      controlWidget.onChangeEnd?.call(80);
      await tester.pumpAndSettle();
      expect(control.lastSetVolume, 80);

      control.emitDeviceStatus(
        const FF1DeviceStatus(
          volume: 80,
          isMuted: false,
        ),
      );
      await tester.pump();
      await tester.pump();
      control.emitDeviceStatus(
        const FF1DeviceStatus(
          volume: 65,
          isMuted: false,
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(
        tester.widget<IconSliderControl>(find.byType(IconSliderControl)).value,
        65,
        reason:
            'Once the device confirms the optimistic value, later status '
            'pushes must drive the shared audio control again.',
      );
    },
  );

  testWidgets(
    'non-integer volume commit still reconciles to integer device updates',
    (tester) async {
      final control = _FakeAudioWifiControl();
      final activeDeviceStream = StreamController<FF1Device?>.broadcast();
      final container = ProviderContainer(
        overrides: [
          ff1WifiControlProvider.overrideWithValue(control),
          activeFF1BluetoothDeviceProvider.overrideWith((ref) {
            return activeDeviceStream.stream;
          }),
        ],
      );

      addTearDown(activeDeviceStream.close);
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: AudioControl(topicId: device.topicId),
            ),
          ),
        ),
      );

      activeDeviceStream.add(device);
      control.emitDeviceStatus(
        const FF1DeviceStatus(
          volume: 20,
          isMuted: false,
        ),
      );
      await tester.pump();
      await tester.pump();

      final controlWidget = tester.widget<IconSliderControl>(
        find.byType(IconSliderControl),
      );
      controlWidget.onChanged(80.4);
      await tester.pump();
      controlWidget.onChangeEnd?.call(80.4);
      await tester.pumpAndSettle();

      control.emitDeviceStatus(
        const FF1DeviceStatus(
          volume: 80,
          isMuted: false,
        ),
      );
      await tester.pump();
      await tester.pump();
      control.emitDeviceStatus(
        const FF1DeviceStatus(
          volume: 65,
          isMuted: false,
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(
        tester.widget<IconSliderControl>(find.byType(IconSliderControl)).value,
        65,
        reason:
            'The optimistic non-integer slider value must reconcile to the '
            'integer device status and stop overriding later pushes.',
      );
    },
  );

  testWidgets('mute toggle rolls back when the command fails', (tester) async {
    final control = _FakeAudioWifiControl()..toggleMuteShouldThrow = true;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ff1WifiControlProvider.overrideWithValue(control),
          activeFF1BluetoothDeviceProvider.overrideWith((ref) {
            return Stream.value(device);
          }),
          ff1CurrentDeviceStatusProvider.overrideWith(
            (ref) => const FF1DeviceStatus(
              volume: 40,
              isMuted: false,
            ),
          ),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: AudioControl(topicId: device.topicId),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final widget = tester.widget<IconSliderControl>(
      find.byType(IconSliderControl),
    );
    widget.onIconTap!.call();
    await tester.pumpAndSettle();

    expect(control.toggleMuteTopicId, device.topicId);
    expect(
      tester
          .widget<IconSliderControl>(find.byType(IconSliderControl))
          .iconAsset,
      'assets/images/icon_volume.svg',
      reason: 'The provider must roll back the optimistic mute state on error.',
    );
  });

  testWidgets(
    'unmuting restores the last non-zero volume immediately',
    (tester) async {
      final control = _FakeAudioWifiControl();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ff1WifiControlProvider.overrideWithValue(control),
            activeFF1BluetoothDeviceProvider.overrideWith((ref) {
              return Stream.value(device);
            }),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: AudioControl(topicId: device.topicId),
            ),
          ),
        ),
      );

      control.emitDeviceStatus(
        const FF1DeviceStatus(
          volume: 35,
          isMuted: false,
        ),
      );
      await tester.pump();
      await tester.pump();

      final widget = tester.widget<IconSliderControl>(
        find.byType(IconSliderControl),
      );
      widget.onIconTap?.call();
      await tester.pumpAndSettle();

      control.emitDeviceStatus(
        const FF1DeviceStatus(
          volume: 0,
          isMuted: true,
        ),
      );
      await tester.pump();
      await tester.pump();

      final mutedWidget = tester.widget<IconSliderControl>(
        find.byType(IconSliderControl),
      );
      expect(mutedWidget.iconAsset, 'assets/images/icon_volume_muted.svg');
      expect(mutedWidget.value, 0);

      mutedWidget.onIconTap?.call();
      await tester.pump();

      final unmutedWidget = tester.widget<IconSliderControl>(
        find.byType(IconSliderControl),
      );
      expect(unmutedWidget.iconAsset, 'assets/images/icon_volume.svg');
      expect(
        unmutedWidget.value,
        35,
        reason:
            'The provider should keep the last confirmed non-zero volume and '
            'restore it immediately when unmuting.',
      );
    },
  );

  testWidgets('dragging from muted 0 to >0 unmutes before committing volume', (
    tester,
  ) async {
    final control = _FakeAudioWifiControl();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ff1WifiControlProvider.overrideWithValue(control),
          activeFF1BluetoothDeviceProvider.overrideWith((ref) {
            return Stream.value(device);
          }),
          ff1CurrentDeviceStatusProvider.overrideWith(
            (ref) => const FF1DeviceStatus(
              volume: 30,
              isMuted: true,
            ),
          ),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: AudioControl(topicId: device.topicId),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final widget = tester.widget<IconSliderControl>(
      find.byType(IconSliderControl),
    );
    widget.onChanged(80);
    await tester.pump();
    widget.onChangeEnd?.call(80);
    await tester.pumpAndSettle();

    expect(control.toggleMuteTopicId, device.topicId);
    expect(control.lastSetVolume, 80);
    expect(
      tester
          .widget<IconSliderControl>(find.byType(IconSliderControl))
          .iconAsset,
      'assets/images/icon_volume.svg',
    );
  });

  testWidgets('dragging from >0 to 0 toggles mute on', (tester) async {
    final control = _FakeAudioWifiControl();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ff1WifiControlProvider.overrideWithValue(control),
          activeFF1BluetoothDeviceProvider.overrideWith((ref) {
            return Stream.value(device);
          }),
          ff1CurrentDeviceStatusProvider.overrideWith(
            (ref) => const FF1DeviceStatus(
              volume: 40,
              isMuted: false,
            ),
          ),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: AudioControl(topicId: device.topicId),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final widget = tester.widget<IconSliderControl>(
      find.byType(IconSliderControl),
    );
    widget.onChanged(0);
    await tester.pump();
    widget.onChangeEnd?.call(0);
    await tester.pumpAndSettle();

    expect(control.toggleMuteTopicId, device.topicId);
    expect(control.lastSetVolume, 0);
    expect(
      tester
          .widget<IconSliderControl>(find.byType(IconSliderControl))
          .iconAsset,
      'assets/images/icon_volume_muted.svg',
    );
  });

  testWidgets('volume commit failure rolls back to confirmed device status', (
    tester,
  ) async {
    final control = _FakeAudioWifiControl()..setVolumeShouldThrow = true;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ff1WifiControlProvider.overrideWithValue(control),
          activeFF1BluetoothDeviceProvider.overrideWith((ref) {
            return Stream.value(device);
          }),
          ff1CurrentDeviceStatusProvider.overrideWith(
            (ref) => const FF1DeviceStatus(
              volume: 40,
              isMuted: false,
            ),
          ),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: AudioControl(topicId: device.topicId),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final widget = tester.widget<IconSliderControl>(
      find.byType(IconSliderControl),
    );
    widget.onChanged(80);
    await tester.pump();
    expect(
      tester.widget<IconSliderControl>(find.byType(IconSliderControl)).value,
      80,
    );

    widget.onChangeEnd?.call(80);
    await tester.pumpAndSettle();

    expect(
      tester.widget<IconSliderControl>(find.byType(IconSliderControl)).value,
      40,
      reason: 'Failed setVolume must restore the last confirmed device value.',
    );
    expect(
      tester
          .widget<IconSliderControl>(find.byType(IconSliderControl))
          .iconAsset,
      'assets/images/icon_volume.svg',
    );
  });

  testWidgets('control resets when its topic stops being active', (
    tester,
  ) async {
    final control = _FakeAudioWifiControl();
    final activeDeviceStream = StreamController<FF1Device?>.broadcast();

    addTearDown(activeDeviceStream.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ff1WifiControlProvider.overrideWithValue(control),
          activeFF1BluetoothDeviceProvider.overrideWith((ref) {
            return activeDeviceStream.stream;
          }),
          ff1CurrentDeviceStatusProvider.overrideWith(
            (ref) => const FF1DeviceStatus(
              volume: 35,
              isMuted: false,
            ),
          ),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: AudioControl(topicId: device.topicId),
          ),
        ),
      ),
    );

    activeDeviceStream.add(device);
    await tester.pumpAndSettle();

    expect(
      tester.widget<IconSliderControl>(find.byType(IconSliderControl)).enabled,
      isTrue,
    );

    activeDeviceStream.add(otherDevice);
    await tester.pumpAndSettle();

    final widget = tester.widget<IconSliderControl>(
      find.byType(IconSliderControl),
    );
    expect(widget.enabled, isFalse);
    expect(widget.value, 50);
  });
}

class _FakeAudioWifiControl extends FakeWifiControl {
  _FakeAudioWifiControl();

  String? toggleMuteTopicId;
  int? lastSetVolume;
  bool toggleMuteShouldThrow = false;
  bool setVolumeShouldThrow = false;

  @override
  Future<FF1CommandResponse> toggleMute({required String topicId}) async {
    toggleMuteTopicId = topicId;
    if (toggleMuteShouldThrow) {
      throw Exception('toggle mute failed');
    }
    return FF1CommandResponse(status: 'ok');
  }

  @override
  Future<FF1CommandResponse> setVolume({
    required String topicId,
    required int percent,
  }) async {
    if (setVolumeShouldThrow) {
      throw Exception('set volume failed');
    }
    lastSetVolume = percent;
    return FF1CommandResponse(status: 'ok');
  }
}
