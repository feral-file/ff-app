import 'package:app/domain/models/ff1_error.dart';
import 'package:app/infra/ff1/ble_protocol/ff1_ble_commands.dart';
import 'package:app/infra/ff1/ble_protocol/ff1_ble_protocol.dart';
import 'package:app/infra/ff1/ble_transport/ff1_ble_transport.dart';
import 'package:collection/collection.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:riverpod/src/providers/future_provider.dart';

// ============================================================================
// Custom Retry Logic for BLE Operations
// ============================================================================

/// Retry logic for BLE operations (scan, connect, commands).
///
/// Retries up to 3 times with exponential backoff (1s, 2s, 4s).
/// Does not retry on Errors (programming bugs).
Duration? _bleRetry(int retryCount, Object error) {
  // Don't retry errors (programming bugs - indicate code issues)
  if (error is Error) {
    return null;
  }

  // Max 3 retries
  if (retryCount >= 3) return null;

  // Exponential backoff: 1s, 2s, 4s
  return Duration(seconds: 1 << retryCount);
}

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
final bluetoothAdapterStateProvider = StreamProvider<BluetoothAdapterState>((
  ref,
) {
  final transport = ref.watch(ff1TransportProvider);
  return transport.adapterStateStream;
});

/// Returns the connected BLE device for the given device name, if currently
/// connected. Use when we need to resolve remoteId from connected device.
final FutureProviderFamily<BluetoothDevice?, String> connectedBlDeviceForNameProvider =
    FutureProvider.family<BluetoothDevice?, String>((ref, name) async {
  final connected = FlutterBluePlus.connectedDevices;
  return connected.firstWhereOrNull((d) => d.advName == name);
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
    required BluetoothDevice blDevice,
    Duration timeout = const Duration(seconds: 30),
    int maxRetries = 3,
    bool Function()? shouldContinue,
  }) async {
    await _transport.connect(
      blDevice: blDevice,
      timeout: timeout,
      maxRetries: maxRetries,
      shouldContinue: shouldContinue,
    );
  }

  /// Disconnect from device
  Future<void> disconnect(BluetoothDevice blDevice) async {
    await _transport.disconnect(blDevice);
  }

  /// Wait until BLE command characteristic is ready.
  Future<void> waitUntilReady({
    required BluetoothDevice blDevice,
    Duration timeout = const Duration(seconds: 20),
  }) async {
    await _transport.waitUntilReady(blDevice: blDevice, timeout: timeout);
  }

  /// Scan for FF1 devices
  Future<List<BluetoothDevice>> scan({
    Duration timeout = const Duration(seconds: 30),
  }) async {
    // Use Map to deduplicate devices by remote ID
    final deviceMap = <String, BluetoothDevice>{};
    await _transport.scan(
      timeout: timeout,
      onDevice: (foundDevices) {
        // Add devices to map (automatically deduplicates by key)
        for (final device in foundDevices) {
          deviceMap[device.remoteId.str] = device;
        }
        return false; // Continue scanning
      },
    );
    return deviceMap.values.toList();
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
    required BluetoothDevice blDevice,
    required String ssid,
    required String password,
  }) async {
    final response = await _transport.sendCommand(
      blDevice: blDevice,
      command: FF1BleCommand.sendWifiCredentials,
      request: SendWifiCredentialsRequest(ssid: ssid, password: password),
      timeout: const Duration(
        seconds: 60,
      ), // Increased timeout for WiFi connection
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
    required BluetoothDevice blDevice,
  }) async {
    final response = await _transport.sendCommand(
      blDevice: blDevice,
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
    required BluetoothDevice blDevice,
  }) async {
    final response = await _transport.sendCommand(
      blDevice: blDevice,
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
  ///
  /// Note: When using this method directly, consider using ff1BleSendCommandProvider
  /// for automatic retry via Riverpod. This method no longer includes manual retry.
  Future<String> getInfo({
    required BluetoothDevice blDevice,
  }) async {
    final response = await _transport.sendCommand(
      blDevice: blDevice,
      command: FF1BleCommand.getInfo,
      request: const GetInfoRequest(),
    );

    if (response.isError) {
      throw FF1ResponseError.fromCode(response.errorCode);
    }

    return response.data.isNotEmpty ? response.data[0] : '';
  }

  /// Factory reset device
  Future<void> factoryReset({
    required BluetoothDevice blDevice,
  }) async {
    final response = await _transport.sendCommand(
      blDevice: blDevice,
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
    required BluetoothDevice blDevice,
    required String userId,
    required String title,
    required String apiKey,
  }) async {
    final response = await _transport.sendCommand(
      blDevice: blDevice,
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
    required BluetoothDevice blDevice,
    required String timezone,
    DateTime? time,
  }) async {
    await _transport.sendCommand(
      blDevice: blDevice,
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

final _ff1ScanLog = Logger('FF1ScanNotifier');

/// FF1 BLE scan state notifier
class FF1ScanNotifier extends Notifier<FF1ScanState> {
  FF1ScanNotifier();

  FF1BleControl get _control => ref.read(ff1ControlProvider);

  @override
  FF1ScanState build() {
    ref.onDispose(() {
      _ff1ScanLog.info('FF1ScanNotifier disposed');
    });

    return const FF1ScanState(isScanning: false, devices: []);
  }

  /// Start scanning for devices
  Future<void> startScan({
    Duration timeout = const Duration(seconds: 30),
  }) async {
    if (state.isScanning) return;

    state = state.copyWith(isScanning: true);

    try {
      final devices = await _control.scan(timeout: timeout);
      if (!ref.mounted) return;
      state = state.copyWith(isScanning: false, devices: devices);
    } catch (e) {
      if (!ref.mounted) return;
      _ff1ScanLog.severe('Failed to scan for devices', e);
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
final NotifierProvider<FF1ScanNotifier, FF1ScanState> ff1ScanProvider =
    NotifierProvider.autoDispose<FF1ScanNotifier, FF1ScanState>(
      FF1ScanNotifier.new,
    );

/// Parameters for BLE connection
class FF1BleConnectParams {
  const FF1BleConnectParams({
    required this.blDevice,
    this.timeout = const Duration(seconds: 30),
  });

  final BluetoothDevice blDevice;
  final Duration timeout;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FF1BleConnectParams &&
          runtimeType == other.runtimeType &&
          blDevice.remoteId.str == other.blDevice.remoteId.str &&
          timeout == other.timeout;

  @override
  int get hashCode => blDevice.remoteId.str.hashCode ^ timeout.hashCode;
}

/// Connect to FF1 device via BLE (auto-dispose, with retry).
///
/// This provider automatically disposes after use (BLE connect is one-time).
/// Uses Riverpod's automatic retry mechanism (3 attempts with exponential backoff).
///
/// Usage:
/// ```dart
/// await ref.read(
///   ff1BleConnectProvider(FF1BleConnectParams(device: device)).future,
/// );
/// ```
final FutureProviderFamily<void, FF1BleConnectParams> ff1BleConnectProvider =
    FutureProvider.autoDispose.family<void, FF1BleConnectParams>(
      retry: _bleRetry,
      (ref, params) async {
        final control = ref.watch(ff1ControlProvider);

        // Riverpod handles retry, so we set maxRetries to 0 in transport
        await control.connect(
          blDevice: params.blDevice,
          timeout: params.timeout,
          maxRetries: 0, // Riverpod handles retry
        );
      },
    );

/// Parameters for BLE command execution
class FF1BleCommandParams<T extends FF1BleRequest> {
  const FF1BleCommandParams({
    required this.blDevice,
    required this.command,
    required this.request,
    this.timeout = const Duration(seconds: 10),
  });

  final BluetoothDevice blDevice;
  final FF1BleCommand command;
  final T request;
  final Duration timeout;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FF1BleCommandParams<T> &&
          runtimeType == other.runtimeType &&
          blDevice.remoteId.str == other.blDevice.remoteId.str &&
          command == other.command &&
          timeout == other.timeout;

  @override
  int get hashCode =>
      blDevice.remoteId.str.hashCode ^ command.hashCode ^ timeout.hashCode;
}

/// Send BLE command to device (auto-dispose, with retry).
///
/// This provider automatically disposes after use.
/// Uses Riverpod's automatic retry mechanism.
///
/// Usage:
/// ```dart
/// final topicId = await ref.read(
///   ff1BleSendCommandProvider(FF1BleCommandParams(
///     device: device,
///     command: FF1BleCommand.sendWifiCredentials,
///     request: SendWifiCredentialsRequest(ssid: ssid, password: password),
///   )).future,
/// );
/// ```
final FutureProviderFamily<FF1BleResponse, FF1BleCommandParams<FF1BleRequest>>
ff1BleSendCommandProvider = FutureProvider.autoDispose
    .family<FF1BleResponse, FF1BleCommandParams>(
      retry: _bleRetry,
      (ref, params) async {
        final transport = ref.watch(ff1TransportProvider);

        return transport.sendCommand(
          blDevice: params.blDevice,
          command: params.command,
          request: params.request,
          timeout: params.timeout,
        );
      },
    );
