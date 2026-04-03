import 'dart:async';

import 'package:app/app/providers/ff1_bluetooth_device_providers.dart';
import 'package:app/app/providers/ff1_wifi_providers.dart';
import 'package:app/app/providers/version_provider.dart';
import 'package:app/domain/models/dp1/dp1_playlist_item.dart';
import 'package:app/domain/models/ff1_device.dart';
import 'package:app/infra/api/pubdoc_api.dart';
import 'package:app/infra/ff1/wifi_control/ff1_wifi_control.dart';
import 'package:app/infra/ff1/wifi_protocol/ff1_wifi_messages.dart';
import 'package:app/infra/ff1/wifi_transport/ff1_wifi_transport.dart';
import 'package:app/infra/services/version_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'provider_test_helpers.dart';

void main() {
  test('ff1 wifi params equality and default notifier state', () {
    // Unit test: verifies FF1 WiFi connect params equality and initial
    // connection state.
    const p1 = FF1WifiConnectParams(
      device: FF1Device(
        name: 'D',
        remoteId: 'r',
        deviceId: 'id',
        topicId: 'topic',
      ),
      userId: 'u1',
      apiKey: 'k1',
    );
    const p2 = FF1WifiConnectParams(
      device: FF1Device(
        name: 'D',
        remoteId: 'r',
        deviceId: 'id',
        topicId: 'topic',
      ),
      userId: 'u1',
      apiKey: 'k2',
    );
    expect(p1, p2);

    final container = ProviderContainer.test(
      overrides: [
        ff1WifiControlProvider.overrideWithValue(FakeWifiControl()),
      ],
    );
    addTearDown(container.dispose);
    expect(container.read(ff1WifiConnectionProvider).isConnected, isFalse);
  });

  test(
    'ff1AutoConnectWatcherProvider connects when active device is set',
    () async {
      // Unit test: verifies auto-connect watcher triggers connection
      // when active device changes.
      await ensureDotEnvLoaded();

      final deviceService = MockFF1BluetoothDeviceService();
      final wifiControl = FakeWifiControl();
      const device = FF1Device(
        name: 'FF1',
        remoteId: 'remote-1',
        deviceId: 'device-1',
        topicId: 'topic-1',
      );

      final container = ProviderContainer.test(
        overrides: [
          ff1BluetoothDeviceServiceProvider.overrideWithValue(deviceService),
          ff1WifiControlProvider.overrideWithValue(wifiControl),
          ff1WifiConnectionProvider.overrideWith(
            FF1WifiConnectionNotifier.new,
          ),
        ],
      );
      addTearDown(container.dispose);

      // Initially no active device
      deviceService
        ..devices = []
        ..activeDeviceId = null;

      // Watch the auto-connect provider to keep it alive
      container.listen(
        ff1AutoConnectWatcherProvider,
        (previous, next) {},
      );

      // Wait for initial state
      await container.read(activeFF1BluetoothDeviceProvider.future);

      // Verify no connection attempt yet
      expect(wifiControl.connectCalled, isFalse);

      // Set active device
      deviceService
        ..devices = [device]
        ..activeDeviceId = device.deviceId;
      container.invalidate(activeFF1BluetoothDeviceProvider);

      // Wait for active device to update
      await container.read(activeFF1BluetoothDeviceProvider.future);

      // Small delay to allow async connection to trigger
      await Future<void>.delayed(const Duration(milliseconds: 200));

      // Verify connection was attempted
      expect(wifiControl.connectCalled, isTrue);
      expect(wifiControl.lastConnectedDevice?.deviceId, device.deviceId);
    },
  );

  test(
    'ff1AutoConnectWatcherProvider disconnects when active device is removed',
    () async {
      // Unit test: verifies auto-connect watcher triggers disconnection
      // when active device is removed.
      await ensureDotEnvLoaded();

      final deviceService = MockFF1BluetoothDeviceService();
      final wifiControl = FakeWifiControl();
      const device = FF1Device(
        name: 'FF1',
        remoteId: 'remote-1',
        deviceId: 'device-1',
        topicId: 'topic-1',
      );

      final container = ProviderContainer.test(
        overrides: [
          ff1BluetoothDeviceServiceProvider.overrideWithValue(deviceService),
          ff1WifiControlProvider.overrideWithValue(wifiControl),
          ff1WifiConnectionProvider.overrideWith(
            FF1WifiConnectionNotifier.new,
          ),
        ],
      );
      addTearDown(container.dispose);

      // Start with active device
      deviceService
        ..devices = [device]
        ..activeDeviceId = device.deviceId;

      // Watch the auto-connect provider to keep it alive
      container.listen(
        ff1AutoConnectWatcherProvider,
        (previous, next) {},
      );

      // Wait for initial connection
      await container.read(activeFF1BluetoothDeviceProvider.future);
      await Future<void>.delayed(const Duration(milliseconds: 200));

      expect(wifiControl.connectCalled, isTrue);

      // Remove active device
      deviceService.activeDeviceId = null;
      container.invalidate(activeFF1BluetoothDeviceProvider);

      // Wait for active device to update
      await container.read(activeFF1BluetoothDeviceProvider.future);
      await Future<void>.delayed(const Duration(milliseconds: 200));

      // Verify disconnection was attempted
      expect(wifiControl.disconnectCalled, isTrue);
    },
  );

  test(
    'ff1CurrentPlayerStatusProvider clears live status on device switch '
    'even while stream still replays previous payload',
    () async {
      const deviceA = FF1Device(
        name: 'FF1-A',
        remoteId: 'remote-a',
        deviceId: 'device-a',
        topicId: 'topic-a',
      );
      const deviceB = FF1Device(
        name: 'FF1-B',
        remoteId: 'remote-b',
        deviceId: 'device-b',
        topicId: 'topic-b',
      );
      final statusA = FF1PlayerStatus(
        playlistId: 'playlist-a',
        currentWorkIndex: 0,
        items: const <DP1PlaylistItem>[],
      );

      final wifiControl = FakeWifiControl();
      final container = ProviderContainer.test(
        overrides: [
          ff1WifiControlProvider.overrideWithValue(wifiControl),
          ff1WifiConnectionProvider.overrideWith(
            FF1WifiConnectionNotifier.new,
          ),
        ],
      );
      addTearDown(container.dispose);

      container
        ..listen<AsyncValue<FF1PlayerStatus>>(
          ff1PlayerStatusStreamProvider,
          (_, _) {},
        )
        ..listen<AsyncValue<FF1ConnectionStatus>>(
          ff1ConnectionStatusStreamProvider,
          (_, _) {},
        )
        ..listen<FF1PlayerStatus?>(
          ff1CurrentPlayerStatusProvider,
          (_, _) {},
        );

      await container
          .read(ff1WifiConnectionProvider.notifier)
          .connect(
            device: deviceA,
            userId: 'user-a',
            apiKey: 'key-a',
          );
      wifiControl
        ..emitConnectionStatus(isConnected: true)
        ..emitPlayerStatus(statusA);
      await Future<void>.delayed(Duration.zero);

      expect(
        container.read(ff1CurrentPlayerStatusProvider)?.playlistId,
        statusA.playlistId,
      );

      await container
          .read(ff1WifiConnectionProvider.notifier)
          .connect(
            device: deviceB,
            userId: 'user-b',
            apiKey: 'key-b',
          );
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(
        container.read(ff1PlayerStatusStreamProvider).asData?.value.playlistId,
        statusA.playlistId,
      );
      expect(container.read(ff1CurrentPlayerStatusProvider), isNull);
    },
  );

  test(
    'transport disconnect clears current player and device status providers',
    () async {
      const device = FF1Device(
        name: 'FF1',
        remoteId: 'remote-1',
        deviceId: 'device-1',
        topicId: 'topic-1',
      );
      final playerStatus = FF1PlayerStatus(
        playlistId: 'playlist-a',
        currentWorkIndex: 0,
        items: const <DP1PlaylistItem>[],
      );
      const deviceStatus = FF1DeviceStatus(
        connectedWifi: 'studio',
        internetConnected: true,
      );

      final wifiControl = FakeWifiControl();
      final container = ProviderContainer.test(
        overrides: [
          ff1WifiControlProvider.overrideWithValue(wifiControl),
          ff1WifiConnectionProvider.overrideWith(
            FF1WifiConnectionNotifier.new,
          ),
        ],
      );
      addTearDown(container.dispose);

      container
        ..listen<AsyncValue<FF1PlayerStatus>>(
          ff1PlayerStatusStreamProvider,
          (_, _) {},
        )
        ..listen<AsyncValue<FF1DeviceStatus>>(
          ff1DeviceStatusStreamProvider,
          (_, _) {},
        )
        ..listen<AsyncValue<FF1ConnectionStatus>>(
          ff1ConnectionStatusStreamProvider,
          (_, _) {},
        )
        ..listen<FF1PlayerStatus?>(
          ff1CurrentPlayerStatusProvider,
          (_, _) {},
        )
        ..listen<FF1DeviceStatus?>(
          ff1CurrentDeviceStatusProvider,
          (_, _) {},
        );

      await container
          .read(ff1WifiConnectionProvider.notifier)
          .connect(
            device: device,
            userId: 'user-a',
            apiKey: 'key-a',
          );
      wifiControl
        ..emitConnectionStatus(isConnected: true)
        ..emitPlayerStatus(playerStatus)
        ..emitDeviceStatus(deviceStatus);
      await Future<void>.delayed(Duration.zero);

      expect(
        container.read(ff1CurrentPlayerStatusProvider)?.playlistId,
        playerStatus.playlistId,
      );
      expect(
        container.read(ff1CurrentDeviceStatusProvider)?.connectedWifi,
        deviceStatus.connectedWifi,
      );

      wifiControl.emitTransportConnection(isConnected: false);
      await Future<void>.delayed(Duration.zero);

      expect(container.read(ff1CurrentPlayerStatusProvider), isNull);
      expect(container.read(ff1CurrentDeviceStatusProvider), isNull);
    },
  );

  test(
    'device switch resets ff1DeviceConnectedProvider before new '
    'connection notification',
    () async {
      const deviceA = FF1Device(
        name: 'FF1-A',
        remoteId: 'remote-a',
        deviceId: 'device-a',
        topicId: 'topic-a',
      );
      const deviceB = FF1Device(
        name: 'FF1-B',
        remoteId: 'remote-b',
        deviceId: 'device-b',
        topicId: 'topic-b',
      );

      final wifiControl = FakeWifiControl();
      final container = ProviderContainer.test(
        overrides: [
          ff1WifiControlProvider.overrideWithValue(wifiControl),
          ff1WifiConnectionProvider.overrideWith(
            FF1WifiConnectionNotifier.new,
          ),
        ],
      );
      addTearDown(container.dispose);

      container
        ..listen<AsyncValue<FF1ConnectionStatus>>(
          ff1ConnectionStatusStreamProvider,
          (_, _) {},
        )
        ..listen<bool>(
          ff1DeviceConnectedProvider,
          (_, _) {},
        );

      await container
          .read(ff1WifiConnectionProvider.notifier)
          .connect(
            device: deviceA,
            userId: 'user-a',
            apiKey: 'key-a',
          );
      wifiControl.emitConnectionStatus(isConnected: true);
      await Future<void>.delayed(Duration.zero);

      expect(container.read(ff1DeviceConnectedProvider), isTrue);

      await container
          .read(ff1WifiConnectionProvider.notifier)
          .connect(
            device: deviceB,
            userId: 'user-b',
            apiKey: 'key-b',
          );
      await Future<void>.delayed(Duration.zero);

      expect(container.read(ff1DeviceConnectedProvider), isFalse);
    },
  );

  test(
    'auto-connect version check waits for fresh device status after switch',
    () async {
      await ensureDotEnvLoaded();

      final deviceService = MockFF1BluetoothDeviceService();
      final wifiControl = FakeWifiControl();
      final versionService = _RecordingVersionService();
      const deviceA = FF1Device(
        name: 'FF1-A',
        remoteId: 'remote-a',
        deviceId: 'device-a',
        topicId: 'topic-a',
        branchName: 'main',
      );
      const deviceB = FF1Device(
        name: 'FF1-B',
        remoteId: 'remote-b',
        deviceId: 'device-b',
        topicId: 'topic-b',
        branchName: 'main',
      );

      final container = ProviderContainer.test(
        overrides: [
          ff1BluetoothDeviceServiceProvider.overrideWithValue(deviceService),
          ff1WifiControlProvider.overrideWithValue(wifiControl),
          ff1WifiConnectionProvider.overrideWith(
            FF1WifiConnectionNotifier.new,
          ),
          versionServiceProvider.overrideWithValue(versionService),
        ],
      );
      addTearDown(container.dispose);

      container
        ..listen(
          ff1AutoConnectWatcherProvider,
          (_, _) {},
        )
        ..listen<AsyncValue<FF1ConnectionStatus>>(
          ff1ConnectionStatusStreamProvider,
          (_, _) {},
        )
        ..listen<AsyncValue<FF1DeviceStatus>>(
          ff1DeviceStatusStreamProvider,
          (_, _) {},
        );

      deviceService
        ..devices = [deviceA]
        ..activeDeviceId = deviceA.deviceId;
      container.invalidate(activeFF1BluetoothDeviceProvider);
      await container.read(activeFF1BluetoothDeviceProvider.future);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      wifiControl.emitDeviceStatus(
        const FF1DeviceStatus(latestVersion: '1.0.0'),
      );
      await Future<void>.delayed(const Duration(milliseconds: 120));

      expect(versionService.deviceVersions, ['1.0.0']);

      deviceService
        ..devices = [deviceA, deviceB]
        ..activeDeviceId = deviceB.deviceId;
      container.invalidate(activeFF1BluetoothDeviceProvider);
      await container.read(activeFF1BluetoothDeviceProvider.future);
      await Future<void>.delayed(const Duration(milliseconds: 100));

      expect(wifiControl.lastConnectedDevice?.deviceId, deviceB.deviceId);

      wifiControl.emitDeviceStatus(
        const FF1DeviceStatus(latestVersion: '2.0.0'),
      );
      await Future<void>.delayed(const Duration(milliseconds: 250));

      expect(versionService.deviceVersions, contains('1.0.0'));
      expect(versionService.deviceVersions.last, '2.0.0');
      expect(versionService.deviceVersions, isNot(contains('')));
    },
  );

  test(
    'auto-connect version check uses device status emitted during connect',
    () async {
      await ensureDotEnvLoaded();

      final deviceService = MockFF1BluetoothDeviceService();
      final wifiControl = _AutoStatusWifiControl(
        statusesByDeviceId: const {
          'device-a': FF1DeviceStatus(latestVersion: '1.0.0'),
          'device-b': FF1DeviceStatus(latestVersion: '2.0.0'),
        },
      );
      final versionService = _RecordingVersionService();
      const deviceA = FF1Device(
        name: 'FF1-A',
        remoteId: 'remote-a',
        deviceId: 'device-a',
        topicId: 'topic-a',
        branchName: 'main',
      );
      const deviceB = FF1Device(
        name: 'FF1-B',
        remoteId: 'remote-b',
        deviceId: 'device-b',
        topicId: 'topic-b',
        branchName: 'main',
      );

      final container = ProviderContainer.test(
        overrides: [
          ff1BluetoothDeviceServiceProvider.overrideWithValue(deviceService),
          ff1WifiControlProvider.overrideWithValue(wifiControl),
          ff1WifiConnectionProvider.overrideWith(
            FF1WifiConnectionNotifier.new,
          ),
          versionServiceProvider.overrideWithValue(versionService),
        ],
      );
      addTearDown(container.dispose);

      container.listen(
        ff1AutoConnectWatcherProvider,
        (_, _) {},
      );

      deviceService
        ..devices = [deviceA]
        ..activeDeviceId = deviceA.deviceId;
      container.invalidate(activeFF1BluetoothDeviceProvider);
      await container.read(activeFF1BluetoothDeviceProvider.future);
      await Future<void>.delayed(const Duration(milliseconds: 120));

      deviceService
        ..devices = [deviceA, deviceB]
        ..activeDeviceId = deviceB.deviceId;
      container.invalidate(activeFF1BluetoothDeviceProvider);
      await container.read(activeFF1BluetoothDeviceProvider.future);
      await Future<void>.delayed(const Duration(milliseconds: 120));

      expect(versionService.deviceVersions, contains('1.0.0'));
      expect(versionService.deviceVersions.last, '2.0.0');
    },
  );

  test(
    'auto-connect version check does not reuse previous device status',
    () async {
      await ensureDotEnvLoaded();

      final deviceService = MockFF1BluetoothDeviceService();
      final wifiControl = FakeWifiControl();
      final versionService = _RecordingVersionService();
      const deviceA = FF1Device(
        name: 'FF1-A',
        remoteId: 'remote-a',
        deviceId: 'device-a',
        topicId: 'topic-a',
        branchName: 'main',
      );
      const deviceB = FF1Device(
        name: 'FF1-B',
        remoteId: 'remote-b',
        deviceId: 'device-b',
        topicId: 'topic-b',
        branchName: 'main',
      );

      final container = ProviderContainer.test(
        overrides: [
          ff1BluetoothDeviceServiceProvider.overrideWithValue(deviceService),
          ff1WifiControlProvider.overrideWithValue(wifiControl),
          ff1WifiConnectionProvider.overrideWith(
            FF1WifiConnectionNotifier.new,
          ),
          versionServiceProvider.overrideWithValue(versionService),
        ],
      );
      addTearDown(container.dispose);

      container.listen(
        ff1AutoConnectWatcherProvider,
        (_, _) {},
      );

      deviceService
        ..devices = [deviceA]
        ..activeDeviceId = deviceA.deviceId;
      container.invalidate(activeFF1BluetoothDeviceProvider);
      await container.read(activeFF1BluetoothDeviceProvider.future);
      await Future<void>.delayed(const Duration(milliseconds: 120));

      expect(
        versionService.deviceVersions,
        isEmpty,
        reason:
            'Fresh status timeout should defer, not immediately complete, '
            'the device version check',
      );

      wifiControl.emitDeviceStatus(
        const FF1DeviceStatus(latestVersion: '1.0.0'),
      );
      await Future<void>.delayed(const Duration(milliseconds: 120));

      expect(versionService.deviceVersions, ['1.0.0']);

      deviceService
        ..devices = [deviceA, deviceB]
        ..activeDeviceId = deviceB.deviceId;
      container.invalidate(activeFF1BluetoothDeviceProvider);
      await container.read(activeFF1BluetoothDeviceProvider.future);
      await Future<void>.delayed(const Duration(milliseconds: 120));

      expect(
        versionService.deviceVersions,
        ['1.0.0'],
        reason:
            'Switching to device B must not reuse device A status before '
            'device B emits a fresh status',
      );

      wifiControl.emitDeviceStatus(
        const FF1DeviceStatus(latestVersion: '2.0.0'),
      );
      await Future<void>.delayed(const Duration(milliseconds: 120));

      expect(versionService.deviceVersions, ['1.0.0', '2.0.0']);
    },
  );

  test(
    'auto-connect version check waits for later fresh status with '
    'device version',
    () async {
      await ensureDotEnvLoaded();

      final deviceService = MockFF1BluetoothDeviceService();
      final wifiControl = FakeWifiControl();
      final versionService = _RecordingVersionService();
      const device = FF1Device(
        name: 'FF1-A',
        remoteId: 'remote-a',
        deviceId: 'device-a',
        topicId: 'topic-a',
        branchName: 'main',
      );

      final container = ProviderContainer.test(
        overrides: [
          ff1BluetoothDeviceServiceProvider.overrideWithValue(deviceService),
          ff1WifiControlProvider.overrideWithValue(wifiControl),
          ff1WifiConnectionProvider.overrideWith(
            FF1WifiConnectionNotifier.new,
          ),
          versionServiceProvider.overrideWithValue(versionService),
        ],
      );
      addTearDown(container.dispose);

      container.listen(
        ff1AutoConnectWatcherProvider,
        (_, _) {},
      );

      deviceService
        ..devices = [device]
        ..activeDeviceId = device.deviceId;
      container.invalidate(activeFF1BluetoothDeviceProvider);
      await container.read(activeFF1BluetoothDeviceProvider.future);
      await Future<void>.delayed(const Duration(milliseconds: 120));

      wifiControl.emitDeviceStatus(const FF1DeviceStatus());
      await Future<void>.delayed(const Duration(milliseconds: 120));

      expect(versionService.deviceVersions, isEmpty);

      wifiControl.emitDeviceStatus(
        const FF1DeviceStatus(latestVersion: '2.0.0'),
      );
      await Future<void>.delayed(const Duration(milliseconds: 120));

      expect(versionService.deviceVersions, ['2.0.0']);
    },
  );
  test(
    'ff1AutoConnectWatcherProvider disconnects the old device before switching',
    () async {
      await ensureDotEnvLoaded();

      final deviceService = MockFF1BluetoothDeviceService();
      final wifiControl = FakeWifiControl();
      const deviceA = FF1Device(
        name: 'FF1 A',
        remoteId: 'remote-a',
        deviceId: 'device-a',
        topicId: 'topic-a',
      );
      const deviceB = FF1Device(
        name: 'FF1 B',
        remoteId: 'remote-b',
        deviceId: 'device-b',
        topicId: 'topic-b',
      );

      final container = ProviderContainer.test(
        overrides: [
          ff1BluetoothDeviceServiceProvider.overrideWithValue(deviceService),
          ff1WifiControlProvider.overrideWithValue(wifiControl),
          ff1WifiConnectionProvider.overrideWith(
            FF1WifiConnectionNotifier.new,
          ),
        ],
      );
      addTearDown(container.dispose);

      deviceService
        ..devices = [deviceA]
        ..activeDeviceId = deviceA.deviceId;

      container.listen(
        ff1AutoConnectWatcherProvider,
        (previous, next) {},
      );

      await container.read(activeFF1BluetoothDeviceProvider.future);
      await Future<void>.delayed(const Duration(milliseconds: 200));

      expect(wifiControl.connectCalled, isTrue);
      expect(wifiControl.lastConnectedDevice?.deviceId, deviceA.deviceId);
      expect(wifiControl.disconnectCalled, isFalse);

      deviceService
        ..devices = [deviceA, deviceB]
        ..activeDeviceId = deviceB.deviceId;
      container.invalidate(activeFF1BluetoothDeviceProvider);

      await container.read(activeFF1BluetoothDeviceProvider.future);
      await Future<void>.delayed(const Duration(milliseconds: 200));

      expect(wifiControl.disconnectCalled, isTrue);
      expect(wifiControl.lastConnectedDevice?.deviceId, deviceB.deviceId);
    },
  );

  test(
    'ff1AutoConnectWatcherProvider still connects next device '
    'when disconnect fails',
    () async {
      await ensureDotEnvLoaded();

      final deviceService = MockFF1BluetoothDeviceService();
      final wifiControl = FakeWifiControl()..disconnectShouldThrow = true;
      const deviceA = FF1Device(
        name: 'FF1 A',
        remoteId: 'remote-a',
        deviceId: 'device-a',
        topicId: 'topic-a',
      );
      const deviceB = FF1Device(
        name: 'FF1 B',
        remoteId: 'remote-b',
        deviceId: 'device-b',
        topicId: 'topic-b',
      );

      final container = ProviderContainer.test(
        overrides: [
          ff1BluetoothDeviceServiceProvider.overrideWithValue(deviceService),
          ff1WifiControlProvider.overrideWithValue(wifiControl),
          ff1WifiConnectionProvider.overrideWith(
            FF1WifiConnectionNotifier.new,
          ),
        ],
      );
      addTearDown(container.dispose);

      deviceService
        ..devices = [deviceA]
        ..activeDeviceId = deviceA.deviceId;

      container.listen(
        ff1AutoConnectWatcherProvider,
        (previous, next) {},
      );

      await container.read(activeFF1BluetoothDeviceProvider.future);
      await Future<void>.delayed(const Duration(milliseconds: 200));

      expect(wifiControl.lastConnectedDevice?.deviceId, deviceA.deviceId);

      deviceService
        ..devices = [deviceA, deviceB]
        ..activeDeviceId = deviceB.deviceId;
      container.invalidate(activeFF1BluetoothDeviceProvider);

      await container.read(activeFF1BluetoothDeviceProvider.future);
      await Future<void>.delayed(const Duration(milliseconds: 200));

      expect(wifiControl.disconnectCalled, isTrue);
      expect(
        wifiControl.lastConnectedDevice?.deviceId,
        deviceB.deviceId,
        reason:
            'Switch flow must still connect the new device on disconnect '
            'error.',
      );
    },
  );

  test(
    'ff1AutoConnectWatcherProvider disconnects in-flight connect '
    'before switching',
    () async {
      await ensureDotEnvLoaded();

      final deviceService = MockFF1BluetoothDeviceService();
      final wifiControl = _BlockingWifiControl();
      const deviceA = FF1Device(
        name: 'FF1 A',
        remoteId: 'remote-a',
        deviceId: 'device-a',
        topicId: 'topic-a',
      );
      const deviceB = FF1Device(
        name: 'FF1 B',
        remoteId: 'remote-b',
        deviceId: 'device-b',
        topicId: 'topic-b',
      );

      final container = ProviderContainer.test(
        overrides: [
          ff1BluetoothDeviceServiceProvider.overrideWithValue(deviceService),
          ff1WifiControlProvider.overrideWithValue(wifiControl),
          ff1WifiConnectionProvider.overrideWith(
            FF1WifiConnectionNotifier.new,
          ),
          versionServiceProvider.overrideWithValue(
            _fakeCompatibleVersionService(),
          ),
        ],
      );
      addTearDown(container.dispose);

      deviceService
        ..devices = [deviceA, deviceB]
        ..activeDeviceId = deviceA.deviceId;

      container.listen(
        ff1AutoConnectWatcherProvider,
        (previous, next) {},
      );

      await container.read(activeFF1BluetoothDeviceProvider.future);
      await wifiControl.firstConnectStarted.future;
      expect(wifiControl.connectCalls, 1);
      expect(wifiControl.startedDevices.single.deviceId, deviceA.deviceId);

      deviceService.activeDeviceId = deviceB.deviceId;
      container.invalidate(activeFF1BluetoothDeviceProvider);

      await container.read(activeFF1BluetoothDeviceProvider.future);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(wifiControl.disconnectCalls, 1);
      expect(wifiControl.connectCalls, greaterThanOrEqualTo(2));
      expect(
        wifiControl.startedDevices.last.deviceId,
        deviceB.deviceId,
        reason:
            'Switch flow must start the second connect even while the first '
            'connect is still pending.',
      );

      wifiControl.completeConnect();
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(wifiControl.lastConnectedDevice?.deviceId, deviceB.deviceId);
      expect(
        container.read(ff1WifiConnectionProvider).device?.deviceId,
        deviceB.deviceId,
        reason:
            'The notifier should ignore the stale in-flight connect and keep '
            'the later device selected.',
      );
    },
  );

}

