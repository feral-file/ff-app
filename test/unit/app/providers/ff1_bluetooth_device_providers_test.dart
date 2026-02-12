import 'package:app/app/providers/ff1_bluetooth_device_providers.dart';
import 'package:app/domain/models/ff1_device.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'provider_test_helpers.dart';

void main() {
  test(
    'ff1 bluetooth providers read and mutate through service override',
    () async {
      // Unit test: verifies FF1 bluetooth device providers delegate to injected device service.
      final service = MockFF1BluetoothDeviceService();
      final device = const FF1Device(
        name: 'FF1',
        remoteId: 'remote-1',
        deviceId: 'device-1',
        topicId: '',
      );
      service.devices = [device];

      final container = ProviderContainer.test(
        overrides: [
          ff1BluetoothDeviceServiceProvider.overrideWithValue(service),
        ],
      );
      addTearDown(container.dispose);

      final devices = await container.read(
        allFF1BluetoothDevicesProvider.future,
      );
      expect(devices.length, 1);

      await container.read(addFF1BluetoothDeviceProvider(device).future);
      final active = await container.read(
        activeFF1BluetoothDeviceProvider.future,
      );
      expect(active?.deviceId, 'device-1');
    },
  );
}
