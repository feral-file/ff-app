import 'package:app/app/ff1/ff1_ble_device_connect.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:logging/logging.dart';

final _log = Logger('FF1WifiBleFallback');

/// Runs a WiFi-first command flow with a BLE fallback that is guaranteed to
/// connect and discover services before the BLE command runs.
///
/// Why: FF1 BLE commands require a live BLE session and cached command
/// characteristic. The caller must not invoke BLE fallback directly without
/// first establishing readiness, or the fallback will fail on disconnected
/// devices.
Future<bool> runWifiThenBleFallback({
  required Future<bool> Function() wifiAttempt,
  required Future<void> Function() bleAttempt,
  required Ff1BleConnectPort bleConnectPort,
  required BluetoothDevice blDevice,
  String actionName = 'FF1 command',
}) async {
  var success = false;

  try {
    success = await wifiAttempt();
  } on Object catch (e) {
    _log.warning('[$actionName] WiFi attempt failed: $e, falling back to BLE');
  }

  if (!success) {
    _log.info('[$actionName] Ensuring BLE readiness before fallback');
    await connectFf1BleDeviceWithRiverpodRetries(
      control: bleConnectPort,
      blDevice: blDevice,
    );
    await bleAttempt();
    success = true;
  }

  return success;
}
