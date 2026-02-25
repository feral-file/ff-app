import 'package:app/app/providers/ff1_bluetooth_device_providers.dart';
import 'package:app/app/providers/ff1_wifi_providers.dart';
import 'package:app/domain/models/ff1_device.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'provider_test_helpers.dart';

void main() {
  test('ff1 wifi params equality and default notifier state', () {
    // Unit test: verifies FF1 WiFi connect params equality and initial connection state.
    final p1 = FF1WifiConnectParams(
      device: const FF1Device(
        name: 'D',
        remoteId: 'r',
        deviceId: 'id',
        topicId: 'topic',
      ),
      userId: 'u1',
      apiKey: 'k1',
    );
    final p2 = FF1WifiConnectParams(
      device: const FF1Device(
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
      final device = const FF1Device(
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
            () => FF1WifiConnectionNotifier(),
          ),
        ],
      );
      addTearDown(container.dispose);

      // Initially no active device
      deviceService.devices = [];
      deviceService.activeDeviceId = null;

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
      deviceService.devices = [device];
      deviceService.activeDeviceId = device.deviceId;
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
      final device = const FF1Device(
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
            () => FF1WifiConnectionNotifier(),
          ),
        ],
      );
      addTearDown(container.dispose);

      // Start with active device
      deviceService.devices = [device];
      deviceService.activeDeviceId = device.deviceId;

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
}
