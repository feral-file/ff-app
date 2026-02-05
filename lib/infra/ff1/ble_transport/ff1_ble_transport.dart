import 'dart:async';
import 'dart:io';

import 'package:app/domain/models/ff1_device.dart';
import 'package:app/domain/models/ff1_error.dart';
import 'package:app/infra/ff1/ble_protocol/ff1_ble_commands.dart';
import 'package:app/infra/ff1/ble_protocol/ff1_ble_protocol.dart';
import 'package:collection/collection.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:logging/logging.dart';

/// FF1 Bluetooth Low Energy Transport: handles BLE connection, scanning, and I/O
///
/// This is the transport layer for FF1 BLE communication. It:
/// - Manages BLE connection lifecycle (connect, disconnect, scan)
/// - Discovers GATT services and characteristics
/// - Sends commands and receives notifications
/// - Routes responses to callbacks via reply ID subscription
///
/// Separation: Transport handles BLE operations. Protocol handles encoding/decoding.
/// Control layer (in app/) orchestrates commands using this transport.
class FF1BleTransport {
  FF1BleTransport({
    FF1BleProtocol? protocol,
    Logger? logger,
  })  : _protocol = protocol ?? const FF1BleProtocol(),
        _log = logger ?? Logger('FF1BleTransport') {
    _startListening();
  }

  final FF1BleProtocol _protocol;
  final Logger _log;

  // FF1 Service UUID
  static const String serviceUuid = 'f7826da6-4fa2-4e98-8024-bc5b71e0893e';

  // Command/WiFi characteristic UUID (used for all app<->device communication)
  static const String commandCharUuid = '6e400002-b5a3-f393-e0a9-e50e24dcca9e';

  // Characteristic cache (remoteId -> characteristic)
  final Map<String, BluetoothCharacteristic> _characteristics = {};

  // Response callbacks (replyId -> callback)
  final Map<String, void Function(FF1BleResponse)> _responseCallbacks = {};

  // Connection completer (for waiting on connection + service discovery)
  Completer<void>? _connectCompleter;

  /// Start listening to flutter_blue_plus events
  void _startListening() {
    // Connection state changes
    FlutterBluePlus.events.onConnectionStateChanged.listen((event) async {
      final device = event.device;
      final state = event.connectionState;

      _log.info('Connection state: ${device.remoteId.str} -> ${state.name}');

      if (state == BluetoothConnectionState.connected) {
        try {
          // Wait for connection to stabilize
          _log.info('Connection established, stabilizing...');
          await Future<void>.delayed(const Duration(seconds: 2));

          // Discover characteristics
          _log.info('Starting service discovery...');
          await _discoverCharacteristics(device);

          // Complete connection
          if (_connectCompleter?.isCompleted == false) {
            _connectCompleter?.complete();
          }
          _connectCompleter = null;
        } catch (e) {
          _log.warning('Failed to discover characteristics: $e');
          if (_connectCompleter?.isCompleted == false) {
            _connectCompleter?.completeError(e);
          }
          _connectCompleter = null;
          await device.disconnect();
        }
      } else if (state == BluetoothConnectionState.disconnected) {
        _log.warning('Device disconnected: ${device.disconnectReason}');
        if (_connectCompleter?.isCompleted == false) {
          _connectCompleter?.completeError(
            FF1DisconnectedError(disconnectReason: device.disconnectReason),
          );
        }
      }
    });

    // Characteristic notifications
    FlutterBluePlus.events.onCharacteristicReceived.listen((event) {
      final characteristic = event.characteristic;
      final value = event.value;

      if (characteristic.uuid.toString() == commandCharUuid) {
        _log.fine('Received notification: ${value.length} bytes');
        _handleResponse(value);
      }
    });

    // Services reset (Android reconnection)
    FlutterBluePlus.events.onServicesReset.listen((event) {
      _log.info('Services reset: ${event.device.remoteId.str}');
      event.device.discoverServices();
    });
  }

