import 'dart:async';

import 'package:app/app/providers/connect_ff1_providers.dart';
import 'package:app/app/providers/ff1_bluetooth_device_providers.dart';
import 'package:app/app/providers/ff1_ensure_ready_provider.dart';
import 'package:app/app/providers/ff1_providers.dart';
import 'package:app/domain/models/ff1_device.dart';
import 'package:app/domain/models/ff1_device_info.dart';
import 'package:app/infra/ff1/ble_protocol/ff1_ble_commands.dart';
import 'package:app/infra/ff1/ble_protocol/ff1_ble_protocol.dart';
import 'package:app/infra/ff1/ble_transport/ff1_ble_transport.dart';
import 'package:app/test/unit/app/providers/provider_test_helpers.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('connect emits internet-ready state only after persisting device', () async {
    final blDevice = BluetoothDevice.fromId('00:11:22:33:44:55');
    const info = FF1DeviceInfo(
      deviceId: 'FF1-1',
      topicId: 'topic-1',
      isConnectedToInternet: true,
      branchName: 'release',
      version: '1.0.0',
    );
    const ensured = FF1EnsureReadyResult(
      ff1Device: FF1Device(
        name: 'FF1',
        remoteId: '00:11:22:33:44:55',
        deviceId: 'FF1-1',
        topicId: 'topic-1',
      ),
      portalIsSet: true,
      isConnectedToInternet: true,
    );

    final actions = _BlockingActions();
    final container = ProviderContainer.test(
      overrides: [
        ff1TransportProvider.overrideWithValue(_NoopBleTransport()),
        ff1ControlProvider.overrideWith((ref) => FF1BleControl(transport: ref.read(ff1TransportProvider))),
        ff1EnsureReadyProvider.overrideWith((ref, params) async => ensured),
        ff1BluetoothDeviceActionsProvider.overrideWith(() => actions),
      ],
    );
    addTearDown(container.dispose);

    final notifier = container.read(connectFF1Provider.notifier);
    final future = notifier.connectBle(blDevice, ff1DeviceInfo: info);

    // Give the notifier a tick to progress to the persistence await.
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(
      container.read(connectFF1Provider).value,
      isNot(isA<ConnectFF1Connected>()),
    );

    actions.complete();
    await future;

    final state = container.read(connectFF1Provider).value;
    expect(state, isA<ConnectFF1Connected>());
    final connected = state as ConnectFF1Connected;
    expect(connected.isConnectedToInternet, isTrue);
    expect(actions.addDeviceCalled, isTrue);
  });

  test('addDevice does not re-promote an already active device', () async {
    final service = _CountingMockFF1BluetoothDeviceService()
      ..devices = const [
        FF1Device(
          name: 'FF1',
          remoteId: '00:11:22:33:44:55',
          deviceId: 'FF1-1',
          topicId: 'topic-1',
        ),
      ]
      ..activeId = 'FF1-1'
      ..activeDeviceId = 'FF1-1';

    final container = ProviderContainer.test(
      overrides: [
        ff1BluetoothDeviceServiceProvider.overrideWithValue(service),
      ],
    );
    addTearDown(container.dispose);

    await container.read(ff1BluetoothDeviceActionsProvider.notifier).addDevice(
          const FF1Device(
            name: 'FF1',
            remoteId: '00:11:22:33:44:55',
            deviceId: 'FF1-1',
            topicId: 'topic-1',
          ),
        );

    expect(service.activeId, 'FF1-1');
    expect(service.activeDeviceId, 'FF1-1');
    expect(service.setActiveDeviceCalls, 0);
  });
}

class _BlockingActions extends FF1BluetoothDeviceActionsNotifier {
  final Completer<void> _completer = Completer<void>();
  bool addDeviceCalled = false;

  @override
  void build() {}

  void complete() {
    if (!_completer.isCompleted) {
      _completer.complete();
    }
  }

  @override
  Future<void> addDevice(FF1Device device) async {
    addDeviceCalled = true;
    await _completer.future;
  }
}

class _CountingMockFF1BluetoothDeviceService
    extends MockFF1BluetoothDeviceService {
  int setActiveDeviceCalls = 0;

  @override
  Future<void> setActiveDevice(String deviceId) async {
    setActiveDeviceCalls += 1;
    await super.setActiveDevice(deviceId);
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
