import 'package:app/app/providers/ff1_bluetooth_device_providers.dart';
import 'package:app/infra/database/ff1_bluetooth_device_service.dart';
import 'package:app/infra/database/objectbox_models.dart';
import 'package:app/domain/models/ff1_device.dart';
import 'package:app/objectbox.g.dart' show FF1BluetoothDeviceEntity_;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:objectbox/objectbox.dart';

/// Service for managing FF1 Bluetooth device persistence.
///
/// This provider exposes the database service for CRUD operations.
/// Must be initialized in main.dart after ObjectBox setup.
///
/// Usage in main.dart:
/// ```dart
/// final container = ProviderContainer(
///   overrides: [
///     ff1BluetoothDeviceServiceProvider.overrideWithValue(
///       FF1BluetoothDeviceService(box),
///     ),
///   ],
/// );
/// ```
final ff1BluetoothDeviceServiceProvider =
    Provider<FF1BluetoothDeviceService>((ref) {
  throw UnimplementedError(
    'FF1BluetoothDeviceService must be initialized in main.dart after '
    'ObjectBox setup',
  );
});

/// Get all stored Bluetooth devices.
///
/// Usage:
/// ```dart
/// final devices = ref.watch(allFF1BluetoothDevicesProvider);
/// ```
final allFF1BluetoothDevicesProvider =
    FutureProvider<List<FF1Device>>((ref) async {
  final service = ref.watch(ff1BluetoothDeviceServiceProvider);
  return service.getAllDevices();
});

/// Get a specific device by ID.
///
/// Usage:
/// ```dart
/// final device = ref.watch(ff1BluetoothDeviceByIdProvider('device123'));
/// ```
final ff1BluetoothDeviceByIdProvider =
    FutureProvider.family<FF1Device?, String>((ref, deviceId) async {
  final service = ref.watch(ff1BluetoothDeviceServiceProvider);
  return service.getDeviceById(deviceId);
});

/// Get the currently active device.
///
/// Usage:
/// ```dart
/// final activeDevice = ref.watch(activeFF1BluetoothDeviceProvider);
/// ```
final activeFF1BluetoothDeviceProvider =
    FutureProvider<FF1Device?>((ref) async {
  final service = ref.watch(ff1BluetoothDeviceServiceProvider);
  return service.getActiveDevice();
});

/// Get a device by its Bluetooth remote ID.
///
/// Usage:
/// ```dart
/// final device = ref.watch(
///   ff1BluetoothDeviceByRemoteIdProvider('AA:BB:CC:DD:EE:FF'),
/// );
/// ```
final ff1BluetoothDeviceByRemoteIdProvider =
    FutureProvider.family<FF1Device?, String>((ref, remoteId) async {
  final service = ref.watch(ff1BluetoothDeviceServiceProvider);
  return service.getDeviceByRemoteId(remoteId);
});

/// Add a new device to storage.
///
/// Usage:
/// ```dart
/// final result = await ref.read(
///   addFF1BluetoothDeviceProvider(device).future,
/// );
/// ```
final addFF1BluetoothDeviceProvider =
    FutureProvider.family<void, FF1Device>((ref, device) async {
  final service = ref.watch(ff1BluetoothDeviceServiceProvider);
  await service.putDevice(device);
  ref.invalidate(allFF1BluetoothDevicesProvider);
  ref.invalidate(activeFF1BluetoothDeviceProvider);
});

/// Remove a device from storage.
final removeFF1BluetoothDeviceProvider =
    FutureProvider.family<void, String>((ref, deviceId) async {
  final service = ref.watch(ff1BluetoothDeviceServiceProvider);
  await service.removeDevice(deviceId);
  ref.invalidate(allFF1BluetoothDevicesProvider);
  ref.invalidate(activeFF1BluetoothDeviceProvider);
});

/// Set a device as active.
final setActiveFF1BluetoothDeviceProvider =
    FutureProvider.family<void, String>((ref, deviceId) async {
  final service = ref.watch(ff1BluetoothDeviceServiceProvider);
  await service.setActiveDevice(deviceId);
  ref.invalidate(allFF1BluetoothDevicesProvider);
  ref.invalidate(activeFF1BluetoothDeviceProvider);
});

/// Update device connection state.
final updateFF1DeviceConnectionStateProvider =
    FutureProvider.family<void, ({String deviceId, int state})>(
  (ref, params) async {
    final service = ref.watch(ff1BluetoothDeviceServiceProvider);
    await service.updateConnectionState(params.deviceId, params.state);
    ref.invalidate(allFF1BluetoothDevicesProvider);
  },
);

/// Record a failed connection attempt.
final recordFF1FailedConnectionProvider =
    FutureProvider.family<void, String>((ref, deviceId) async {
  final service = ref.watch(ff1BluetoothDeviceServiceProvider);
  await service.recordFailedConnection(deviceId);
  ref.invalidate(allFF1BluetoothDevicesProvider);
});

/// Update device topic ID (cloud connectivity).
final updateFF1DeviceTopicIdProvider =
    FutureProvider.family<void, ({String deviceId, String topicId})>(
  (ref, params) async {
    final service = ref.watch(ff1BluetoothDeviceServiceProvider);
    await service.updateTopicId(params.deviceId, params.topicId);
    ref.invalidate(allFF1BluetoothDevicesProvider);
  },
);

/// Update device metadata.
final updateFF1DeviceMetadataProvider = FutureProvider.family<
    void,
    ({String deviceId, Map<String, dynamic> metadata})>(
  (ref, params) async {
    final service = ref.watch(ff1BluetoothDeviceServiceProvider);
    await service.updateMetadata(params.deviceId, params.metadata);
    ref.invalidate(allFF1BluetoothDevicesProvider);
  },
);
