import 'package:app/app/ff1/ff1_ble_device_connect.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('bleOperationRetryDelay', () {
    test('returns null for Error subclasses (no retry)', () {
      expect(bleOperationRetryDelay(0, ArgumentError()), isNull);
      expect(bleOperationRetryDelay(0, StateError('x')), isNull);
    });

    test('returns null after retryCount >= 3', () {
      expect(
        bleOperationRetryDelay(3, Exception()),
        isNull,
      );
    });

    test('returns exponential backoff for Exception', () {
      expect(
        bleOperationRetryDelay(0, Exception()),
        const Duration(seconds: 1),
      );
      expect(
        bleOperationRetryDelay(1, Exception()),
        const Duration(seconds: 2),
      );
      expect(
        bleOperationRetryDelay(2, Exception()),
        const Duration(seconds: 4),
      );
    });
  });

  group('connectFf1BleDeviceWithRiverpodRetries', () {
    test('succeeds on first attempt', () async {
      final port = _RecordingPort();
      final device = BluetoothDevice.fromId('aa:bb:cc:dd:ee:ff');

      await connectFf1BleDeviceWithRiverpodRetries(
        control: port,
        blDevice: device,
      );

      expect(port.connectCalls, 1);
      expect(port.lastMaxRetries, kFf1BleConnectMaxRetriesRiverpodLayer);
    });

    test('retries once after Exception then succeeds', () async {
      final port = _FailsOnceThenSucceedsPort();
      final device = BluetoothDevice.fromId('11:22:33:44:55:66');

      await connectFf1BleDeviceWithRiverpodRetries(
        control: port,
        blDevice: device,
      );

      expect(port.attempts, 2);
    });
  });
}

/// Test double implementing [Ff1BleConnectPort] without importing
/// [FF1BleControl] from ff1_providers.
class _RecordingPort implements Ff1BleConnectPort {
  int connectCalls = 0;
  BluetoothDevice? lastBlDevice;
  Duration lastTimeout = Duration.zero;
  int lastMaxRetries = -1;
  bool Function()? lastShouldContinue;

  @override
  Future<void> connect({
    required BluetoothDevice blDevice,
    Duration timeout = const Duration(seconds: 30),
    int maxRetries = 3,
    bool Function()? shouldContinue,
  }) async {
    connectCalls++;
    lastBlDevice = blDevice;
    lastTimeout = timeout;
    lastMaxRetries = maxRetries;
    lastShouldContinue = shouldContinue;
  }
}

class _FailsOnceThenSucceedsPort implements Ff1BleConnectPort {
  int attempts = 0;

  @override
  Future<void> connect({
    required BluetoothDevice blDevice,
    Duration timeout = const Duration(seconds: 30),
    int maxRetries = 3,
    bool Function()? shouldContinue,
  }) async {
    attempts++;
    if (attempts == 1) {
      throw Exception('simulated BLE failure');
    }
  }
}
