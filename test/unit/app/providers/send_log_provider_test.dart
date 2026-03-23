import 'dart:async';

import 'package:app/app/providers/ff1_providers.dart';
import 'package:app/app/providers/ff1_wifi_providers.dart';
import 'package:app/app/providers/send_log_provider.dart';
import 'package:app/domain/models/ff1_device.dart';
import 'package:app/infra/ff1/ble_protocol/ff1_ble_commands.dart';
import 'package:app/infra/ff1/ble_protocol/ff1_ble_protocol.dart';
import 'package:app/infra/ff1/ble_transport/ff1_ble_transport.dart';
import 'package:app/infra/ff1/wifi_protocol/ff1_wifi_messages.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'provider_test_helpers.dart';

void main() {
  // Device with a topicId (WiFi available) used by most tests.
  const wifiDevice = FF1Device(
    name: 'FF1-Test',
    remoteId: '00:11:22:33:44:55',
    deviceId: 'device-id',
    topicId: 'topic-abc',
  );

  // Device without a topicId — forces BLE-only path.
  const bleOnlyDevice = FF1Device(
    name: 'FF1-BleOnly',
    remoteId: '00:11:22:33:44:66',
    deviceId: 'device-id-2',
    topicId: '',
  );

  group('SendLogNotifier', () {
    group('SUPPORT_API_KEY absent', () {
      test('returns SendLogNotConfigured without contacting WiFi or BLE', () async {
        // Regression: with a missing key the flow must short-circuit before
        // issuing any transport command. Both transports throw if called so the
        // test will fail fast if the guard is bypassed.
        final wifiSpy = _SpyWifiControl(sendLogError: Exception('should not be called'));
        final bleTransport = _SpyBleTransport(throwOnSendLog: true);

        final container = ProviderContainer.test(
          overrides: [
            supportApiKeyProvider.overrideWithValue(''),
            ff1WifiControlProvider.overrideWithValue(wifiSpy),
            ff1TransportProvider.overrideWithValue(bleTransport),
          ],
        );
        addTearDown(container.dispose);

        final outcome = await container
            .read(sendLogProvider.notifier)
            .send(wifiDevice);

        expect(outcome, isA<SendLogNotConfigured>());
        expect(wifiSpy.sendLogCalled, isFalse);
        expect(bleTransport.sendLogCalled, isFalse);
      });
    });

    group('SUPPORT_API_KEY present', () {
      test('passes key to WiFi when topicId is available and WiFi succeeds', () async {
        // Regression: the support API key must reach the WiFi transport so the
        // device can authenticate with the backend.
        const testKey = 'test-support-key-123';
        final wifiSpy = _SpyWifiControl(
          response: FF1CommandResponse(status: 'ok'),
        );
        final bleTransport = _SpyBleTransport();

        final container = ProviderContainer.test(
          overrides: [
            supportApiKeyProvider.overrideWithValue(testKey),
            ff1WifiControlProvider.overrideWithValue(wifiSpy),
            ff1TransportProvider.overrideWithValue(bleTransport),
          ],
        );
        addTearDown(container.dispose);

        final outcome = await container
            .read(sendLogProvider.notifier)
            .send(wifiDevice);

        expect(outcome, isA<SendLogSuccess>());
        expect(wifiSpy.sendLogCalled, isTrue);
        expect(wifiSpy.capturedApiKey, testKey);
        // BLE should not be contacted when WiFi succeeds.
        expect(bleTransport.sendLogCalled, isFalse);
      });

      test('falls back to BLE with the same key when WiFi fails', () async {
        const testKey = 'test-support-key-456';
        final wifiSpy = _SpyWifiControl(sendLogError: Exception('wifi error'));
        final bleTransport = _SpyBleTransport();

        final container = ProviderContainer.test(
          overrides: [
            supportApiKeyProvider.overrideWithValue(testKey),
            ff1WifiControlProvider.overrideWithValue(wifiSpy),
            ff1TransportProvider.overrideWithValue(bleTransport),
          ],
        );
        addTearDown(container.dispose);

        final outcome = await container
            .read(sendLogProvider.notifier)
            .send(wifiDevice);

        expect(outcome, isA<SendLogSuccess>());
        expect(wifiSpy.sendLogCalled, isTrue);
        // BLE fallback must carry the same key so auth is consistent.
        expect(bleTransport.sendLogCalled, isTrue);
        expect(bleTransport.capturedApiKey, testKey);
      });

      test('falls back to BLE when WiFi returns non-ok status', () async {
        const testKey = 'test-support-key-789';
        final wifiSpy = _SpyWifiControl(
          response: FF1CommandResponse(status: 'error'),
        );
        final bleTransport = _SpyBleTransport();

        final container = ProviderContainer.test(
          overrides: [
            supportApiKeyProvider.overrideWithValue(testKey),
            ff1WifiControlProvider.overrideWithValue(wifiSpy),
            ff1TransportProvider.overrideWithValue(bleTransport),
          ],
        );
        addTearDown(container.dispose);

        final outcome = await container
            .read(sendLogProvider.notifier)
            .send(wifiDevice);

        expect(outcome, isA<SendLogSuccess>());
        expect(bleTransport.sendLogCalled, isTrue);
        expect(bleTransport.capturedApiKey, testKey);
      });

      test('goes directly to BLE when device has no topicId', () async {
        const testKey = 'test-support-key-ble-only';
        final wifiSpy = _SpyWifiControl(
          sendLogError: Exception('should not be called'),
        );
        final bleTransport = _SpyBleTransport();

        final container = ProviderContainer.test(
          overrides: [
            supportApiKeyProvider.overrideWithValue(testKey),
            ff1WifiControlProvider.overrideWithValue(wifiSpy),
            ff1TransportProvider.overrideWithValue(bleTransport),
          ],
        );
        addTearDown(container.dispose);

        final outcome = await container
            .read(sendLogProvider.notifier)
            .send(bleOnlyDevice);

        expect(outcome, isA<SendLogSuccess>());
        // WiFi must not be attempted when topicId is empty.
        expect(wifiSpy.sendLogCalled, isFalse);
        expect(bleTransport.sendLogCalled, isTrue);
        expect(bleTransport.capturedApiKey, testKey);
      });

      test('returns SendLogFailure when both WiFi and BLE fail', () async {
        const testKey = 'test-support-key-fail';
        final wifiSpy = _SpyWifiControl(sendLogError: Exception('wifi error'));
        final bleTransport = _SpyBleTransport(throwOnSendLog: true);

        final container = ProviderContainer.test(
          overrides: [
            supportApiKeyProvider.overrideWithValue(testKey),
            ff1WifiControlProvider.overrideWithValue(wifiSpy),
            ff1TransportProvider.overrideWithValue(bleTransport),
          ],
        );
        addTearDown(container.dispose);

        final outcome = await container
            .read(sendLogProvider.notifier)
            .send(wifiDevice);

        expect(outcome, isA<SendLogFailure>());
      });
    });
  });
}

