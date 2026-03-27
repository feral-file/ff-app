import 'package:flutter_blue_plus/flutter_blue_plus.dart';

// ============================================================================
// BLE connect primitive (single implementation for all call sites)
// ============================================================================

/// Retry delay for BLE operations (scan, connect, commands).
///
/// Retries up to 3 times with exponential backoff (1s, 2s, 4s).
/// Does not retry on [Error] (programming bugs).
///
/// Used by ff1BleSendCommandProvider and connectFf1BleDeviceWithRiverpodRetries
/// to match former FutureProvider retry behavior.
Duration? bleOperationRetryDelay(int retryCount, Object error) {
  if (error is Error) {
    return null;
  }
  if (retryCount >= 3) {
    return null;
  }
  return Duration(seconds: 1 << retryCount);
}

/// Transport-level retries disabled; outer loop retries (Riverpod-style).
const int kFf1BleConnectMaxRetriesRiverpodLayer = 0;

/// Default transport-level retries when the session notifier owns the attempt
/// (no outer [bleOperationRetryDelay] loop).
const int kFf1BleConnectMaxRetriesSessionDefault = 3;

/// Contract implemented by FF1BleControl for testability (Wi‑Fi connect +
/// retry loop only; ConnectFF1Notifier calls control.connect directly).
// ignore: one_member_abstracts — port keeps BLE connect mockable without pulling in FF1BleControl.
abstract class Ff1BleConnectPort {
  /// Connect to an FF1 device over BLE.
  Future<void> connect({
    required BluetoothDevice blDevice,
    Duration timeout = const Duration(seconds: 30),
    int maxRetries = 3,
    bool Function()? shouldContinue,
  });
}

/// Replaces the former ff1BleConnectProvider family: connect with maxRetries 0
/// on the transport, then bleOperationRetryDelay loop (same semantics as the
/// old provider retry:).
Future<void> connectFf1BleDeviceWithRiverpodRetries({
  required Ff1BleConnectPort control,
  required BluetoothDevice blDevice,
  Duration timeout = const Duration(seconds: 30),
}) async {
  var retryCount = 0;
  while (true) {
    try {
      await control.connect(
        blDevice: blDevice,
        timeout: timeout,
        maxRetries: kFf1BleConnectMaxRetriesRiverpodLayer,
      );
      return;
    } on Object catch (e) {
      final delay = bleOperationRetryDelay(retryCount, e);
      if (delay == null) {
        rethrow;
      }
      await Future<void>.delayed(delay);
      retryCount++;
    }
  }
}
