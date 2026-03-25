import 'dart:async';

import 'package:app/app/providers/ff1_providers.dart';
import 'package:app/domain/extensions/string_ext.dart';
import 'package:app/domain/models/ff1_device_info.dart';
import 'package:app/domain/models/ff1_error.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class FF1GetDeviceInfoParams {
  const FF1GetDeviceInfoParams({
    required this.blDevice,
    required this.deeplinkInfo,
    required this.shouldContinue,
  });

  final BluetoothDevice blDevice;
  final FF1DeviceInfo? deeplinkInfo;
  final bool Function() shouldContinue;

  void assertShouldContinue() {
    if (!shouldContinue()) {
      throw const FF1ConnectionCancelledError();
    }
  }
}

// Matches existing behavior in ConnectFF1Notifier.
const List<Duration> _kGetInfoRetryDelays = <Duration>[
  Duration(milliseconds: 300),
  Duration(milliseconds: 900),
  Duration(milliseconds: 1500),
  Duration(milliseconds: 2200),
];

const Duration _kGetInfoReadinessTimeout = Duration(seconds: 8);

/// Flow 2: obtain [FF1DeviceInfo] for a connected BLE device.
///
/// - If [FF1GetDeviceInfoParams.deeplinkInfo] is non-null, returns it (no BLE).
/// - Otherwise, calls `get_info` with the same retry semantics as the legacy
///   connect notifier.
final ff1GetDeviceInfoProvider =
    FutureProvider.family<FF1DeviceInfo, FF1GetDeviceInfoParams>((
  ref,
  params,
) async {
  // Ensure cancellation can surface through async boundary consistently.
  await Future<void>.value();
  params.assertShouldContinue();
  final deeplinkInfo = params.deeplinkInfo;
  if (deeplinkInfo != null) {
    return deeplinkInfo;
  }

  final control = ref.read(ff1ControlProvider);
  Exception? lastError;
  for (final delay in _kGetInfoRetryDelays) {
    params.assertShouldContinue();
    await Future<void>.delayed(delay);
    try {
      params.assertShouldContinue();
      await control.waitUntilReady(
        blDevice: params.blDevice,
        timeout: _kGetInfoReadinessTimeout,
      );
      params.assertShouldContinue();
      final encoded = await control.getInfo(blDevice: params.blDevice);
      params.assertShouldContinue();
      return encoded.toFF1DeviceInfo;
    } on Exception catch (e) {
      lastError = e;
      final shouldRetry =
          e is TimeoutException ||
          e.toString().contains('BLE characteristic readiness timeout') ||
          e.toString().contains('Command characteristic not found');
      if (!shouldRetry) {
        rethrow;
      }
    }
  }

  if (lastError != null) {
    throw lastError;
  }
  throw Exception('Failed to get device info');
});

