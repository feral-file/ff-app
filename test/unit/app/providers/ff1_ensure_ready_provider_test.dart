import 'dart:async';

import 'package:app/app/providers/ff1_ensure_ready_provider.dart';
import 'package:app/app/providers/ff1_providers.dart';
import 'package:app/app/providers/version_provider.dart';
import 'package:app/domain/models/ff1_device_info.dart';
import 'package:app/domain/models/ff1_error.dart';
import 'package:app/infra/api/pubdoc_api.dart';
import 'package:app/infra/ff1/ble_protocol/ff1_ble_commands.dart';
import 'package:app/infra/ff1/ble_protocol/ff1_ble_protocol.dart';
import 'package:app/infra/ff1/ble_transport/ff1_ble_transport.dart';
import 'package:app/infra/services/version_service.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';

void main() {
  test('Flow3 returns needsWiFi when internet is not connected', () async {
    final container = ProviderContainer.test(
      overrides: [
        ff1ControlProvider.overrideWithValue(_FakeControl()),
        versionServiceProvider.overrideWithValue(_fakeCompatibleVersionService()),
      ],
    );
    addTearDown(container.dispose);

    const info = FF1DeviceInfo(
      deviceId: 'FF1-123',
      topicId: '',
      isConnectedToInternet: false,
      branchName: 'release',
      version: '1.0.0',
    );

    final result = await container.read(
      ff1EnsureReadyProvider(
        FF1EnsureReadyParams(
          blDevice: BluetoothDevice.fromId('00:11'),
          deviceInfo: info,
          shouldContinue: () => true,
        ),
      ).future,
    );

    expect(result, isNotNull);
    expect(result!.isConnectedToInternet, isFalse);
    expect(result.portalIsSet, isFalse);
  });

  test('Flow3 calls keepWifi when internet is connected but topicId is missing',
      () async {
    final control = _FakeControl()..keepWifiTopicId = 'topic-keep';
    final container = ProviderContainer.test(
      overrides: [
        ff1ControlProvider.overrideWithValue(control),
        versionServiceProvider.overrideWithValue(_fakeCompatibleVersionService()),
      ],
    );
    addTearDown(container.dispose);

    const info = FF1DeviceInfo(
      deviceId: 'FF1-123',
      topicId: '',
      isConnectedToInternet: true,
      branchName: 'release',
      version: '1.0.0',
    );

    final result = await container.read(
      ff1EnsureReadyProvider(
        FF1EnsureReadyParams(
          blDevice: BluetoothDevice.fromId('00:11'),
          deviceInfo: info,
          shouldContinue: () => true,
        ),
      ).future,
    );

    expect(result, isNotNull);
    expect(result!.isConnectedToInternet, isTrue);
    expect(result.portalIsSet, isFalse);
    expect(result.ff1Device.topicId, 'topic-keep');
    expect(control.keepWifiCalls, 1);
  });

  test('Flow3 throws FF1ConnectionCancelledError when shouldContinue is false',
      () async {
    final control = _FakeControl()..keepWifiTopicId = 'topic-keep';
    final container = ProviderContainer.test(
      overrides: [
        ff1ControlProvider.overrideWithValue(control),
        versionServiceProvider.overrideWithValue(_fakeCompatibleVersionService()),
      ],
    );
    addTearDown(container.dispose);

    const info = FF1DeviceInfo(
      deviceId: 'FF1-123',
      topicId: '',
      isConnectedToInternet: true,
      branchName: 'release',
      version: '1.0.0',
    );

    final provider = ff1EnsureReadyProvider(
      FF1EnsureReadyParams(
        blDevice: BluetoothDevice.fromId('00:11'),
        deviceInfo: info,
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

VersionService _fakeCompatibleVersionService() {
  return VersionService(
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
}

class _FakePubDocApi implements PubDocApi {
  @override
  Future<Map<String, dynamic>> getVersionCompatibility() async {
    // Allow any app version to be compatible for this test branch/version.
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

class _FakeControl extends FF1BleControl {
  _FakeControl() : super(transport: _NoopBleTransport());

  int keepWifiCalls = 0;
  String keepWifiTopicId = '';

  @override
  Future<String> keepWifi({required BluetoothDevice blDevice}) async {
    keepWifiCalls++;
    return keepWifiTopicId;
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

