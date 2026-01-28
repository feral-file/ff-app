import 'package:app/app/providers/ff1_bluetooth_device_providers.dart';
import 'package:app/domain/models/ff1_device.dart';
import 'package:app/domain/models/ff1_error.dart';
import 'package:app/app/providers/ff1_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';

final _log = Logger('FF1ConnectionProviders');

// ============================================================================
// WiFi Network Model
// ============================================================================

/// Represents a WiFi network/SSID
class WiFiNetwork {
  const WiFiNetwork(this.ssid);

  final String ssid;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WiFiNetwork &&
          runtimeType == other.runtimeType &&
          ssid == other.ssid;

  @override
  int get hashCode => ssid.hashCode;
}

// ============================================================================
// WiFi Connection State
// ============================================================================

/// State representing WiFi connection progress for a device
class WiFiConnectionState {
  const WiFiConnectionState({
    this.deviceId,
    this.status = WiFiConnectionStatus.idle,
    this.message,
    this.scannedNetworks,
    this.selectedNetwork,
    this.topicId,
    this.error,
  });

  final String? deviceId;
  final WiFiConnectionStatus status;
  final String? message;
  final List<WiFiNetwork>? scannedNetworks;
  final WiFiNetwork? selectedNetwork;
  final String? topicId;
  final Object? error;

  WiFiConnectionState copyWith({
    String? deviceId,
    WiFiConnectionStatus? status,
    String? message,
    List<WiFiNetwork>? scannedNetworks,
    WiFiNetwork? selectedNetwork,
    String? topicId,
    Object? error,
  }) {
    return WiFiConnectionState(
      deviceId: deviceId ?? this.deviceId,
      status: status ?? this.status,
      message: message ?? this.message,
      scannedNetworks: scannedNetworks ?? this.scannedNetworks,
      selectedNetwork: selectedNetwork ?? this.selectedNetwork,
      topicId: topicId ?? this.topicId,
      error: error,
    );
  }
}

enum WiFiConnectionStatus {
  idle,
  // Step 1: Initial BLE connection
  connecting,
  // Step 2: Scanning for available networks
  scanningNetworks,
  // Step 3: User selects network
  selectingNetwork,
  // Step 4: User enters password and we send credentials
  sendingCredentials,
  // Step 5: Waiting for device to connect to WiFi and respond
  waitingForDeviceConnection,
  // Step 6: Hiding QR code after successful connection
  finalizingConnection,
  // Final state
  success,
  error,
}

// ============================================================================
// WiFi Connection Notifier
// ============================================================================

/// Notifier for managing complete WiFi connection flow
/// 
/// Steps:
/// 1. Connect to device via BLE
/// 2. Scan for available WiFi networks
/// 3. User selects network from list
/// 4. User enters password
/// 5. Send SSID + password to device
/// 6. Wait for device to connect to WiFi and respond with topicId
/// 7. Finalize connection (hide QR code, etc)
/// 8. Update database with topicId and set as active
class WiFiConnectionNotifier extends Notifier<WiFiConnectionState> {
  @override
  WiFiConnectionState build() {
    return const WiFiConnectionState();
  }

  /// Step 1 & 2: Connect to device and scan for WiFi networks
  Future<void> connectAndScanNetworks({
    required FF1Device device,
  }) async {
    try {
      state = state.copyWith(
        deviceId: device.deviceId,
        status: WiFiConnectionStatus.connecting,
        message: 'Connecting to ${device.name}...',
      );

      final ff1Control = ref.read(ff1ControlProvider);

      // Step 1: Connect to device
      await ff1Control.connect(device: device);
      _log.info('Connected to device: ${device.deviceId}');

      state = state.copyWith(
        status: WiFiConnectionStatus.scanningNetworks,
        message: 'Scanning for WiFi networks...',
      );

      // Step 2: Scan for available WiFi networks
      final ssidList = await ff1Control.scanWifi(device: device);
      _log.info('Found ${ssidList.length} WiFi networks');

      final networks = ssidList
          .where((ssid) => ssid.isNotEmpty)
          .map(WiFiNetwork.new)
          .toList();

      state = state.copyWith(
        status: WiFiConnectionStatus.selectingNetwork,
        message: 'Select a WiFi network',
        scannedNetworks: networks,
      );
    } on FF1Error catch (e) {
      _log.severe('FF1 Error during scan: $e');
      state = state.copyWith(
        status: WiFiConnectionStatus.error,
        error: e,
        message: 'Scan failed: ${e.message}',
      );
    } catch (e, st) {
      _log.severe('Unexpected error during scan', e, st);
      state = state.copyWith(
        status: WiFiConnectionStatus.error,
        error: e,
        message: 'Unexpected error: $e',
      );
    }
  }

  /// Step 3: User selects a network
  void selectNetwork(WiFiNetwork network) {
    state = state.copyWith(
      selectedNetwork: network,
      status: WiFiConnectionStatus.selectingNetwork,
      message: 'Enter password for ${network.ssid}',
    );
  }

