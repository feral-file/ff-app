/// FF1 WiFi Control: orchestrates WiFi communication and device state.
///
/// This is the control layer that:
/// - Manages connection lifecycle (connect, disconnect, auto-reconnect)
/// - Routes incoming notifications to appropriate handlers
/// - Maintains device state (player status, device status, connection)
/// - Provides high-level API for app layer (Riverpod providers)
///
/// Separation: Control layer is transport-independent.
/// It uses the abstract FF1WifiTransport interface,
/// so it works with any adapter (Relayer, LAN, etc.)
library;

import 'dart:async';

import 'package:app/domain/models/ff1_device.dart';
import 'package:app/infra/ff1/wifi_protocol/ff1_wifi_messages.dart';
import 'package:app/infra/ff1/wifi_transport/ff1_wifi_transport.dart';
import 'package:logging/logging.dart';

// ============================================================================
// WiFi Control (orchestration)
// ============================================================================

/// FF1 WiFi control: high-level orchestration of WiFi communication.
///
/// This class:
/// - Connects to devices via transport adapter
/// - Subscribes to notification stream
/// - Maintains device state (player status, device status)
/// - Exposes streams for state changes
/// - Handles auto-reconnect on app lifecycle changes
/// - Sends commands to devices via REST API
class FF1WifiControl {
  /// Creates FF1 WiFi control with given transport adapter and optional REST client.
  FF1WifiControl({
    required FF1WifiTransport transport,
    dynamic restClient,
    Logger? logger,
  }) : _transport = transport,
       _restClient = restClient,
       _log = logger ?? Logger('FF1WifiControl') {
    _startListening();
  }

  final FF1WifiTransport _transport;
  final dynamic _restClient;
  final Logger _log;

  // Stream controllers for state changes
  final _playerStatusController = StreamController<FF1PlayerStatus>.broadcast();
  final _deviceStatusController = StreamController<FF1DeviceStatus>.broadcast();
  final _connectionStatusController =
      StreamController<FF1ConnectionStatus>.broadcast();

  // Current device state
  FF1PlayerStatus? _currentPlayerStatus;
  FF1DeviceStatus? _currentDeviceStatus;
  bool _isDeviceConnected = false;

  // Stream subscriptions
  StreamSubscription<FF1NotificationMessage>? _notificationSub;
  StreamSubscription<bool>? _connectionStateSub;
  StreamSubscription<FF1WifiTransportError>? _errorSub;

  // Current device and auth (for reconnect)
  FF1Device? _device;
  String? _userId;
  String? _apiKey;

  /// Start listening to transport streams
  void _startListening() {
    // Listen to notification stream
    _notificationSub = _transport.notificationStream.listen(
      _handleNotification,
      onError: (Object e) {
        _log.warning('Notification stream error: $e');
      },
    );

    // Listen to connection state changes
    _connectionStateSub = _transport.connectionStateStream.listen(
      _handleConnectionStateChange,
      onError: (Object e) {
        _log.warning('Connection state stream error: $e');
      },
    );

    // Listen to transport errors
    _errorSub = _transport.errorStream.listen(
      _handleTransportError,
      onError: (Object e) {
        _log.warning('Error stream error: $e');
      },
    );
  }

  /// Connect to device
  ///
  /// [device] - FF1 device with topicId
  /// [userId] - user identifier for authentication
  /// [apiKey] - API key for authentication
  Future<void> connect({
    required FF1Device device,
    required String userId,
    required String apiKey,
  }) async {
    _device = device;
    _userId = userId;
    _apiKey = apiKey;

    _log.info('Connecting to ${device.deviceId}');

    try {
      await _transport.connect(
        device: device,
        userId: userId,
        apiKey: apiKey,
      );
    } catch (e) {
      _log.severe('Failed to connect: $e');
      rethrow;
    }
  }

