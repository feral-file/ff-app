import 'package:app/app/providers/ff1_bluetooth_device_providers.dart';
import 'package:app/app/providers/ff1_connection_providers.dart';
import 'package:app/domain/models/ff1_device.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'provider_test_helpers.dart';

void main() {
  test(
    'ff1 connection providers split connected and disconnected devices',
    () async {
      // Unit test: verifies FF1 device split uses topicId presence for connection status.
      final service = MockFF1BluetoothDeviceService()
        ..devices = const [
          FF1Device(
            name: 'Connected',
            remoteId: 'r1',
            deviceId: 'd1',
            topicId: 'topic',
          ),
          FF1Device(
            name: 'Disconnected',
            remoteId: 'r2',
            deviceId: 'd2',
            topicId: '',
          ),
        ];

      final container = ProviderContainer.test(
        overrides: [
          ff1BluetoothDeviceServiceProvider.overrideWithValue(service),
        ],
      );
      addTearDown(container.dispose);

      final connected = await container.read(
        connectedFF1DevicesProvider.future,
      );
      final disconnected = await container.read(
        disconnectedFF1DevicesProvider.future,
      );

      expect(connected.map((e) => e.deviceId), ['d1']);
      expect(disconnected.map((e) => e.deviceId), ['d2']);
    },
  );
}
