import 'package:app/app/providers/ff1_bluetooth_device_providers.dart';
import 'package:app/domain/models/ff1_device.dart';
import 'package:riverpod/src/providers/future_provider.dart';

// ============================================================================
// Connected Devices List
// ============================================================================

/// Get all devices that have successfully connected to WiFi (have topicId)
final connectedFF1DevicesProvider = FutureProvider<List<FF1Device>>((
  ref,
) async {
  final allDevices = await ref.watch(allFF1BluetoothDevicesProvider.future);
  return allDevices.where((device) => device.topicId.isNotEmpty).toList();
});

/// Get only disconnected devices (no topicId yet)
final disconnectedFF1DevicesProvider = FutureProvider<List<FF1Device>>((
  ref,
) async {
  final allDevices = await ref.watch(allFF1BluetoothDevicesProvider.future);
  return allDevices.where((device) => device.topicId.isEmpty).toList();
});
