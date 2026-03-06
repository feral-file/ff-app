// ============================================================================
// WiFi Network Model
// ============================================================================

import 'package:app/app/providers/ff1_bluetooth_device_providers.dart';
import 'package:app/app/providers/ff1_providers.dart';
import 'package:app/domain/models/ff1_error.dart';
import 'package:app/domain/models/models.dart';
import 'package:app/infra/ff1/ble_protocol/ff1_ble_commands.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';

final _log = Logger('WiFiConnectionNotifier');

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
  /// Constructor.
  const WiFiConnectionState({
    this.deviceId,
    this.status = WiFiConnectionStatus.idle,
    this.message,
    this.scannedNetworks,
    this.selectedNetwork,
    this.topicId,
    this.error,
    this.isConnectionFailed = false,
  });

  /// Device ID.
  final String? deviceId;

  /// Status.
  final WiFiConnectionStatus status;
  final String? message;

  /// Scanned networks.
  final List<WiFiNetwork>? scannedNetworks;

  /// Selected network.
  final WiFiNetwork? selectedNetwork;

  /// Topic ID.
  final String? topicId;

  /// Error.
  final Object? error;

  /// Whether the connection failed.
  final bool isConnectionFailed;

  /// Copy with updated fields.
  WiFiConnectionState copyWith({
    String? deviceId,
    WiFiConnectionStatus? status,
    String? message,
    List<WiFiNetwork>? scannedNetworks,
    WiFiNetwork? selectedNetwork,
    String? topicId,
    Object? error,
    bool? isConnectionFailed,
  }) {
    return WiFiConnectionState(
      deviceId: deviceId ?? this.deviceId,
      status: status ?? this.status,
      message: message ?? this.message,
      scannedNetworks: scannedNetworks ?? this.scannedNetworks,
      selectedNetwork: selectedNetwork ?? this.selectedNetwork,
      topicId: topicId ?? this.topicId,
      error: error,
      isConnectionFailed: isConnectionFailed ?? this.isConnectionFailed,
    );
  }
}

/// WiFi connection status.
enum WiFiConnectionStatus {
  /// Idle.
  idle,

  /// Connecting.
  connecting,

  /// Scanning for available networks.
  scanningNetworks,

  /// User selects network.
  selectingNetwork,

  /// User enters password and we send credentials.
  sendingCredentials,

  /// Waiting for device to connect to WiFi and respond.
  waitingForDeviceConnection,

  /// Hiding QR code after successful connection.
  finalizingConnection,

  /// Success.
  success,

  /// Error.
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
  ///
  /// If [FF1Device.remoteId] is empty (device was paired without a cached BLE
  /// address), the method first scans by device name to resolve the address
  /// before connecting.
  ///
  /// Uses Riverpod's automatic retry for BLE operations.
  Future<void> connectAndScanNetworks({
    required FF1Device device,
  }) async {
    var connectionEstablished = false;

    try {
      state = state.copyWith(
        deviceId: device.deviceId,
        status: WiFiConnectionStatus.connecting,
        isConnectionFailed: false,
      );

      // Step 1: Resolve BluetoothDevice — scan first if remoteId is absent.
      late final BluetoothDevice blDevice;
      if (device.remoteId.isEmpty) {
        _log.info(
          'remoteId is empty for ${device.name}, scanning by name to resolve',
        );
        final control = ref.read(ff1ControlProvider);
        final found = await control.scanForName(name: device.name);
        if (found == null) {
          throw FF1BluetoothError(
            'Could not find ${device.name} via Bluetooth scan',
          );
        }
        _log.info('Found device via scan: ${found.remoteId}');
        blDevice = found;
      } else {
        blDevice = device.toBluetoothDevice();
      }

      // Step 1: Connect to device (with automatic retry)
      await ref.read(
        ff1BleConnectProvider(FF1BleConnectParams(blDevice: blDevice)).future,
      );
      _log.info('Connected to device: ${device.deviceId}');
      connectionEstablished = true;

      state = state.copyWith(
        status: WiFiConnectionStatus.scanningNetworks,
      );

      // Step 2: Scan for available WiFi networks (with automatic retry)
      final response = await ref.read(
        ff1BleSendCommandProvider(
          FF1BleCommandParams(
            blDevice: blDevice,
            command: FF1BleCommand.scanWifi,
            request: const ScanWifiRequest(),
          ),
        ).future,
      );

      if (response.isError) {
        throw FF1ResponseError.fromCode(response.errorCode);
      }

      final ssidList = response.data;
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
      _log.severe('FF1 Error during connect/scan: $e');
      state = state.copyWith(
        status: WiFiConnectionStatus.error,
        error: e,
        isConnectionFailed: !connectionEstablished,
        message: e.message,
      );
    } on Exception catch (e, st) {
      _log.severe('Unexpected error during connect/scan', e, st);
      state = state.copyWith(
        status: WiFiConnectionStatus.error,
        error: e,
        isConnectionFailed: !connectionEstablished,
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
  ///
  /// Uses Riverpod's automatic retry for BLE operations.
  Future<void> sendCredentialsAndConnect({
    required FF1Device device,
    required String ssid,
    required String password,
  }) async {
    try {
      state = state.copyWith(
        status: WiFiConnectionStatus.sendingCredentials,
        message: 'Sending WiFi credentials to device...',
      );
      final blDevice = device.toBluetoothDevice();

      // Step 5: Send WiFi credentials (connect_wifi command) with automatic retry
      // Device will attempt to connect to WiFi and respond with topicId
      final response = await ref.read(
        ff1BleSendCommandProvider(
          FF1BleCommandParams(
            blDevice: blDevice,
            command: FF1BleCommand.sendWifiCredentials,
            request: SendWifiCredentialsRequest(ssid: ssid, password: password),
            timeout: const Duration(seconds: 60),
          ),
        ).future,
      );

      if (response.isError) {
        throw FF1ResponseError.fromCode(response.errorCode);
      }

      if (response.data.isEmpty) {
        throw const FF1BluetoothError('No topicId in response');
      }

      final topicId = response.data[0];
      _log.info('Received topicId from device: $topicId');

      state = state.copyWith(
        status: WiFiConnectionStatus.waitingForDeviceConnection,
        message: 'Device connected to WiFi successfully',
        topicId: topicId,
      );

      // Step 7: Update database with topicId
      state = state.copyWith(
        status: WiFiConnectionStatus.finalizingConnection,
        message: 'Saving device configuration...',
      );

      final updatedDevice = device.copyWith(topicId: topicId);
      await ref.read(addFF1BluetoothDeviceProvider(updatedDevice).future);

      state = state.copyWith(
        status: WiFiConnectionStatus.success,
        topicId: topicId,
        message: 'Device connected successfully!',
      );
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
final connectWiFiProvider =
    NotifierProvider<WiFiConnectionNotifier, WiFiConnectionState>(
      WiFiConnectionNotifier.new,
    );