  /// Disconnect from device
  Future<void> disconnect() async {
    _log.info('Disconnecting');

    await _transport.disconnect();

    // Clear cached connection params
    _device = null;
    _userId = null;
    _apiKey = null;

    // Clear current state
    _currentPlayerStatus = null;
    _currentDeviceStatus = null;
    _isDeviceConnected = false;
  }

  /// Check if transport is connected
  bool get isConnected => _transport.isConnected;

  /// Current player status (last received)
  FF1PlayerStatus? get currentPlayerStatus => _currentPlayerStatus;

  /// Current device status (last received)
  FF1DeviceStatus? get currentDeviceStatus => _currentDeviceStatus;

  /// Whether device is connected (per connection notification)
  bool get isDeviceConnected => _isDeviceConnected;

  /// Stream of player status updates
  Stream<FF1PlayerStatus> get playerStatusStream =>
      _playerStatusController.stream;

  /// Stream of device status updates
  Stream<FF1DeviceStatus> get deviceStatusStream =>
      _deviceStatusController.stream;

  /// Stream of connection status updates
  Stream<FF1ConnectionStatus> get connectionStatusStream =>
      _connectionStatusController.stream;

  /// Handle incoming notification from transport
  void _handleNotification(FF1NotificationMessage notification) {
    _log.fine('Notification: ${notification.notificationType}');

    switch (notification.notificationType) {
      case FF1NotificationType.playerStatus:
        final playerStatus = FF1PlayerStatus.fromJson(notification.message);
        _currentPlayerStatus = playerStatus;
        _playerStatusController.add(playerStatus);

      case FF1NotificationType.deviceStatus:
        final deviceStatus = FF1DeviceStatus.fromJson(notification.message);
        _currentDeviceStatus = deviceStatus;
        _deviceStatusController.add(deviceStatus);

      case FF1NotificationType.connection:
        final connectionStatus = FF1ConnectionStatus.fromJson(
          notification.message,
        );
        _isDeviceConnected = connectionStatus.isConnected;
        _connectionStatusController.add(connectionStatus);
    }
  }

  /// Handle connection state change from transport
  void _handleConnectionStateChange(bool isConnected) {
    _log.info('Connection state changed: $isConnected');

    if (!isConnected) {
      // if disconnected from transport
      // update connection status
      // Clear state on disconnect
      _currentPlayerStatus = null;
      _currentDeviceStatus = null;
      _isDeviceConnected = false;
      _connectionStatusController.add(
        FF1ConnectionStatus(isConnected: isConnected),
      );
    } else {
      // device connected to transport
      // connection status is already updated by _handleNotification
      // nothing to do
    }
  }

  /// Handle transport error
  void _handleTransportError(FF1WifiTransportError error) {
    _log.warning('Transport error: $error');
  }

  /// Reconnect to device (using cached connection params)
  ///
  /// Useful for app lifecycle changes (foreground/background)
  Future<void> reconnect() async {
    if (_device == null || _userId == null || _apiKey == null) {
      _log.warning('Cannot reconnect: no cached connection params');
      return;
    }

    _log.info('Reconnecting to ${_device!.deviceId}');

    try {
      await connect(
        device: _device!,
        userId: _userId!,
        apiKey: _apiKey!,
      );
    } catch (e) {
      _log.warning('Reconnect failed: $e');
      rethrow;
    }
  }

  /// Dispose control and clean up resources.
  void dispose() {
    _log.info('Disposing WiFi control');

    unawaited(_notificationSub?.cancel());
    unawaited(_connectionStateSub?.cancel());
    unawaited(_errorSub?.cancel());

    unawaited(_playerStatusController.close());
    unawaited(_deviceStatusController.close());
    unawaited(_connectionStatusController.close());

    _transport.dispose();
  }

  // =========================================================================
  // Command Methods (send commands to device via REST API)
  // =========================================================================

