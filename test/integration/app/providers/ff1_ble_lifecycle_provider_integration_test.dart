import 'dart:async';

import 'package:app/app/providers/ff1_ble_lifecycle_provider.dart';
import 'package:app/app/providers/ff1_bluetooth_device_providers.dart';
import 'package:app/app/providers/ff1_providers.dart';
import 'package:app/app/routing/routes.dart';
import 'package:app/domain/models/ff1_device.dart';
import 'package:app/infra/ff1/ble_protocol/ff1_ble_commands.dart';
import 'package:app/infra/ff1/ble_protocol/ff1_ble_protocol.dart';
import 'package:app/infra/ff1/ble_transport/ff1_ble_transport.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import '../../../unit/app/providers/provider_test_helpers.dart';

void main() {
  test(
    'lifecycle coordinator closes BLE on home then reconnects on resume',
    () async {
      const activeDevice = FF1Device(
        name: 'FF1_DEVICE',
        remoteId: '00:11:22:33:44:55',
        deviceId: 'DEVICE_1',
        topicId: 'topic_1',
      );

      final transport = _FakeIntegrationBleTransport();
      final deviceService = MockFF1BluetoothDeviceService()
        ..devices = [activeDevice]
        ..activeId = activeDevice.deviceId;
      final container = ProviderContainer.test(
        overrides: [
          ff1TransportProvider.overrideWithValue(transport),
          ff1BluetoothDeviceServiceProvider.overrideWithValue(deviceService),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(
        ff1BleLifecycleCoordinatorProvider.notifier,
      );

      await notifier.handleRouteChanged(Routes.home);
      await notifier.handleLifecycleChanged(
        AppLifecycleState.resumed,
        routePath: Routes.deviceConfiguration,
      );

      expect(transport.disconnectAllCallCount, 1);
      expect(transport.connectCallCount, 1);
    },
  );
}

class _FakeIntegrationBleTransport implements FF1BleTransport {
  int connectCallCount = 0;
  int disconnectAllCallCount = 0;

  @override
  BluetoothAdapterState get adapterState => BluetoothAdapterState.on;

  @override
  Stream<BluetoothAdapterState> get adapterStateStream =>
      Stream.value(BluetoothAdapterState.on);

  @override
  Future<bool> get isSupported => Future.value(true);

  @override
  Future<void> connect({
    required BluetoothDevice blDevice,
    Duration timeout = const Duration(seconds: 30),
    int maxRetries = 0,
    bool Function()? shouldContinue,
  }) async {
    connectCallCount++;
  }

  @override
  Future<void> disconnect(BluetoothDevice blDevice) async {}

  @override
  Future<void> disconnectAll() async {
    disconnectAllCallCount++;
  }

  @override
  Future<void> scan({
    required FutureOr<bool> Function(List<BluetoothDevice>) onDevice,
    Duration timeout = const Duration(seconds: 30),
  }) async {
    await onDevice(const <BluetoothDevice>[]);
  }

  @override
  Future<BluetoothDevice?> scanForName({
    required String name,
    Duration timeout = const Duration(seconds: 15),
  }) async {
    return null;
  }

  @override
  Future<FF1BleResponse> sendCommand({
    required BluetoothDevice blDevice,
    required FF1BleCommand command,
    required FF1BleRequest request,
    Duration timeout = const Duration(seconds: 10),
  }) async {
    throw UnimplementedError();
  }
}
