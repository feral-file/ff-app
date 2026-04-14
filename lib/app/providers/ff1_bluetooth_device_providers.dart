import 'package:app/app/providers/ff1_wifi_providers.dart';
import 'package:app/domain/models/ff1_device.dart';
import 'package:app/infra/database/ff1_bluetooth_device_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';

final _log = Logger('FF1BluetoothDeviceProviders');

/// Service for managing FF1 Bluetooth device persistence.
///
/// Must be initialized in main.dart after ObjectBox setup.
final ff1BluetoothDeviceServiceProvider = Provider<FF1BluetoothDeviceService>((
  ref,
) {
  throw UnimplementedError(
    'FF1BluetoothDeviceService must be initialized in main.dart after '
    'ObjectBox setup',
  );
});

/// Stream of all stored Bluetooth devices.
///
/// Automatically updates when the ObjectBox database changes (migration,
/// add/remove device, etc.). No manual invalidation needed.
final allFF1BluetoothDevicesProvider = StreamProvider<List<FF1Device>>((ref) {
  final service = ref.watch(ff1BluetoothDeviceServiceProvider);
  return service.watchAllDevices();
});

/// Stream of the currently active device.
///
/// Automatically updates when the ObjectBox database changes.
final activeFF1BluetoothDeviceProvider = StreamProvider<FF1Device?>((ref) {
  final service = ref.watch(ff1BluetoothDeviceServiceProvider);
  return service.watchActiveDevice();
});

/// Notifier that exposes side-effecting mutations on FF1 Bluetooth devices.
///
/// All write operations must go through this notifier so each call always
/// executes the action. Using [FutureProvider.family] for mutations is an
/// anti-pattern in Riverpod — the provider caches the result and the body
/// only runs once per unique argument, silently skipping subsequent calls.
class FF1BluetoothDeviceActionsNotifier extends Notifier<void> {
  @override
  void build() {}

  FF1BluetoothDeviceService get _service =>
      ref.read(ff1BluetoothDeviceServiceProvider);

  /// Persists [device] and sets it as the active device.
  Future<void> addDevice(FF1Device device) async {
    await _service.putDevice(device);
    _log.info('Device saved: ${device.deviceId}');
    final activeDevice = _service.getActiveDevice();
    if (activeDevice?.deviceId == device.deviceId) {
      // Internet-ready setup already promotes the device before callers reach
      // teardown. Skipping the redundant active-device write avoids retriggering
      // auto-connect watchers while the setup flow is still unwinding.
      return;
    }
    await setActiveDevice(device.deviceId);
  }

  /// Removes the device with [deviceId] from storage.
  Future<void> removeDevice(String deviceId) async {
    await _service.removeDevice(deviceId);
    _log.info('Device removed: $deviceId');
  }

  /// Sets the device with [deviceId] as the active FF1 device.
  ///
  /// WiFi auto-connect is handled separately by [ff1AutoConnectWatcherProvider]
  /// when [activeFF1BluetoothDeviceProvider] changes.
  Future<void> setActiveDevice(String deviceId) async {
    // Clear the relayer cache before the active-device stream flips so UI
    // consumers never evaluate the new selection against the previous
    // device's status snapshot.
    final device = _service.getDeviceById(deviceId);
    if (device != null) {
      ref.read(ff1WifiControlProvider).prepareForDeviceSwitch(device);
    }
    await _service.setActiveDevice(deviceId);
    _log.info('Device set as active: $deviceId');
  }

  /// Updates the Bluetooth connection state for [deviceId].
  Future<void> updateConnectionState(String deviceId, int state) async {
    await _service.updateConnectionState(deviceId, state);
  }

  /// Records a failed connection attempt for [deviceId].
  Future<void> recordFailedConnection(String deviceId) async {
    await _service.recordFailedConnection(deviceId);
  }

  /// Updates the cloud topic ID for [deviceId].
  ///
  /// If [deviceId] is currently the active device and [topicId] is non-empty,
  /// re-triggers active-device promotion so WiFi auto-connect fires.
  Future<void> updateTopicId(String deviceId, String topicId) async {
    await _service.updateTopicId(deviceId, topicId);

    final activeDevice = _service.getActiveDevice();
    if (activeDevice?.deviceId == deviceId && topicId.isNotEmpty) {
      _log.info('TopicId updated for active device, triggering WiFi connect');
      await setActiveDevice(deviceId);
    }
  }

  /// Updates the metadata map for [deviceId].
  Future<void> updateMetadata(
    String deviceId,
    Map<String, dynamic> metadata,
  ) async {
    await _service.updateMetadata(deviceId, metadata);
  }
}

/// Provider for [FF1BluetoothDeviceActionsNotifier].
final ff1BluetoothDeviceActionsProvider =
    NotifierProvider<FF1BluetoothDeviceActionsNotifier, void>(
      FF1BluetoothDeviceActionsNotifier.new,
    );
