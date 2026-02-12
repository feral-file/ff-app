import 'dart:async';

import 'package:app/app/providers/ff1_providers.dart';
import 'package:app/domain/models/ff1_error.dart';
import 'package:app/infra/ff1/ble_protocol/ff1_ble_commands.dart';
import 'package:app/infra/ff1/ble_protocol/ff1_ble_protocol.dart';
import 'package:app/infra/ff1/ble_transport/ff1_ble_transport.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FF1 Providers', () {
    group('FF1BleControl.sendWifiCredentials', () {
      test('returns topicId on success', () async {
        final fakeTransport = FakeFF1BleTransport(
          sendCommandResponse: const FF1BleResponse(
            topic: 'test',
            errorCode: 0,
            data: ['topic_12345'],
          ),
        );

        final container = ProviderContainer(
          overrides: [
            ff1TransportProvider.overrideWithValue(fakeTransport),
          ],
        );
        addTearDown(container.dispose);

        final control = container.read(ff1ControlProvider);
        final blDevice = BluetoothDevice.fromId('00:11:22:33:44:55');

        final topicId = await control.sendWifiCredentials(
          blDevice: blDevice,
          ssid: 'TestNetwork',
          password: 'password123',
        );

        expect(topicId, 'topic_12345');
        expect(fakeTransport.lastCommand, FF1BleCommand.sendWifiCredentials);
      });

      test('throws error on wrong password', () async {
        final fakeTransport = FakeFF1BleTransport(
          sendCommandResponse: const FF1BleResponse(
            topic: 'test',
            errorCode: 1, // Wrong password
            data: [],
          ),
        );

        final container = ProviderContainer(
          overrides: [
            ff1TransportProvider.overrideWithValue(fakeTransport),
          ],
        );
        addTearDown(container.dispose);

        final control = container.read(ff1ControlProvider);
        final blDevice = BluetoothDevice.fromId('00:11:22:33:44:55');

        expect(
          () => control.sendWifiCredentials(
            blDevice: blDevice,
            ssid: 'TestNetwork',
            password: 'wrongpass',
          ),
          throwsA(isA<WrongWifiPasswordError>()),
        );
      });

      test('throws error when topicId is missing', () async {
        final fakeTransport = FakeFF1BleTransport(
          sendCommandResponse: const FF1BleResponse(
            topic: 'test',
            errorCode: 0,
            data: [], // No topicId!
          ),
        );

        final container = ProviderContainer(
          overrides: [
            ff1TransportProvider.overrideWithValue(fakeTransport),
          ],
        );
        addTearDown(container.dispose);

        final control = container.read(ff1ControlProvider);
        final blDevice = BluetoothDevice.fromId('00:11:22:33:44:55');

        expect(
          () => control.sendWifiCredentials(
            blDevice: blDevice,
            ssid: 'TestNetwork',
            password: 'password',
          ),
          throwsA(isA<FF1BluetoothError>()),
        );
      });
    });

    group('FF1BleControl.scanWifi', () {
      test('returns list of SSIDs', () async {
        final fakeTransport = FakeFF1BleTransport(
          sendCommandResponse: const FF1BleResponse(
            topic: 'scan',
            errorCode: 0,
            data: ['Network1', 'Network2', 'Network3'],
          ),
        );

        final container = ProviderContainer(
          overrides: [
            ff1TransportProvider.overrideWithValue(fakeTransport),
          ],
        );
        addTearDown(container.dispose);

        final control = container.read(ff1ControlProvider);
        final blDevice = BluetoothDevice.fromId('00:11:22:33:44:55');

        final ssids = await control.scanWifi(blDevice: blDevice);

        expect(ssids, ['Network1', 'Network2', 'Network3']);
        expect(fakeTransport.lastCommand, FF1BleCommand.scanWifi);
      });

      test('returns empty list when no networks found', () async {
        final fakeTransport = FakeFF1BleTransport(
          sendCommandResponse: const FF1BleResponse(
            topic: 'scan',
            errorCode: 0,
            data: [],
          ),
        );

        final container = ProviderContainer(
          overrides: [
            ff1TransportProvider.overrideWithValue(fakeTransport),
          ],
        );
        addTearDown(container.dispose);

        final control = container.read(ff1ControlProvider);
        final blDevice = BluetoothDevice.fromId('00:11:22:33:44:55');

        final ssids = await control.scanWifi(blDevice: blDevice);

        expect(ssids, isEmpty);
      });
    });

    group('FF1BleControl.keepWifi', () {
      test('returns topicId on success', () async {
        final fakeTransport = FakeFF1BleTransport(
          sendCommandResponse: const FF1BleResponse(
            topic: 'keep',
            errorCode: 0,
            data: ['topic_existing'],
          ),
        );

        final container = ProviderContainer(
          overrides: [
            ff1TransportProvider.overrideWithValue(fakeTransport),
          ],
        );
        addTearDown(container.dispose);

        final control = container.read(ff1ControlProvider);
        final blDevice = BluetoothDevice.fromId('00:11:22:33:44:55');

        final topicId = await control.keepWifi(blDevice: blDevice);

        expect(topicId, 'topic_existing');
        expect(fakeTransport.lastCommand, FF1BleCommand.keepWifi);
      });

      test('throws WifiRequiredError when not connected', () async {
        final fakeTransport = FakeFF1BleTransport(
          sendCommandResponse: const FF1BleResponse(
            topic: 'keep',
            errorCode: 4, // WiFi required
            data: [],
          ),
        );

        final container = ProviderContainer(
          overrides: [
            ff1TransportProvider.overrideWithValue(fakeTransport),
          ],
        );
        addTearDown(container.dispose);

        final control = container.read(ff1ControlProvider);
        final blDevice = BluetoothDevice.fromId('00:11:22:33:44:55');

        expect(
          () => control.keepWifi(blDevice: blDevice),
          throwsA(isA<WifiRequiredError>()),
        );
      });
    });

    group('FF1BleControl.getInfo', () {
      test('returns device info string', () async {
        final fakeTransport = FakeFF1BleTransport(
          sendCommandResponse: const FF1BleResponse(
            topic: 'info',
            errorCode: 0,
            data: ['{"version":"1.0.0","deviceId":"FF1_12345"}'],
          ),
        );

        final container = ProviderContainer(
          overrides: [
            ff1TransportProvider.overrideWithValue(fakeTransport),
          ],
        );
        addTearDown(container.dispose);

        final control = container.read(ff1ControlProvider);
        final blDevice = BluetoothDevice.fromId('00:11:22:33:44:55');

        final info = await control.getInfo(blDevice: blDevice);

        expect(info, contains('version'));
        expect(info, contains('deviceId'));
      });

      test('retries on failure (via Riverpod)', () async {
        var callCount = 0;
        final fakeTransport = FakeFF1BleTransport(
          sendCommandCallback: (device, command, request, timeout) {
            callCount++;
            if (callCount < 2) {
              throw Exception('Network error');
            }
            return Future.value(
              const FF1BleResponse(
                topic: 'info',
                errorCode: 0,
                data: ['success'],
              ),
            );
          },
        );

        final container = ProviderContainer(
          overrides: [
            ff1TransportProvider.overrideWithValue(fakeTransport),
          ],
        );
        addTearDown(container.dispose);

        final blDevice = BluetoothDevice.fromId('00:11:22:33:44:55');

        final provider = ff1BleSendCommandProvider(
          FF1BleCommandParams(
            blDevice: blDevice,
            command: FF1BleCommand.getInfo,
            request: const GetInfoRequest(),
          ),
        );

        // Keep provider alive during test to prevent auto-dispose during retry
        final sub = container.listen(provider, (_, __) {});
        addTearDown(sub.close);

        // Use provider with automatic retry
        final response = await container.read(provider.future);

        expect(response.data[0], 'success');
        expect(
          callCount,
          2,
        ); // Failed once, succeeded on second attempt (Riverpod retry)
      });
    });

    group('FF1ScanNotifier', () {
      test('starts scan and updates state', () async {
        final fakeTransport = FakeFF1BleTransport(
          scanDevices: [
            BluetoothDevice.fromId('00:11:22:33:44:55'),
            BluetoothDevice.fromId('AA:BB:CC:DD:EE:FF'),
          ],
        );

        final container = ProviderContainer(
          overrides: [
            ff1TransportProvider.overrideWithValue(fakeTransport),
          ],
        );
        addTearDown(container.dispose);

        final notifier = container.read(ff1ScanProvider.notifier);

        expect(container.read(ff1ScanProvider).isScanning, false);
        expect(container.read(ff1ScanProvider).devices, isEmpty);

        await notifier.startScan(timeout: const Duration(seconds: 1));

        expect(container.read(ff1ScanProvider).isScanning, false);
        expect(container.read(ff1ScanProvider).devices.length, 2);
      });

      test('handles scan error', () async {
        final fakeTransport = FakeFF1BleTransport(
          scanError: Exception('Bluetooth not enabled'),
        );

        final container = ProviderContainer(
          overrides: [
            ff1TransportProvider.overrideWithValue(fakeTransport),
          ],
        );
        addTearDown(container.dispose);

        final notifier = container.read(ff1ScanProvider.notifier);

        await notifier.startScan();

        expect(container.read(ff1ScanProvider).isScanning, false);
        expect(container.read(ff1ScanProvider).error, isNotNull);
      });

      test('clears devices', () {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        final notifier = container.read(ff1ScanProvider.notifier);

        // Initialize first
        container.read(ff1ScanProvider);

        // Manually set state with devices using internal API
        notifier.state = FF1ScanState(
          isScanning: false,
          devices: [BluetoothDevice.fromId('00:11:22:33:44:55')],
        );

        expect(container.read(ff1ScanProvider).devices.length, 1);

        notifier.clear();

        expect(container.read(ff1ScanProvider).devices, isEmpty);
      });
    });
  });
}