  /// Send rotate command to the device.
  ///
  /// [topicId] — device identifier on the relayer
  /// [angle] — rotation angle in degrees (default 90)
  Future<FF1CommandResponse> rotate({
    required String topicId,
    int angle = 90,
  }) async {
    if (_restClient == null) {
      throw StateError('REST client not available');
    }

    try {
      _log.info('Sending rotate command (angle: $angle) to device');

      final request = FF1WifiRotateRequest(angle: angle);
      final response =
          await _restClient.sendCommand(
                topicId: topicId,
                command: request.command,
                params: request.params,
              )
              as Map<String, dynamic>;

      return FF1CommandResponse.fromJson(response);
    } catch (e) {
      _log.severe('Failed to send rotate command: $e');
      rethrow;
    }
  }

  /// Send pause command to the device.
  ///
  /// [topicId] — device identifier on the relayer
  Future<FF1CommandResponse> pause({required String topicId}) async {
    if (_restClient == null) {
      throw StateError('REST client not available');
    }

    try {
      _log.info('Sending pause command to device');

      final request = const FF1WifiPauseRequest();
      final response =
          await _restClient.sendCommand(
                topicId: topicId,
                command: request.command,
                params: request.params,
              )
              as Map<String, dynamic>;

      return FF1CommandResponse.fromJson(response);
    } catch (e) {
      _log.severe('Failed to send pause command: $e');
      rethrow;
    }
  }

  /// Send play/resume command to the device.
  ///
  /// [topicId] — device identifier on the relayer
  Future<FF1CommandResponse> play({required String topicId}) async {
    if (_restClient == null) {
      throw StateError('REST client not available');
    }

    try {
      _log.info('Sending play command to device');

      final request = const FF1WifiPlayRequest();
      final response =
          await _restClient.sendCommand(
                topicId: topicId,
                command: request.command,
                params: request.params,
              )
              as Map<String, dynamic>;

      return FF1CommandResponse.fromJson(response);
    } catch (e) {
      _log.severe('Failed to send play command: $e');
      rethrow;
    }
  }

  /// Send next artwork command to the device.
  ///
  /// [topicId] — device identifier on the relayer
  Future<FF1CommandResponse> nextArtwork({required String topicId}) async {
    if (_restClient == null) {
      throw StateError('REST client not available');
    }

    try {
      _log.info('Sending nextArtwork command to device');

      final request = const FF1WifiNextArtworkRequest();
      final response =
          await _restClient.sendCommand(
                topicId: topicId,
                command: request.command,
                params: request.params,
              )
              as Map<String, dynamic>;

      return FF1CommandResponse.fromJson(response);
    } catch (e) {
      _log.severe('Failed to send nextArtwork command: $e');
      rethrow;
    }
  }

  /// Send previous artwork command to the device.
  ///
  /// [topicId] — device identifier on the relayer
  Future<FF1CommandResponse> previousArtwork({required String topicId}) async {
    if (_restClient == null) {
      throw StateError('REST client not available');
    }

    try {
      _log.info('Sending previousArtwork command to device');

      final request = const FF1WifiPreviousArtworkRequest();
      final response =
          await _restClient.sendCommand(
                topicId: topicId,
                command: request.command,
                params: request.params,
              )
              as Map<String, dynamic>;

      return FF1CommandResponse.fromJson(response);
    } catch (e) {
      _log.severe('Failed to send previousArtwork command: $e');
      rethrow;
    }
  }

  /// Show or hide pairing QR code on device.
  ///
  /// [topicId] — device topic ID
  /// [show] — true to show QR code, false to hide it
  ///
  /// Returns command response.
  Future<FF1CommandResponse> showPairingQRCode({
    required String topicId,
    required bool show,
  }) async {
    if (_restClient == null) {
      throw StateError('REST client not available');
    }

    try {
      _log.info('Sending showPairingQRCode($show) command to device');

      final request = FF1WifiShowPairingQRCodeRequest(show: show);
      final response =
          await _restClient.sendCommand(
                topicId: topicId,
                command: request.command,
                params: request.params,
              )
              as Map<String, dynamic>;

      return FF1CommandResponse.fromJson(response);
    } catch (e) {
      _log.severe('Failed to send showPairingQRCode command: $e');
      rethrow;
    }
  }
}
