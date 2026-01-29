import 'package:app/domain/models/ff1_device.dart';
import 'package:app/domain/models/ff1_error.dart';
import 'package:app/infra/ff1/ble_protocol/ff1_ble_commands.dart';
import 'package:app/infra/ff1/ble_protocol/ff1_ble_protocol.dart';
import 'package:app/infra/ff1/ble_transport/ff1_ble_transport.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';

// ============================================================================
// Transport and Protocol providers (infrastructure)
// ============================================================================

/// FF1 BLE protocol codec provider (singleton)
final ff1ProtocolProvider = Provider<FF1BleProtocol>((ref) {
  return const FF1BleProtocol();
});

/// FF1 BLE transport provider (singleton)
final ff1TransportProvider = Provider<FF1BleTransport>((ref) {
  final protocol = ref.watch(ff1ProtocolProvider);
  return FF1BleTransport(
    protocol: protocol,
    logger: Logger('FF1BleTransport'),
  );
});

// ============================================================================
// Bluetooth adapter state provider
// ============================================================================

/// Current Bluetooth adapter state (on, off, unavailable, etc.)
final bluetoothAdapterStateProvider =
    StreamProvider<BluetoothAdapterState>((ref) {
  final transport = ref.watch(ff1TransportProvider);
  return transport.adapterStateStream;
});

/// Check if Bluetooth is supported on this device
final bluetoothSupportedProvider = FutureProvider<bool>((ref) {
  final transport = ref.watch(ff1TransportProvider);
  return transport.isSupported;
});

// ============================================================================
// FF1 Control provider (orchestration)
// ============================================================================

/// FF1 BLE control provider: orchestrates commands and connection lifecycle
///
/// This is the main interface for interacting with FF1 devices over BLE.
/// Use this provider to:
/// - Connect/disconnect devices
/// - Scan for devices
/// - Send commands (WiFi, info, logs, etc.)
final ff1ControlProvider = Provider<FF1BleControl>((ref) {
  final transport = ref.watch(ff1TransportProvider);
  return FF1BleControl(transport: transport);
});

/// FF1 BLE Control: high-level orchestration of FF1 BLE commands
///
/// This class provides typed methods for all FF1 BLE operations.
/// It uses the transport layer to send commands and parse responses.
class FF1BleControl {
  FF1BleControl({required FF1BleTransport transport}) : _transport = transport;

  final FF1BleTransport _transport;

  /// Connect to an FF1 device
  Future<void> connect({
    required FF1Device device,
    Duration timeout = const Duration(seconds: 30),
    int maxRetries = 3,
    bool Function()? shouldContinue,
  }) async {
    await _transport.connect(
      device: device,
      timeout: timeout,
      maxRetries: maxRetries,
      shouldContinue: shouldContinue,
    );
  }

  /// Disconnect from device
  Future<void> disconnect(FF1Device device) async {
    await _transport.disconnect(device);
  }

  /// Scan for FF1 devices
  Future<List<BluetoothDevice>> scan({
    Duration timeout = const Duration(seconds: 30),
  }) async {
    final devices = <BluetoothDevice>[];
    await _transport.scan(
      timeout: timeout,
      onDevice: (foundDevices) {
        devices.addAll(foundDevices);
        return false; // Continue scanning
      },
    );
    return devices;
  }

  /// Scan for device by name
  Future<BluetoothDevice?> scanForName({
    required String name,
    Duration timeout = const Duration(seconds: 15),
  }) async {
    return _transport.scanForName(name: name, timeout: timeout);
  }

  /// Send WiFi credentials to device
  ///
  /// Returns the topicId on success, which can be used for cloud communication
  Future<String> sendWifiCredentials({
    required FF1Device device,
    required String ssid,
    required String password,
  }) async {
    final response = await _transport.sendCommand(
      device: device,
      command: FF1BleCommand.sendWifiCredentials,
      request: SendWifiCredentialsRequest(ssid: ssid, password: password),
      timeout: const Duration(seconds: 30),
    );

    if (response.isError) {
      throw FF1ResponseError.fromCode(response.errorCode);
    }

    if (response.data.isEmpty) {
      throw const FF1BluetoothError('No topicId in response');
    }

    return response.data[0];
  }

  /// Scan for available WiFi networks
  Future<List<String>> scanWifi({
    required FF1Device device,
  }) async {
    final response = await _transport.sendCommand(
      device: device,
      command: FF1BleCommand.scanWifi,
      request: const ScanWifiRequest(),
    );

    if (response.isError) {
      throw FF1ResponseError.fromCode(response.errorCode);
    }

    return response.data;
  }

