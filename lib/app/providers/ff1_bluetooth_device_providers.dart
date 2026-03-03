import 'package:app/app/providers/ff1_wifi_providers.dart';
import 'package:app/domain/models/ff1_device.dart';
import 'package:app/infra/database/ff1_bluetooth_device_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:riverpod/src/providers/future_provider.dart';

final _log = Logger('FF1BluetoothDeviceProviders');

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
///       FF1BluetoothDeviceService(store, store.box<FF1BluetoothDeviceEntity>()),
///     ),
///   ],
/// );
/// ```
final ff1BluetoothDeviceServiceProvider = Provider<FF1BluetoothDeviceService>((
  ref,
) {
  throw UnimplementedError(
    'FF1BluetoothDeviceService must be initialized in main.dart after '
    'ObjectBox setup',
  );
});

/// Get all stored Bluetooth devices.
///
/// Automatically updates when the ObjectBox database changes (migration,
/// add/remove device, etc.). No manual [ref.invalidate] needed.
///
/// Usage:
/// ```dart
/// final devices = ref.watch(allFF1BluetoothDevicesProvider);
/// ```
final allFF1BluetoothDevicesProvider = StreamProvider<List<FF1Device>>((ref) {
  final service = ref.watch(ff1BluetoothDeviceServiceProvider);
  return service.watchAllDevices();
});

/// Get the currently active device.
///
/// Automatically updates when the ObjectBox database changes (migration,
/// setActiveDevice, remove device, etc.). No manual [ref.invalidate] needed.
///
/// Usage:
/// ```dart
/// final activeDevice = ref.watch(activeFF1BluetoothDeviceProvider);
/// ```
final activeFF1BluetoothDeviceProvider = StreamProvider<FF1Device?>((ref) {
  final service = ref.watch(ff1BluetoothDeviceServiceProvider);
  return service.watchActiveDevice();
});

/// Add a new device to storage and set it as active.
///
/// After saving the device, it will automatically be set as the active device.
///
/// Usage:
/// ```dart
/// final result = await ref.read(
///   addFF1BluetoothDeviceProvider(device).future,
/// );
/// ```
final FutureProviderFamily<void, FF1Device> addFF1BluetoothDeviceProvider =
    FutureProvider.family<void, FF1Device>((ref, device) async {
      final service = ref.watch(ff1BluetoothDeviceServiceProvider);

      // Save device to database
      await service.putDevice(device);
      _log.info('Device saved: ${device.deviceId}');

      // Auto-set as active device
      await ref.read(
        setActiveFF1BluetoothDeviceProvider(device.deviceId).future,
      );
    });

/// Remove a device from storage.
final FutureProviderFamily<void, String> removeFF1BluetoothDeviceProvider =
    FutureProvider.family<void, String>((ref, deviceId) async {
      final service = ref.watch(ff1BluetoothDeviceServiceProvider);
      await service.removeDevice(deviceId);
    });

/// Set a device as the active FF1 device.
///
/// WiFi auto-connect is handled separately by [ff1AutoConnectWatcherProvider]
/// when [activeFF1BluetoothDeviceProvider] changes.
/// Usage:
/// ```dart
/// await ref.read(setActiveFF1BluetoothDeviceProvider(deviceId).future);
/// ```
final FutureProviderFamily<void, String>
setActiveFF1BluetoothDeviceProvider = FutureProvider.family<void, String>(
  (ref, deviceId) async {
    final service = ref.watch(ff1BluetoothDeviceServiceProvider);

    // Set as active device
    await service.setActiveDevice(deviceId);
    _log.info('Device set as active: $deviceId');
  },
);

/// Update device connection state.
final FutureProviderFamily<void, ({String deviceId, int state})>
updateFF1DeviceConnectionStateProvider =
    FutureProvider.family<void, ({String deviceId, int state})>(
      (ref, params) async {
        final service = ref.watch(ff1BluetoothDeviceServiceProvider);
        await service.updateConnectionState(params.deviceId, params.state);
      },
    );

/// Record a failed connection attempt.
final FutureProviderFamily<void, String> recordFF1FailedConnectionProvider =
    FutureProvider.family<void, String>((ref, deviceId) async {
      final service = ref.watch(ff1BluetoothDeviceServiceProvider);
      await service.recordFailedConnection(deviceId);
    });

/// Update device topic ID (cloud connectivity).
final FutureProviderFamily<void, ({String deviceId, String topicId})>
updateFF1DeviceTopicIdProvider =
    FutureProvider.family<void, ({String deviceId, String topicId})>(
      (ref, params) async {
        final service = ref.watch(ff1BluetoothDeviceServiceProvider);
        await service.updateTopicId(params.deviceId, params.topicId);

        // If this is the active device, trigger WiFi connection by refreshing active device
        final activeDevice = service.getActiveDevice();
        if (activeDevice?.deviceId == params.deviceId &&
            params.topicId.isNotEmpty) {
          _log.info(
            'TopicId updated for active device, triggering WiFi connect',
          );
          await ref.read(
            setActiveFF1BluetoothDeviceProvider(params.deviceId).future,
          );
        }
      },
    );

/// Update device metadata.
final FutureProviderFamily<
  void,
  ({String deviceId, Map<String, dynamic> metadata})
>
updateFF1DeviceMetadataProvider =
    FutureProvider.family<
      void,
      ({String deviceId, Map<String, dynamic> metadata})
    >(
      (ref, params) async {
        final service = ref.watch(ff1BluetoothDeviceServiceProvider);
        await service.updateMetadata(params.deviceId, params.metadata);
      },
    );
