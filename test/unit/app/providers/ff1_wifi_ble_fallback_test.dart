import 'package:app/app/ff1/ff1_ble_device_connect.dart';
import 'package:app/app/providers/ff1_wifi_ble_fallback.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('runWifiThenBleFallback', () {
    test('short-circuits BLE when WiFi succeeds', () async {
      final port = _RecordingPort();
      var bleCalled = false;

      final success = await runWifiThenBleFallback(
        wifiAttempt: () async => true,
        bleAttempt: () async {
          bleCalled = true;
        },
        bleConnectPort: port,
        blDevice: BluetoothDevice.fromId('00:11'),
        actionName: 'TestAction',
      );

      expect(success, isTrue);
      expect(port.connectCalls, 0);
      expect(bleCalled, isFalse);
    });

    test('connects before BLE command when WiFi fails', () async {
      final port = _RecordingPort();
      final callOrder = <String>[];

      final success = await runWifiThenBleFallback(
        wifiAttempt: () async => false,
        bleAttempt: () async {
          callOrder.add('ble');
        },
        bleConnectPort: port,
        blDevice: BluetoothDevice.fromId('00:11'),
        actionName: 'TestAction',
      );

      expect(success, isTrue);
      expect(port.connectCalls, 1);
      expect(callOrder, ['ble']);
    });

    test('connect failure stops BLE command dispatch', () async {
      final port = _FailsWithErrorPort();
      var bleCalled = false;

      final future = runWifiThenBleFallback(
        wifiAttempt: () async => false,
        bleAttempt: () async {
          bleCalled = true;
        },
        bleConnectPort: port,
        blDevice: BluetoothDevice.fromId('00:11'),
        actionName: 'TestAction',
      );

      await expectLater(
        future,
        throwsA(isA<StateError>().having(
          (error) => error.message,
          'message',
          'connect failed',
        )),
      );
      expect(bleCalled, isFalse);
    });
  });
}

class _RecordingPort implements Ff1BleConnectPort {
  int connectCalls = 0;

  @override
  Future<void> connect({
    required BluetoothDevice blDevice,
    Duration timeout = const Duration(seconds: 30),
    int maxRetries = 3,
    bool Function()? shouldContinue,
  }) async {
    connectCalls++;
  }
}

class _FailsWithErrorPort implements Ff1BleConnectPort {
  @override
  Future<void> connect({
    required BluetoothDevice blDevice,
    Duration timeout = const Duration(seconds: 30),
    int maxRetries = 3,
    bool Function()? shouldContinue,
  }) async {
    throw StateError('connect failed');
  }
}