// ============================================================================
// WiFi spy
// ============================================================================

/// Spy around [FakeWifiControl] that records [sendLog] calls and allows
/// configuring the response or exception to return.
class _SpyWifiControl extends FakeWifiControl {
  _SpyWifiControl({this.response, this.sendLogError});

  final FF1CommandResponse? response;
  final Exception? sendLogError;

  bool sendLogCalled = false;
  String? capturedApiKey;

  @override
  Future<FF1CommandResponse> sendLog({
    required String topicId,
    required String userId,
    required String? title,
    required String apiKey,
  }) async {
    sendLogCalled = true;
    capturedApiKey = apiKey;
    if (sendLogError != null) throw sendLogError!;
    return response ?? FF1CommandResponse(status: 'ok');
  }
}

// ============================================================================
// BLE transport spy
// ============================================================================

/// Minimal [FF1BleTransport] implementation that records [sendLog] calls
/// (via [sendCommand]) and allows simulating failures.
class _SpyBleTransport implements FF1BleTransport {
  _SpyBleTransport({this.throwOnSendLog = false});

  final bool throwOnSendLog;

  bool sendLogCalled = false;
  String? capturedApiKey;

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
    if (command == FF1BleCommand.sendLog) {
      sendLogCalled = true;
      if (request is SendLogRequest) {
        capturedApiKey = request.apiKey;
      }
      if (throwOnSendLog) {
        throw Exception('BLE sendLog error');
      }
      return const FF1BleResponse(topic: '', errorCode: 0, data: []);
    }
    throw UnimplementedError('Unexpected command in spy: $command');
  }

  @override
  Future<void> scan({
    required FutureOr<bool> Function(List<BluetoothDevice> devices) onDevice,
    Duration timeout = const Duration(seconds: 30),
  }) async {}

  @override
  Future<BluetoothDevice?> scanForName({
    required String name,
    Duration timeout = const Duration(seconds: 15),
  }) async => null;

  @override
  Future<void> connect({
    required BluetoothDevice blDevice,
    Duration timeout = const Duration(seconds: 30),
    int maxRetries = 3,
    bool Function()? shouldContinue,
  }) async {}

  @override
  Future<void> disconnect(BluetoothDevice device) async {}

  @override
  Future<void> waitUntilReady({
    required BluetoothDevice blDevice,
    Duration timeout = const Duration(seconds: 20),
  }) async {}
}
