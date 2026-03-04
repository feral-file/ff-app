import 'package:app/app/providers/ff1_bluetooth_device_providers.dart';
import 'package:app/domain/models/ff1_device.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod/src/providers/future_provider.dart';

// ============================================================================
// Connected Devices List
// ============================================================================

/// Get all devices that have successfully connected to WiFi (have topicId).
///
/// Derives from [allFF1BluetoothDevicesProvider]; auto-updates when it changes.
final connectedFF1DevicesProvider = Provider<AsyncValue<List<FF1Device>>>(
  (Ref ref) {
    final allDevices = ref.watch(allFF1BluetoothDevicesProvider);
    return allDevices.whenData(
      (List<FF1Device> devices) =>
          devices.where((FF1Device d) => d.topicId.isNotEmpty).toList(),
    );
  },
);

/// Get only disconnected devices (no topicId yet).
///
/// Derives from [allFF1BluetoothDevicesProvider]; auto-updates when it changes.
final disconnectedFF1DevicesProvider = Provider<AsyncValue<List<FF1Device>>>(
  (Ref ref) {
    final allDevices = ref.watch(allFF1BluetoothDevicesProvider);
    return allDevices.whenData(
      (List<FF1Device> devices) =>
          devices.where((FF1Device d) => d.topicId.isEmpty).toList(),
    );
  },
);
