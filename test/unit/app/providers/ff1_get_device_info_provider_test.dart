import 'dart:async';

import 'package:app/app/providers/ff1_get_device_info_provider.dart';
import 'package:app/app/providers/ff1_providers.dart';
import 'package:app/domain/models/ff1_device_info.dart';
import 'package:app/domain/models/ff1_error.dart';
import 'package:app/infra/ff1/ble_protocol/ff1_ble_commands.dart';
import 'package:app/infra/ff1/ble_protocol/ff1_ble_protocol.dart';
import 'package:app/infra/ff1/ble_transport/ff1_ble_transport.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Flow2 returns deeplink info without BLE calls', () async {
    final control = _FakeControl(infoEncoded: 'IGNORED');
    final container = ProviderContainer.test(
      overrides: [
        ff1ControlProvider.overrideWithValue(control),
      ],
    );
    addTearDown(container.dispose);

    const info = FF1DeviceInfo(
      deviceId: 'FF1-123',
      topicId: 'topic-123',
      isConnectedToInternet: true,
      branchName: 'release',
      version: '1.0.0',
    );

    final result = await container.read(
      ff1GetDeviceInfoProvider(
        FF1GetDeviceInfoParams(
          blDevice: BluetoothDevice.fromId('00:11'),
          deeplinkInfo: info,
          shouldContinue: () => true,
        ),
      ).future,
    );

    expect(result.deviceId, 'FF1-123');
    expect(control.getInfoCalls, 0);
    expect(control.waitUntilReadyCalls, 0);
  });

  test('Flow2 fetches device info via get_info when deeplink is absent', () async {
    final control = _FakeControl(
      infoEncoded: 'FF1-ABC|topic-xyz|true|release|1.0.0',
    );
    final container = ProviderContainer.test(
      overrides: [
        ff1ControlProvider.overrideWithValue(control),
      ],
    );
    addTearDown(container.dispose);

    final result = await container.read(
      ff1GetDeviceInfoProvider(
        FF1GetDeviceInfoParams(
          blDevice: BluetoothDevice.fromId('00:11'),
          deeplinkInfo: null,
          shouldContinue: () => true,
        ),
      ).future,
    );

    expect(result.deviceId, 'FF1-ABC');
    expect(result.topicId, 'topic-xyz');
    expect(result.isConnectedToInternet, isTrue);
    expect(control.waitUntilReadyCalls, greaterThanOrEqualTo(1));
    expect(control.getInfoCalls, greaterThanOrEqualTo(1));
  });

  test('Flow2 throws FF1ConnectionCancelledError when shouldContinue is false',
      () async {
    final control = _FakeControl(
      infoEncoded: 'FF1-ABC|topic-xyz|true|release|1.0.0',
    );
    final container = ProviderContainer.test(
      overrides: [
        ff1ControlProvider.overrideWithValue(control),
      ],
    );
    addTearDown(container.dispose);

    final provider = ff1GetDeviceInfoProvider(
      FF1GetDeviceInfoParams(
        blDevice: BluetoothDevice.fromId('00:11'),
        deeplinkInfo: null,
        shouldContinue: () => false,
      ),
    );
    final sub = container.listen(provider, (_, __) {}, fireImmediately: true);

    await Future<void>.delayed(Duration.zero);
    final value = container.read(provider);
    expect(value.hasError, isTrue);
    expect(value.error, isA<FF1ConnectionCancelledError>());
    sub.close();
  });
}

class _FakeControl extends FF1BleControl {
  _FakeControl({required this.infoEncoded})
      : super(transport: _NoopBleTransport());

  final String infoEncoded;
  int getInfoCalls = 0;
  int waitUntilReadyCalls = 0;

  @override
  Future<void> waitUntilReady({
    required BluetoothDevice blDevice,
    Duration timeout = const Duration(seconds: 20),
  }) async {
    waitUntilReadyCalls++;
  }

  @override
  Future<String> getInfo({
    required BluetoothDevice blDevice,
  }) async {
    getInfoCalls++;
    return infoEncoded;
  }
}

class _NoopBleTransport implements FF1BleTransport {
  @override
  BluetoothAdapterState get adapterState => BluetoothAdapterState.on;

  @override
  Stream<BluetoothAdapterState> get adapterStateStream =>
      const Stream<BluetoothAdapterState>.empty();

  @override
  Future<void> connect({
    required BluetoothDevice blDevice,
    Duration timeout = const Duration(seconds: 30),
    int maxRetries = 0,
    bool Function()? shouldContinue,
  }) async {}

  @override
  Future<void> disconnect(BluetoothDevice device) async {}

  @override
  Future<bool> get isSupported async => true;

  @override
  Future<void> scan({
    required FutureOr<bool> Function(List<BluetoothDevice> devices) onDevice,
    Duration timeout = const Duration(seconds: 30),
  }) async {}

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
    return const FF1BleResponse(topic: 'noop', errorCode: 0, data: <String>[]);
  }

  @override
  Future<void> waitUntilReady({
    required BluetoothDevice blDevice,
    Duration timeout = const Duration(seconds: 20),
  }) async {}

}

