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
import 'provider_test_helpers.dart';

void main() {
  group('FF1BleLifecycleCoordinator', () {
    const activeDevice = FF1Device(
      name: 'FF1_DEVICE',
      remoteId: '00:11:22:33:44:55',
      deviceId: 'DEVICE_1',
      topicId: 'topic_1',
    );

    test('disconnects all sessions when route changes to home', () async {
      final transport = FakeLifecycleBleTransport();
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

      expect(transport.disconnectAllCallCount, 1);
      expect(
        container.read(ff1BleLifecycleCoordinatorProvider).isConnected,
        isFalse,
      );
    });

    test('reconnects active device on resumed away from home', () async {
      final transport = FakeLifecycleBleTransport();
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
      await notifier.handleLifecycleChanged(
        AppLifecycleState.resumed,
        routePath: Routes.deviceConfiguration,
      );

      expect(transport.connectCallCount, 1);
      expect(transport.lastConnectedRemoteId, activeDevice.remoteId);
      expect(
        container.read(ff1BleLifecycleCoordinatorProvider).isConnected,
        isTrue,
      );
    });

    test('does not reconnect on resumed when route is home', () async {
      final transport = FakeLifecycleBleTransport();
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
      await notifier.handleLifecycleChanged(
        AppLifecycleState.resumed,
        routePath: Routes.home,
      );

      expect(transport.connectCallCount, 0);
    });

    test('disconnects all sessions when app moves to background', () async {
      final transport = FakeLifecycleBleTransport();
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
      await notifier.handleLifecycleChanged(
        AppLifecycleState.paused,
        routePath: Routes.deviceConfiguration,
      );

      expect(transport.disconnectAllCallCount, 1);
    });
  });
}

class FakeLifecycleBleTransport implements FF1BleTransport {
  int connectCallCount = 0;
  int disconnectAllCallCount = 0;
  String? lastConnectedRemoteId;

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
    lastConnectedRemoteId = blDevice.remoteId.str;
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