  /// Connect to an FF1 device
  ///
  /// [device] - FF1 device to connect to
  /// [timeout] - connection timeout
  /// [maxRetries] - max connection attempts (default 0 when using Riverpod retry)
  /// [shouldContinue] - optional callback to check if connection should continue
  /// 
  /// Note: When using Riverpod's automatic retry, set maxRetries to 0.
  /// Riverpod will handle retries with proper exponential backoff.
  Future<void> connect({
    required FF1Device device,
    Duration timeout = const Duration(seconds: 30),
    int maxRetries = 0,
    bool Function()? shouldContinue,
  }) async {
    final blDevice = device.toBluetoothDevice();

    // Check if operation should continue (for cancellation)
    if (shouldContinue != null && !shouldContinue()) {
      _log.info('Connection cancelled by caller');
      throw const FF1ConnectionCancelledError();
    }

    if (maxRetries == 0) {
      // Single attempt - Riverpod handles retry
      _log.info('Connecting to ${device.deviceId}');
      
      try {
        await _connectOnce(blDevice, timeout: timeout);
        _log.info('Connected to ${device.deviceId}');
      } catch (e) {
        if (e is FF1ConnectionCancelledError) {
          rethrow;
        }
        await blDevice.disconnect();
        _log.warning('Connection failed: $e');
        rethrow;
      }
    } else {
      // Manual retry logic (legacy, for backwards compatibility)
      for (var attempt = 0; attempt <= maxRetries; attempt++) {
        if (shouldContinue != null && !shouldContinue()) {
          _log.info('Connection cancelled by caller');
          throw const FF1ConnectionCancelledError();
        }

        try {
          _log.info(
            'Connecting to ${device.deviceId} (attempt ${attempt + 1}/${maxRetries + 1})',
          );

          await _connectOnce(blDevice, timeout: timeout);

          _log.info('Connected to ${device.deviceId}');
          return;
        } catch (e) {
          if (e is FF1ConnectionCancelledError) {
            rethrow;
          }

          await blDevice.disconnect();

          if (attempt >= maxRetries) {
            _log.severe('Failed after ${attempt + 1} attempts: $e');
            rethrow;
          }

          _log.info('Retry ${attempt + 1}/${maxRetries} after 2s...');
          await Future<void>.delayed(const Duration(seconds: 2));
        }
      }
    }
  }

  /// Single connection attempt
  Future<void> _connectOnce(
    BluetoothDevice device, {
    required Duration timeout,
  }) async {
    if (device.isConnected) {
      _log.fine('Already connected: ${device.remoteId.str}');
      return;
    }

    _connectCompleter = Completer<void>();

    try {
      await device.disconnect();
      await Future<void>.delayed(const Duration(milliseconds: 1000));

      // Note: flutter_blue_plus 2.x requires explicit license acknowledgment
      await device.connect(
        timeout: timeout,
        mtu: null,
        autoConnect: false,
        // Using free license (for individuals, nonprofits, educational, small orgs <50 employees)
        license: License.free,
      );

      // Wait for characteristic discovery to complete
      await _connectCompleter?.future.timeout(
        timeout,
        onTimeout: () {
          final error = TimeoutException('Connection timeout');
          if (_connectCompleter?.isCompleted == false) {
            _connectCompleter?.completeError(error);
          }
          _connectCompleter = null;
          throw error;
        },
      );
    } catch (e) {
      if (_connectCompleter?.isCompleted == false) {
        _connectCompleter?.completeError(e);
      }
      _connectCompleter = null;
      rethrow;
    }
  }