class _RecordingVersionService extends VersionService {
  _RecordingVersionService()
    : super(
        pubDocApi: _FakePubDocApi(),
        navigatorKey: null,
        platformOverride: 'ios',
        packageInfoLoader: () async => PackageInfo(
          appName: 'app',
          packageName: 'pkg',
          version: '10.0.0',
          buildNumber: '1',
        ),
      );

  final List<String> deviceVersions = <String>[];

  @override
  Future<VersionCompatibilityResult> checkDeviceVersionCompatibility({
    required String branchName,
    required String deviceVersion,
    bool requiredDeviceUpdate = false,
  }) async {
    deviceVersions.add(deviceVersion);
    return VersionCompatibilityResult.compatible;
  }
}

class _AutoStatusWifiControl extends FakeWifiControl {
  _AutoStatusWifiControl({
    required this.statusesByDeviceId,
  });

  final Map<String, FF1DeviceStatus> statusesByDeviceId;

  @override
  Future<void> connect({
    required FF1Device device,
    required String userId,
    required String apiKey,
  }) async {
    await super.connect(device: device, userId: userId, apiKey: apiKey);
    final status = statusesByDeviceId[device.deviceId];
    if (status != null) {
      emitDeviceStatus(status);
    }
  }
}

VersionService _fakeCompatibleVersionService() {
  return VersionService(
    pubDocApi: _FakePubDocApi(),
    platformOverride: 'ios',
    packageInfoLoader: () async => PackageInfo(
      appName: 'app',
      packageName: 'pkg',
      version: '10.0.0',
      buildNumber: '1',
    ),
  );
}

