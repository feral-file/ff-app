import 'dart:async';
import 'dart:io';

import 'package:app/domain/models/ff1_error.dart';
import 'package:app/infra/ff1/ble_protocol/ff1_ble_commands.dart';
import 'package:app/infra/ff1/ble_protocol/ff1_ble_protocol.dart';
import 'package:app/infra/logging/log_sanitizer.dart';
import 'package:app/infra/logging/structured_logger.dart';
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
  /// Creates a BLE transport and starts listening to BLE lifecycle events.
  FF1BleTransport({
    FF1BleProtocol? protocol,
    Logger? logger,
  }) : _protocol = protocol ?? const FF1BleProtocol(),
       _structuredLog = AppStructuredLog.forLogger(
         logger ?? Logger('FF1BleTransport'),
         context: {
           'layer': 'ff1',
           'component': 'ble_transport',
         },
       ) {
    _startListening();
  }

  final FF1BleProtocol _protocol;
  final StructuredLogger _structuredLog;

  /// FF1 service UUID.
  static const String serviceUuid = 'f7826da6-4fa2-4e98-8024-bc5b71e0893e';

  /// Command/Wi-Fi characteristic UUID used for app/device communication.
  static const String commandCharUuid = '6e400002-b5a3-f393-e0a9-e50e24dcca9e';

  static const List<Duration> _discoveryTimeouts = [
    Duration(seconds: 10),
    Duration(seconds: 15),
    Duration(seconds: 20),
  ];

  static const Duration _discoveryStabilizationDelay = Duration(seconds: 2);
  static const Duration _discoveryRetryDelay = Duration(seconds: 1);
  static const Duration _waitUntilReadyRetryDelay = Duration(milliseconds: 300);

  // Characteristic cache (remoteId -> characteristic)
  final Map<String, BluetoothCharacteristic> _characteristics = {};

  // Response callbacks (replyId -> callback)
  final Map<String, void Function(FF1BleResponse)> _responseCallbacks = {};

  // Active connect attempt tracking (used to ignore stale async work).
  int _connectAttemptSequence = 0;
  int? _activeConnectAttemptId;
  String? _activeConnectDeviceId;

  /// Start listening to flutter_blue_plus events
  void _startListening() {
    // Connection state changes
    FlutterBluePlus.events.onConnectionStateChanged.listen((event) async {
      final device = event.device;
      final state = event.connectionState;

      _structuredLog.info(
        category: LogCategory.ble,
        event: 'connection_state_changed',
        message: 'connection state ${state.name}',
        entityId: device.remoteId.str,
        payload: {
          'deviceId': device.remoteId.str,
          'state': state.name,
        },
      );

      if (state == BluetoothConnectionState.connected) {
        _structuredLog.info(
          category: LogCategory.ble,
          event: 'connect_established',
          message: 'connect established for ${device.remoteId.str}',
          entityId: device.remoteId.str,
        );
      } else if (state == BluetoothConnectionState.disconnected) {
        _characteristics.remove(device.remoteId.str);

        _structuredLog.warning(
          category: LogCategory.ble,
          event: 'device_disconnected',
          message: 'device disconnected',
          entityId: device.remoteId.str,
          payload: {
            'deviceId': device.remoteId.str,
            'disconnectReason': device.disconnectReason?.toString(),
          },
        );
      }
    });

    // Characteristic notifications
    FlutterBluePlus.events.onCharacteristicReceived.listen((event) {
      final characteristic = event.characteristic;
      final value = event.value;

      if (characteristic.uuid.toString() == commandCharUuid) {
        _structuredLog.info(
          category: LogCategory.ble,
          event: 'characteristic_notify_received',
          message: 'notification received ${value.length} bytes',
          entityId: characteristic.device.remoteId.str,
          payload: {
            'characteristic': characteristic.uuid.toString(),
            'payload': LogSanitizer.sanitizeBlePayload(value),
          },
        );
        _handleResponse(value);
      }
    });

    // Services reset (Android reconnection)
    FlutterBluePlus.events.onServicesReset.listen((event) {
      _structuredLog.info(
        category: LogCategory.ble,
        event: 'services_reset',
        message: 'services reset',
        entityId: event.device.remoteId.str,
        payload: {
          'deviceId': event.device.remoteId.str,
        },
      );
      unawaited(_rediscoverAfterServicesReset(event.device));
    });
  }

  Future<void> _rediscoverAfterServicesReset(BluetoothDevice device) async {
    try {
      await _discoverCharacteristics(device);
    } on Object catch (e, stack) {
      _structuredLog.warning(
        category: LogCategory.ble,
        event: 'services_reset_rediscovery_failed',
        message: 'service rediscovery after reset failed',
        entityId: device.remoteId.str,
        error: e,
        stackTrace: stack,
      );
    }
  }

  /// Connect to an FF1 device
  ///
  /// [blDevice] - FF1 device to connect to
  /// [timeout] - connection timeout
  /// [maxRetries] - max connection attempts (default 0 with Riverpod retry).
  /// [shouldContinue] - optional callback that gates whether connect continues.
  ///
  /// Note: When using Riverpod's automatic retry, set maxRetries to 0.
  /// Riverpod will handle retries with proper exponential backoff.
  Future<void> connect({
    required BluetoothDevice blDevice,
    Duration timeout = const Duration(seconds: 30),
    int maxRetries = 0,
    bool Function()? shouldContinue,
  }) async {
    // Check if operation should continue (for cancellation)
    if (shouldContinue != null && !shouldContinue()) {
      _structuredLog.info(
        category: LogCategory.ble,
        event: 'connect_cancelled',
        message: 'connection cancelled by caller',
        entityId: blDevice.remoteId.str,
      );
      throw const FF1ConnectionCancelledError();
    }

    if (maxRetries == 0) {
      // Single attempt - Riverpod handles retry
      _structuredLog.info(
        category: LogCategory.ble,
        event: 'connect_started',
        message: 'connect started for ${blDevice.advName}',
        entityId: blDevice.remoteId.str,
      );

      try {
        await _connectOnce(blDevice, timeout: timeout);
        _structuredLog.info(
          category: LogCategory.ble,
          event: 'connect_succeeded',
          message: 'connect succeeded for ${blDevice.advName}',
          entityId: blDevice.remoteId.str,
        );
      } on Object catch (e) {
        if (e is FF1ConnectionCancelledError) {
          rethrow;
        }
        await blDevice.disconnect();
        _structuredLog.warning(
          category: LogCategory.ble,
          event: 'connect_failed',
          message: 'connect failed for ${blDevice.advName}',
          entityId: blDevice.remoteId.str,
          error: e,
        );
        rethrow;
      }
    } else {
      // Manual retry logic (legacy, for backwards compatibility)
      for (var attempt = 0; attempt <= maxRetries; attempt++) {
        if (shouldContinue != null && !shouldContinue()) {
          _structuredLog.info(
            category: LogCategory.ble,
            event: 'connect_cancelled',
            message: 'connection cancelled by caller',
            entityId: blDevice.remoteId.str,
          );
          throw const FF1ConnectionCancelledError();
        }

        try {
          _structuredLog.info(
            category: LogCategory.ble,
            event: 'connect_started',
            message: 'connect started for ${blDevice.advName}',
            entityId: blDevice.remoteId.str,
            payload: {
              'attempt': attempt + 1,
              'maxAttempts': maxRetries + 1,
            },
          );

          await _connectOnce(blDevice, timeout: timeout);

          _structuredLog.info(
            category: LogCategory.ble,
            event: 'connect_succeeded',
            message: 'connect succeeded for ${blDevice.advName}',
            entityId: blDevice.remoteId.str,
            payload: {
              'attempt': attempt + 1,
            },
          );
          return;
        } on Object catch (e) {
          if (e is FF1ConnectionCancelledError) {
            rethrow;
          }

          await blDevice.disconnect();

          if (attempt >= maxRetries) {
            _structuredLog.error(
              event: 'connect_failed',
              message:
                  'connect failed after ${attempt + 1} attempts '
                  'for ${blDevice.advName}',
              error: e,
              payload: {
                'attempts': attempt + 1,
                'maxAttempts': maxRetries + 1,
              },
              entityId: blDevice.remoteId.str,
            );
            rethrow;
          }

          _structuredLog.info(
            category: LogCategory.ble,
            event: 'connect_retry_scheduled',
            message: 'connect retry scheduled after delay',
            entityId: blDevice.remoteId.str,
            payload: {
              'attempt': attempt + 1,
              'maxRetries': maxRetries,
            },
          );
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
    final attemptId = ++_connectAttemptSequence;
    _activeConnectAttemptId = attemptId;
    _activeConnectDeviceId = device.remoteId.str;

    if (device.isConnected) {
      final cached = _characteristics[device.remoteId.str];
      if (cached != null) {
        _structuredLog.info(
          category: LogCategory.ble,
          event: 'connect_skipped_already_connected',
          message: 'device already connected',
          entityId: device.remoteId.str,
        );
        return;
      }

      _structuredLog.info(
        category: LogCategory.ble,
        event: 'connect_connected_missing_characteristic',
        message: 'device connected but characteristic missing, rediscovering',
        entityId: device.remoteId.str,
      );

      await _discoverCharacteristics(device, attemptId: attemptId);
      return;
    }

    try {
      await device.disconnect();
      await Future<void>.delayed(const Duration(milliseconds: 1000));

      // Note: flutter_blue_plus 2.x requires explicit license acknowledgment
      await device.connect(
        timeout: timeout,
        mtu: null,
        // Using free license for individuals/nonprofits/education/small orgs.
        license: License.free,
      );

      await _discoverCharacteristics(device, attemptId: attemptId).timeout(
        timeout,
        onTimeout: () => throw TimeoutException('Connection timeout'),
      );
    } on Object {
      rethrow;
    }
  }

  /// Discover GATT characteristics for an FF1 device
  Future<void> _discoverCharacteristics(
    BluetoothDevice device, {
    int? attemptId,
  }) async {
    _characteristics.remove(device.remoteId.str);

    for (var i = 0; i < _discoveryTimeouts.length; i++) {
      try {
        _assertAttemptIsCurrent(device: device, attemptId: attemptId);

        _structuredLog.info(
          category: LogCategory.ble,
          event: 'service_discovery_attempt',
          message: 'discovering services',
          entityId: device.remoteId.str,
          payload: {
            'attempt': i + 1,
            'maxAttempts': _discoveryTimeouts.length,
          },
        );

        await Future<void>.delayed(_discoveryStabilizationDelay);
        _assertAttemptIsCurrent(device: device, attemptId: attemptId);

        if (device.isDisconnected) {
          throw FF1DisconnectedError(disconnectReason: device.disconnectReason);
        }

        final services = await device.discoverServices(
          timeout: _discoveryTimeouts[i].inSeconds,
        );

        _assertAttemptIsCurrent(device: device, attemptId: attemptId);

        _structuredLog.info(
          category: LogCategory.ble,
          event: 'services_found',
          message: 'found ${services.length} services',
          entityId: device.remoteId.str,
          payload: {'servicesCount': services.length},
        );

        // Find FF1 service by UUID
        final ff1Service = services.firstWhereOrNull(
          (s) => s.uuid.toString() == serviceUuid,
        );
        if (ff1Service == null) {
          _structuredLog.warning(
            category: LogCategory.ble,
            event: 'ff1_service_not_found',
            message: 'FF1 service not found',
            entityId: device.remoteId.str,
            payload: {
              'expectedServiceUuid': serviceUuid,
              'availableServiceUuids': services
                  .map((s) => s.uuid.toString())
                  .toList(),
            },
          );
          throw Exception('FF1 service not found');
        }

        _structuredLog.info(
          category: LogCategory.ble,
          event: 'ff1_service_found',
          message: 'FF1 service found',
          entityId: device.remoteId.str,
          payload: {
            'serviceUuid': ff1Service.uuid.toString(),
          },
        );

        // Find command characteristic
        final commandChar = ff1Service.characteristics.firstWhereOrNull(
          (c) => c.uuid.toString() == commandCharUuid,
        );
        if (commandChar == null) {
          throw Exception('Command characteristic not found');
        }

        // Enable notifications
        if (!commandChar.properties.notify) {
          throw Exception(
            'Command characteristic does not support notifications',
          );
        }

        await commandChar.setNotifyValue(true);
        _assertAttemptIsCurrent(device: device, attemptId: attemptId);

        // Cache characteristic
        _characteristics[device.remoteId.str] = commandChar;

        _structuredLog.info(
          category: LogCategory.ble,
          event: 'characteristic_discovery_succeeded',
          message: 'characteristics discovered',
          entityId: device.remoteId.str,
          payload: {
            'characteristicUuid': commandChar.uuid.toString(),
          },
        );
        return;
      } on Object catch (e) {
        _structuredLog.warning(
          category: LogCategory.ble,
          event: 'service_discovery_attempt_failed',
          message: 'service discovery attempt failed',
          entityId: device.remoteId.str,
          error: e,
          payload: {
            'attempt': i + 1,
            'maxAttempts': _discoveryTimeouts.length,
          },
        );

        if (i == _discoveryTimeouts.length - 1) {
          rethrow;
        }

        if (e is FF1ConnectionCancelledError ||
            e is FF1DisconnectedError ||
            (e is FlutterBluePlusException && e.code == 6)) {
          rethrow;
        }

        if (Platform.isAndroid) {
          await device.clearGattCache();
        }

        await Future<void>.delayed(_discoveryRetryDelay);
      }
    }
  }

  /// Disconnect from device
  Future<void> disconnect(BluetoothDevice blDevice) async {
    await blDevice.disconnect();
    _characteristics.remove(blDevice.remoteId.str);
  }

  void _assertAttemptIsCurrent({
    required BluetoothDevice device,
    required int? attemptId,
  }) {
    if (attemptId == null) {
      return;
    }

    if (_activeConnectAttemptId != attemptId ||
        _activeConnectDeviceId != device.remoteId.str) {
      throw const FF1ConnectionCancelledError();
    }
  }

  /// Wait until command characteristic is ready for command send.
  Future<void> waitUntilReady({
    required BluetoothDevice blDevice,
    Duration timeout = const Duration(seconds: 20),
  }) async {
    final deadline = DateTime.now().add(timeout);

    while (DateTime.now().isBefore(deadline)) {
      if (blDevice.isDisconnected) {
        throw FF1DisconnectedError(disconnectReason: blDevice.disconnectReason);
      }

      if (_characteristics.containsKey(blDevice.remoteId.str)) {
        return;
      }

      final remaining = deadline.difference(DateTime.now());
      if (remaining <= Duration.zero) {
        break;
      }

      try {
        await _discoverCharacteristics(blDevice).timeout(remaining);
      } on FF1DisconnectedError {
        rethrow;
      } on TimeoutException {
        break;
      } on Object {
        // Discovery can fail transiently right after connect.
      }

      await Future<void>.delayed(_waitUntilReadyRetryDelay);
    }

    throw TimeoutException('BLE characteristic readiness timeout');
  }

  /// Scan for FF1 devices
  ///
  /// [timeout] - scan duration
  /// [onDevice] - callback for each discovered device; return true to stop.
  Future<void> scan({
    required FutureOr<bool> Function(List<BluetoothDevice>) onDevice,
    Duration timeout = const Duration(seconds: 30),
  }) async {
    _structuredLog.info(
      category: LogCategory.ble,
      event: 'scan_started',
      message: 'scan started',
      payload: {
        'timeoutSeconds': timeout.inSeconds,
      },
    );

    await FlutterBluePlus.stopScan();
    await Future<void>.delayed(const Duration(milliseconds: 500));

    // Check already-connected devices
    final connectedDevices = FlutterBluePlus.connectedDevices;
    if (await onDevice(connectedDevices)) {
      _structuredLog.info(
        category: LogCategory.ble,
        event: 'scan_device_found',
        message: 'device found in connected devices',
        payload: {
          'connectedDeviceCount': connectedDevices.length,
        },
      );
      return;
    }

    // Start BLE scan
    final subscription = FlutterBluePlus.onScanResults.listen((results) async {
      final devices = results.map((r) => r.device).toList();
      final shouldStop = await onDevice([...devices, ...connectedDevices]);

      if (shouldStop) {
        _structuredLog.info(
          category: LogCategory.ble,
          event: 'scan_stopped',
          message: 'scan stopped after device found',
          payload: {
            'scanResultCount': devices.length,
          },
        );
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

    _structuredLog.info(
      category: LogCategory.ble,
      event: 'scan_completed',
      message: 'scan complete',
    );
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
  /// [blDevice] - target FF1 device
  /// [command] - command to send
  /// [request] - request parameters
  /// [timeout] - response timeout
  Future<FF1BleResponse> sendCommand({
    required BluetoothDevice blDevice,
    required FF1BleCommand command,
    required FF1BleRequest request,
    Duration timeout = const Duration(seconds: 10),
  }) async {
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
      final char = _characteristics[blDevice.remoteId.str];
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
      _structuredLog.info(
        category: LogCategory.ble,
        event: 'characteristic_write',
        message: 'characteristic write',
        entityId: char.device.remoteId.str,
        payload: {
          'characteristic': char.uuid.toString(),
          'payload': LogSanitizer.sanitizeBlePayload(value),
        },
      );
      await char.write(value);
    } on Object catch (e) {
      _structuredLog.warning(
        category: LogCategory.ble,
        event: 'characteristic_write_failed',
        message: 'characteristic write failed, retrying',
        entityId: char.device.remoteId.str,
        error: e,
      );

      if (e is FlutterBluePlusException && _canIgnoreError(e)) {
        _structuredLog.info(
          category: LogCategory.ble,
          event: 'characteristic_write_ignored_error',
          message: 'ignored write error code ${e.code}',
          entityId: char.device.remoteId.str,
          payload: {'errorCode': e.code},
        );
        return;
      }

      final device = char.device;
      final isDataTooLong = e.toString().contains('data longer than allowed');

      // Wait a bit before retry to let connection stabilize
      await Future<void>.delayed(const Duration(milliseconds: 500));

      if (device.isConnected) {
        if (!isDataTooLong) {
          _structuredLog.info(
            category: LogCategory.ble,
            event: 'service_rediscovery_started',
            message: 'rediscovering services after write failure',
            entityId: char.device.remoteId.str,
          );
          await device.discoverServices();

          // Wait for services to be discovered
          await Future<void>.delayed(const Duration(milliseconds: 500));
        }

        try {
          await char.write(value, allowLongWrite: isDataTooLong);
        } on Object catch (e2) {
          if (e2 is FlutterBluePlusException && _canIgnoreError(e2)) {
            _structuredLog.info(
              category: LogCategory.ble,
              event: 'characteristic_write_ignored_error',
              message: 'ignored write retry error code ${e2.code}',
              entityId: char.device.remoteId.str,
              payload: {'errorCode': e2.code},
            );
            return;
          }
          _structuredLog.error(
            event: 'characteristic_write_failed',
            message: 'write failed after retry',
            error: e2,
            entityId: char.device.remoteId.str,
          );
          rethrow;
        }
      } else {
        _structuredLog.error(
          event: 'characteristic_write_failed',
          message: 'device disconnected, cannot retry write',
          entityId: char.device.remoteId.str,
        );
        rethrow;
      }
    }
  }

  bool _canIgnoreError(FlutterBluePlusException e) {
    return e.code == 14 ||
        e.code == 133 ||
        (e.description?.contains('GATT') ?? false);
  }

  /// Handle incoming response notification
  void _handleResponse(List<int> bytes) {
    try {
      final response = _protocol.parseResponse(bytes);
      _structuredLog.info(
        category: LogCategory.ble,
        event: 'response_received',
        message: 'response received',
        payload: {
          'topic': response.topic,
          'payload': LogSanitizer.sanitizeBlePayload(bytes),
        },
      );

      final callback = _responseCallbacks[response.topic];
      if (callback != null) {
        callback(response);
      } else {
        _structuredLog.warning(
          category: LogCategory.ble,
          event: 'response_unhandled',
          message: 'no callback for topic ${response.topic}',
          payload: {
            'topic': response.topic,
          },
        );
      }
    } on Object catch (e) {
      _structuredLog.warning(
        category: LogCategory.ble,
        event: 'response_parse_failed',
        message: 'failed to parse response',
        error: e,
      );
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