  /// Discover GATT characteristics for an FF1 device
  Future<void> _discoverCharacteristics(BluetoothDevice device) async {
    const timeouts = [
      Duration(seconds: 10),
      Duration(seconds: 15),
      Duration(seconds: 20),
    ];

    for (var i = 0; i < timeouts.length; i++) {
      try {
        _log.info('Discovering services (attempt ${i + 1}/${timeouts.length})');

        await Future<void>.delayed(const Duration(seconds: 2));
        final services = await device.discoverServices(
          timeout: timeouts[i].inSeconds,
        );

        _log.info('Found ${services.length} services on device');

        // Log all available services for debugging
        for (final service in services) {
          _log.info(
            'Service: ${service.uuid} '
            '(primary: ${service.isPrimary}, '
            'characteristics: ${service.characteristics.length})',
          );
        }

        // Find FF1 service by UUID
        final ff1Service = services.firstWhereOrNull(
          (s) => s.uuid.toString() == serviceUuid,
        );
        if (ff1Service == null) {
          _log.warning(
            'FF1 service not found. Looking for UUID: $serviceUuid',
          );
          _log.warning(
            'Available service UUIDs: '
            '${services.map((s) => s.uuid.toString()).join(", ")}',
          );
          throw Exception('FF1 service not found');
        }

        _log.info('Found FF1 service: ${ff1Service.uuid}');

        // Find command characteristic
        final commandChar = ff1Service.characteristics.firstWhereOrNull(
          (c) => c.uuid.toString() == commandCharUuid,
        );
        if (commandChar == null) {
          throw Exception('Command characteristic not found');
        }

        // Enable notifications
        if (!commandChar.properties.notify) {
          throw Exception('Command characteristic does not support notifications');
        }

        await commandChar.setNotifyValue(true);

        // Cache characteristic
        _characteristics[device.remoteId.str] = commandChar;

        _log.fine('Successfully discovered characteristics');
        return;
      } catch (e) {
        _log.warning('Discovery attempt ${i + 1} failed: $e');

        if (i == timeouts.length - 1) {
          rethrow;
        }

        if (Platform.isAndroid) {
          await device.clearGattCache();
        }

        await Future<void>.delayed(const Duration(seconds: 1));
      }
    }
  }

  /// Disconnect from device
  Future<void> disconnect(FF1Device device) async {
    final blDevice = device.toBluetoothDevice();
    await blDevice.disconnect();
    _characteristics.remove(device.remoteId);
  }

  /// Scan for FF1 devices
  ///
  /// [timeout] - scan duration
  /// [onDevice] - callback for each discovered device (return true to stop scan)
  Future<void> scan({
    Duration timeout = const Duration(seconds: 30),
    required FutureOr<bool> Function(List<BluetoothDevice>) onDevice,
  }) async {
    _log.info('Starting scan (timeout: ${timeout.inSeconds}s)');

    await FlutterBluePlus.stopScan();
    await Future<void>.delayed(const Duration(milliseconds: 500));

    // Check already-connected devices
    final connectedDevices = FlutterBluePlus.connectedDevices;
    if (await onDevice(connectedDevices)) {
      _log.info('Device found in connected devices');
      return;
    }

    // Start BLE scan
    final subscription = FlutterBluePlus.onScanResults.listen((results) async {
      final devices = results.map((r) => r.device).toList();
      final shouldStop = await onDevice([...devices, ...connectedDevices]);

      if (shouldStop) {
        _log.info('Device found, stopping scan');
        await FlutterBluePlus.stopScan();
      }
    });

    FlutterBluePlus.cancelWhenScanComplete(subscription);

    await FlutterBluePlus.startScan(
      timeout: timeout,
      withServices: [Guid(serviceUuid)],
    );

    // Wait for scan to complete
    while (FlutterBluePlus.isScanningNow) {
      await Future<void>.delayed(const Duration(milliseconds: 1000));
    }

    _log.info('Scan complete');
  }

  /// Scan for a device by name (deviceId shown on FF1 screen)
  Future<BluetoothDevice?> scanForName({
    required String name,
    Duration timeout = const Duration(seconds: 15),
  }) async {
    BluetoothDevice? foundDevice;

    await scan(
      timeout: timeout,
      onDevice: (devices) {
        final device = devices.firstWhereOrNull((d) => d.advName == name);
        if (device != null) {
          foundDevice = device;
          return true;
        }
        return false;
      },
    );

    return foundDevice;
  }