  /// Step 4 & 5 & 6: Send WiFi credentials and wait for device connection
  Future<void> sendCredentialsAndConnect({
    required FF1Device device,
    required String ssid,
    required String password,
    bool useKeepWifiCommand = false,
  }) async {
    try {
      state = state.copyWith(
        status: WiFiConnectionStatus.sendingCredentials,
        message: 'Sending WiFi credentials to device...',
      );

      final ff1Control = ref.read(ff1ControlProvider);

      // Step 5: Send WiFi credentials (connect_wifi command)
      // Device will attempt to connect to WiFi and respond with topicId
      final topicId = await ff1Control.sendWifiCredentials(
        device: device,
        ssid: ssid,
        password: password,
      );
      _log.info('Received topicId from device: $topicId');

      state = state.copyWith(
        status: WiFiConnectionStatus.waitingForDeviceConnection,
        message: 'Device connected to WiFi successfully',
        topicId: topicId,
      );

      // Step 6 (Optional): Send keep_wifi command if needed
      // This is mainly used when reconnecting to an existing WiFi network
      if (useKeepWifiCommand) {
        state = state.copyWith(
          status: WiFiConnectionStatus.finalizingConnection,
          message: 'Confirming WiFi connection...',
        );

        try {
          final confirmedTopicId = await ff1Control.keepWifi(device: device);
          _log.info('Confirmed topicId via keep_wifi: $confirmedTopicId');
        } catch (e) {
          _log.warning('keep_wifi command failed (non-critical): $e');
          // Non-critical error - continue with flow
        }
      }

      // Step 7: Update database with topicId
      state = state.copyWith(
        status: WiFiConnectionStatus.finalizingConnection,
        message: 'Saving device configuration...',
      );

      final updatedDevice = device.copyWith(topicId: topicId);
      final deviceService = ref.read(ff1BluetoothDeviceServiceProvider);

      await deviceService.putDevice(updatedDevice);
      _log.info('Device updated in database with topicId: $topicId');

      // Set as active device
      await deviceService.setActiveDevice(device.deviceId);
      _log.info('Device set as active');

      // Update connection state to connected
      await deviceService.updateConnectionState(device.deviceId, 1);

      // Invalidate providers to reflect changes
      ref.invalidate(allFF1BluetoothDevicesProvider);
      ref.invalidate(activeFF1BluetoothDeviceProvider);
      ref.invalidate(ff1BluetoothDeviceByIdProvider(device.deviceId));

      state = state.copyWith(
        status: WiFiConnectionStatus.success,
        message: 'Device connected successfully!',
      );

      // Note: Hiding QR code (showPairingQRCode) is done via WebSocket/cloud
      // using the topicId, not via BLE. That should be handled separately
      // in the cloud communication layer.

      await Future<void>.delayed(const Duration(seconds: 2));
      state = const WiFiConnectionState();
    } on FF1Error catch (e) {
      _log.severe('FF1 Error: $e');
      state = state.copyWith(
        status: WiFiConnectionStatus.error,
        error: e,
        message: 'Connection failed: ${e.message}',
      );
    } catch (e, st) {
      _log.severe('Unexpected error during connection', e, st);
      state = state.copyWith(
        status: WiFiConnectionStatus.error,
        error: e,
        message: 'Unexpected error: $e',
      );
    }
  }

  /// Reset connection state
  void reset() {
    state = const WiFiConnectionState();
  }
}

// ============================================================================
// WiFi Connection Provider
// ============================================================================

/// Provider for WiFi connection management
final wifiConnectionProvider = NotifierProvider<
    WiFiConnectionNotifier,
    WiFiConnectionState
>(WiFiConnectionNotifier.new);

// ============================================================================
// Connected Devices List
// ============================================================================

/// Get all devices that have successfully connected to WiFi (have topicId)
final connectedFF1DevicesProvider =
    FutureProvider<List<FF1Device>>((ref) async {
  final allDevices =
      await ref.watch(allFF1BluetoothDevicesProvider.future);
  return allDevices
      .where((device) => device.topicId != null && device.topicId!.isNotEmpty)
      .toList();
});

/// Get only disconnected devices (no topicId yet)
final disconnectedFF1DevicesProvider =
    FutureProvider<List<FF1Device>>((ref) async {
  final allDevices =
      await ref.watch(allFF1BluetoothDevicesProvider.future);
  return allDevices
      .where((device) => device.topicId == null || device.topicId!.isEmpty)
      .toList();
});

// ============================================================================
// Device Management Operations
// ============================================================================

/// Forget (remove) a connected device
final forgetFF1DeviceProvider =
    FutureProvider.family<void, String>((ref, deviceId) async {
  final deviceService = ref.read(ff1BluetoothDeviceServiceProvider);
  await deviceService.removeDevice(deviceId);
  ref.invalidate(allFF1BluetoothDevicesProvider);
  ref.invalidate(connectedFF1DevicesProvider);
  ref.invalidate(disconnectedFF1DevicesProvider);
  ref.invalidate(activeFF1BluetoothDeviceProvider);
});

/// Disconnect device (remove topicId but keep device in storage)
final disconnectFF1DeviceProvider =
    FutureProvider.family<void, String>((ref, deviceId) async {
  final deviceService = ref.read(ff1BluetoothDeviceServiceProvider);
  await deviceService.updateTopicId(deviceId, '');
  await deviceService.updateConnectionState(deviceId, 0);
  ref.invalidate(allFF1BluetoothDevicesProvider);
  ref.invalidate(connectedFF1DevicesProvider);
  ref.invalidate(disconnectedFF1DevicesProvider);
  ref.invalidate(activeFF1BluetoothDeviceProvider);
});