class _FakePubDocApi implements PubDocApi {
  @override
  Future<Map<String, dynamic>> getVersionCompatibility() async {
    return <String, dynamic>{
      'release': <String, dynamic>{
        '1.0.0': <String, dynamic>{
          'min_ios_version': '0.0.0(0)',
          'max_ios_version': '99.0.0(0)',
        },
      },
    };
  }

  @override
  Future<String> getAppleModelIdentifier() async => '';

  @override
  Future<String> getVersionContent() async => '';
}

class _BlockingWifiControl extends FF1WifiControl {
  _BlockingWifiControl()
    : super(
        transport: _NoopWifiTransport(),
        restClient: null,
      );

  final Completer<void> firstConnectStarted = Completer<void>();
  final Completer<void> _connectGate = Completer<void>();
  int connectCalls = 0;
  int disconnectCalls = 0;
  final List<FF1Device> startedDevices = <FF1Device>[];
  FF1Device? lastConnectedDevice;

  void completeConnect() {
    if (!_connectGate.isCompleted) {
      _connectGate.complete();
    }
  }

  @override
  Future<void> connect({
    required FF1Device device,
    required String userId,
    required String apiKey,
  }) async {
    connectCalls++;
    startedDevices.add(device);
    lastConnectedDevice = device;
    if (!firstConnectStarted.isCompleted) {
      firstConnectStarted.complete();
    }
    await _connectGate.future;
  }

  @override
  Future<void> disconnect() async {
    disconnectCalls++;
  }
}

class _NoopWifiTransport implements FF1WifiTransport {
  @override
  Stream<bool> get connectionStateStream => const Stream<bool>.empty();

  @override
  Stream<FF1WifiTransportError> get errorStream =>
      const Stream<FF1WifiTransportError>.empty();

  @override
  bool get isConnected => false;

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