  /// Send a command to device and wait for response
  ///
  /// [device] - target FF1 device
  /// [command] - command to send
  /// [request] - request parameters
  /// [timeout] - response timeout
  Future<FF1BleResponse> sendCommand({
    required FF1Device device,
    required FF1BleCommand command,
    required FF1BleRequest request,
    Duration timeout = const Duration(seconds: 10),
  }) async {
    final blDevice = device.toBluetoothDevice();

    if (blDevice.isDisconnected) {
      throw const FF1BluetoothError('Device is disconnected');
    }

    final replyId = _protocol.generateReplyId();
    final bytes = _protocol.buildCommand(
      command: command.wireName,
      replyId: replyId,
      params: request.toParams(),
    );

    // Subscribe to response
    final completer = Completer<FF1BleResponse>();
    _responseCallbacks[replyId] = completer.complete;

    try {
      // Get characteristic
      final char = _characteristics[device.remoteId];
      if (char == null) {
        throw Exception('Command characteristic not found');
      }

      // Send command
      await _writeWithRetry(char, bytes);

      // Wait for response
      final response = await completer.future.timeout(
        timeout,
        onTimeout: () {
          throw TimeoutException('Command timeout: ${command.wireName}');
        },
      );

      return response;
    } finally {
      _responseCallbacks.remove(replyId);
    }
  }

  /// Write to characteristic with retry logic
  Future<void> _writeWithRetry(
    BluetoothCharacteristic char,
    List<int> value,
  ) async {
    try {
      await char.write(value);
    } catch (e) {
      _log.warning('Write failed, retrying: $e');

      if (e is FlutterBluePlusException && _canIgnoreError(e)) {
        _log.fine('Ignoring error code ${e.code}');
        return;
      }

      final device = char.device;
      final isDataTooLong = e.toString().contains('data longer than allowed');

      // Wait a bit before retry to let connection stabilize
      await Future<void>.delayed(const Duration(milliseconds: 500));

      if (device.isConnected) {
        if (!isDataTooLong) {
          _log.info('Rediscovering services after write failure...');
          await device.discoverServices();
          
          // Wait for services to be discovered
          await Future<void>.delayed(const Duration(milliseconds: 500));
        }

        try {
          await char.write(value, allowLongWrite: isDataTooLong);
        } catch (e2) {
          if (e2 is FlutterBluePlusException && _canIgnoreError(e2)) {
            _log.fine('Ignoring error code ${e2.code}');
            return;
          }
          _log.severe('Write failed after retry: $e2');
          rethrow;
        }
      } else {
        _log.severe('Device disconnected, cannot retry write');
        rethrow;
      }
    }
  }

  bool _canIgnoreError(FlutterBluePlusException e) {
    return e.code == 14 || e.code == 133 || (e.description?.contains('GATT') ?? false);
  }

  /// Handle incoming response notification
  void _handleResponse(List<int> bytes) {
    try {
      final response = _protocol.parseResponse(bytes);
      _log.fine('Response: $response');

      final callback = _responseCallbacks[response.topic];
      if (callback != null) {
        callback(response);
      } else {
        _log.warning('No callback for topic: ${response.topic}');
      }
    } catch (e) {
      _log.warning('Failed to parse response: $e');
    }
  }

  /// Get Bluetooth adapter state
  BluetoothAdapterState get adapterState => FlutterBluePlus.adapterStateNow;

  /// Check if Bluetooth is available
  Future<bool> get isSupported => FlutterBluePlus.isSupported;

  /// Listen to adapter state changes
  Stream<BluetoothAdapterState> get adapterStateStream =>
      FlutterBluePlus.adapterState;
}