  /// Keep current WiFi connection (get topicId if already connected)
  Future<String> keepWifi({
    required FF1Device device,
  }) async {
    final response = await _transport.sendCommand(
      device: device,
      command: FF1BleCommand.keepWifi,
      request: const KeepWifiRequest(),
    );

    if (response.isError) {
      throw FF1ResponseError.fromCode(response.errorCode);
    }

    if (response.data.isEmpty) {
      throw const FF1BluetoothError('No topicId in response');
    }

    return response.data[0];
  }

  /// Get device information
  Future<String> getInfo({
    required FF1Device device,
    int maxRetries = 3,
  }) async {
    var attempt = 0;

    while (attempt < maxRetries) {
      try {
        final response = await _transport.sendCommand(
          device: device,
          command: FF1BleCommand.getInfo,
          request: const GetInfoRequest(),
        );

        if (response.isError) {
          throw FF1ResponseError.fromCode(response.errorCode);
        }

        return response.data.isNotEmpty ? response.data[0] : '';
      } catch (e) {
        attempt++;
        if (attempt >= maxRetries) {
          rethrow;
        }

        // Wait before retry
        await Future<void>.delayed(
          Duration(milliseconds: attempt == 1 ? 1000 : 1500),
        );
      }
    }

    throw Exception('Failed to get device info after $maxRetries attempts');
  }

  /// Factory reset device
  Future<void> factoryReset({
    required FF1Device device,
  }) async {
    final response = await _transport.sendCommand(
      device: device,
      command: FF1BleCommand.factoryReset,
      request: const FactoryResetRequest(),
      timeout: const Duration(seconds: 30),
    );

    if (response.isError) {
      throw FF1ResponseError.fromCode(response.errorCode);
    }
  }

  /// Send device logs to support
  Future<void> sendLog({
    required FF1Device device,
    required String userId,
    required String title,
    required String apiKey,
  }) async {
    final response = await _transport.sendCommand(
      device: device,
      command: FF1BleCommand.sendLog,
      request: SendLogRequest(
        userId: userId,
        title: title,
        apiKey: apiKey,
      ),
      timeout: const Duration(seconds: 30),
    );

    if (response.isError) {
      throw FF1ResponseError.fromCode(response.errorCode);
    }
  }

  /// Set device timezone
  Future<void> setTimezone({
    required FF1Device device,
    required String timezone,
    DateTime? time,
  }) async {
    await _transport.sendCommand(
      device: device,
      command: FF1BleCommand.setTimezone,
      request: SetTimezoneRequest(timezone: timezone, time: time),
      timeout: const Duration(seconds: 5),
    );
    // Note: setTimezone doesn't wait for reply in original implementation
  }
}

// ============================================================================
// Scan state provider (for UI)
// ============================================================================

/// Scan state for UI
class FF1ScanState {
  const FF1ScanState({
    required this.isScanning,
    required this.devices,
    this.error,
  });

  final bool isScanning;
  final List<BluetoothDevice> devices;
  final Object? error;

  FF1ScanState copyWith({
    bool? isScanning,
    List<BluetoothDevice>? devices,
    Object? error,
  }) {
    return FF1ScanState(
      isScanning: isScanning ?? this.isScanning,
      devices: devices ?? this.devices,
      error: error,
    );
  }
}

/// FF1 BLE scan state notifier
class FF1ScanNotifier extends Notifier<FF1ScanState> {
  FF1ScanNotifier();

  FF1BleControl get _control => ref.read(ff1ControlProvider);

  @override
  FF1ScanState build() {
    return const FF1ScanState(isScanning: false, devices: []);
  }

  /// Start scanning for devices
  Future<void> startScan({
    Duration timeout = const Duration(seconds: 30),
  }) async {
    if (state.isScanning) return;

    state = state.copyWith(isScanning: true, error: null);

    try {
      final devices = await _control.scan(timeout: timeout);
      state = state.copyWith(isScanning: false, devices: devices);
    } catch (e) {
      state = state.copyWith(isScanning: false, error: e);
    }
  }

  /// Stop scanning
  void stopScan() {
    state = state.copyWith(isScanning: false);
  }

  /// Clear devices
  void clear() {
    state = const FF1ScanState(isScanning: false, devices: []);
  }
}

/// FF1 scan state provider
final ff1ScanProvider = NotifierProvider<FF1ScanNotifier, FF1ScanState>(
  FF1ScanNotifier.new,
);
