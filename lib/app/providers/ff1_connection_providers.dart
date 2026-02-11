import 'package:app/app/providers/ff1_bluetooth_device_providers.dart';
import 'package:app/domain/models/ff1_device.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';

final _log = Logger('FF1ConnectionProviders');
// ============================================================================
// Connected Devices List
// ============================================================================

/// Get all devices that have successfully connected to WiFi (have topicId)
final connectedFF1DevicesProvider = FutureProvider<List<FF1Device>>((
  ref,
) async {
  final allDevices = await ref.watch(allFF1BluetoothDevicesProvider.future);
  return allDevices
      .where((device) => device.topicId != null && device.topicId!.isNotEmpty)
      .toList();
});

/// Get only disconnected devices (no topicId yet)
final disconnectedFF1DevicesProvider = FutureProvider<List<FF1Device>>((
  ref,
) async {
  final allDevices = await ref.watch(allFF1BluetoothDevicesProvider.future);
  return allDevices
      .where((device) => device.topicId == null || device.topicId!.isEmpty)
      .toList();
});

// ============================================================================
// Device Management Operations
// ============================================================================

/// Forget (remove) a connected device
final forgetFF1DeviceProvider = FutureProvider.family<void, String>((
  ref,
  deviceId,
) async {
  final deviceService = ref.read(ff1BluetoothDeviceServiceProvider);
  await deviceService.removeDevice(deviceId);
  ref.invalidate(allFF1BluetoothDevicesProvider);
  ref.invalidate(connectedFF1DevicesProvider);
  ref.invalidate(disconnectedFF1DevicesProvider);
  ref.invalidate(activeFF1BluetoothDeviceProvider);
});

/// Disconnect device (remove topicId but keep device in storage)
final disconnectFF1DeviceProvider = FutureProvider.family<void, String>((
  ref,
  deviceId,
) async {
  final deviceService = ref.read(ff1BluetoothDeviceServiceProvider);
  await deviceService.updateTopicId(deviceId, '');
  await deviceService.updateConnectionState(deviceId, 0);
  ref.invalidate(allFF1BluetoothDevicesProvider);
  ref.invalidate(connectedFF1DevicesProvider);
  ref.invalidate(disconnectedFF1DevicesProvider);
  ref.invalidate(activeFF1BluetoothDeviceProvider);
});