// ============================================================================
// Fake Transport for testing
// ============================================================================

class FakeFF1BleTransport implements FF1BleTransport {
  FakeFF1BleTransport({
    this.sendCommandResponse,
    this.sendCommandCallback,
    this.scanDevices = const [],
    this.scanError,
  });

  final FF1BleResponse? sendCommandResponse;
  final Future<FF1BleResponse> Function(
    BluetoothDevice device,
    FF1BleCommand command,
    FF1BleRequest request,
    Duration timeout,
  )?
  sendCommandCallback;
  final List<BluetoothDevice> scanDevices;
  final Object? scanError;

  FF1BleCommand? lastCommand;
  FF1BleRequest? lastRequest;

  @override
  BluetoothAdapterState get adapterState => BluetoothAdapterState.on;

  @override
  Stream<BluetoothAdapterState> get adapterStateStream =>
      Stream.value(BluetoothAdapterState.on);

  @override
  Future<bool> get isSupported => Future.value(true);

  @override
  Future<FF1BleResponse> sendCommand({
    required BluetoothDevice blDevice,
    required FF1BleCommand command,
    required FF1BleRequest request,
    Duration timeout = const Duration(seconds: 10),
  }) async {
    lastCommand = command;
    lastRequest = request;

    if (sendCommandCallback != null) {
      return sendCommandCallback!(blDevice, command, request, timeout);
    }

    if (sendCommandResponse != null) {
      return sendCommandResponse!;
    }

    throw UnimplementedError('No mock response configured');
  }

  @override
  Future<void> scan({
    required FutureOr<bool> Function(List<BluetoothDevice> devices) onDevice,
    Duration timeout = const Duration(seconds: 30),
  }) async {
    if (scanError != null) {
      throw scanError! as Exception;
    }

    await onDevice(scanDevices);
  }

  @override
  Future<BluetoothDevice?> scanForName({
    required String name,
    Duration timeout = const Duration(seconds: 15),
  }) async {
    if (scanError != null) {
      throw scanError! as Exception;
    }

    for (final device in scanDevices) {
      if (device.advName == name) {
        return device;
      }
    }

    return null;
  }

  @override
  Future<void> connect({
    required BluetoothDevice blDevice,
    Duration timeout = const Duration(seconds: 30),
    int maxRetries = 3,
    bool Function()? shouldContinue,
  }) async {
    // Mock: do nothing
  }

  @override
  Future<void> disconnect(BluetoothDevice device) async {
    // Mock: do nothing
  }
}
