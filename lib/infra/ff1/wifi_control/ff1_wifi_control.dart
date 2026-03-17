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
import 'dart:ui' show Offset;

import 'package:app/domain/models/ff1/art_framing.dart';
import 'package:app/domain/models/ff1/canvas_cast_request_reply.dart';
import 'package:app/domain/models/ff1/loop_mode.dart';
import 'package:app/domain/models/ff1_device.dart';
import 'package:app/infra/ff1/wifi_protocol/ff1_wifi_messages.dart';
import 'package:app/infra/ff1/wifi_transport/ff1_wifi_transport.dart';
import 'package:logging/logging.dart';
import 'package:rxdart/rxdart.dart';

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
  final _playerStatusController = BehaviorSubject<FF1PlayerStatus>();
  final _deviceStatusController = BehaviorSubject<FF1DeviceStatus>();
  final _connectionStatusController = BehaviorSubject<FF1ConnectionStatus>();

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

  /// Check if transport is currently connecting
  bool get isConnecting => _transport.isConnecting;

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

      const request = FF1WifiPauseRequest();
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

  /// Send resume command to the device.
  ///
  /// [topicId] — device identifier on the relayer
  Future<FF1CommandResponse> resume({required String topicId}) async {
    if (_restClient == null) {
      throw StateError('REST client not available');
    }

    try {
      _log.info('Sending resume command to device');

      const request = FF1WifiResumeRequest();
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

      const request = FF1WifiNextArtworkRequest();
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

      const request = FF1WifiPreviousArtworkRequest();
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

  /// Move to artwork at [index] in the playlist (jump to item).
  ///
  /// [topicId] — device identifier on the relayer
  /// [index] — zero-based index of the artwork in the playlist
  Future<FF1CommandResponse> moveToArtwork({
    required String topicId,
    required int index,
  }) async {
    if (_restClient == null) {
      throw StateError('REST client not available');
    }

    try {
      _log.info('Sending moveToArtwork($index) to device');
      final request = FF1WifiMoveToArtworkRequest(index: index);
      final response =
          await _restClient.sendCommand(
                topicId: topicId,
                command: request.command,
                params: request.params,
              )
              as Map<String, dynamic>;
      return FF1CommandResponse.fromJson(response);
    } catch (e) {
      _log.severe('Failed to send moveToArtwork command: $e');
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

  /// Send update art framing (fit/fill) command to the device.
  ///
  /// [topicId] — device identifier on the relayer
  /// [framing] — ArtFraming.fitToScreen or ArtFraming.cropToFill
  Future<FF1CommandResponse> updateArtFraming({
    required String topicId,
    required ArtFraming framing,
  }) async {
    if (_restClient == null) {
      throw StateError('REST client not available');
    }

    try {
      _log.info('Sending updateArtFraming(${framing.name}) command to device');

      final request = FF1WifiUpdateArtFramingRequest(framing: framing);
      final response =
          await _restClient.sendCommand(
                topicId: topicId,
                command: request.command,
                params: request.params,
              )
              as Map<String, dynamic>;

      return FF1CommandResponse.fromJson(response);
    } catch (e) {
      _log.severe('Failed to send updateArtFraming command: $e');
      rethrow;
    }
  }

  /// Send keyboard event (key code) to the device.
  ///
  /// [topicId] — device identifier on the relayer
  /// [code] — key code (e.g. from [String.codeUnitAt])
  Future<FF1CommandResponse> keyboardEvent({
    required String topicId,
    required int code,
  }) async {
    if (_restClient == null) {
      throw StateError('REST client not available');
    }
    try {
      _log.info('Sending keyboardEvent($code) to device');
      final request = FF1WifiKeyboardEventRequest(code: code);
      final response =
          await _restClient.sendCommand(
                topicId: topicId,
                command: request.command,
                params: request.params,
              )
              as Map<String, dynamic>;
      return FF1CommandResponse.fromJson(response);
    } catch (e) {
      _log.severe('Failed to send keyboardEvent command: $e');
      rethrow;
    }
  }

  /// Send tap gesture to the device.
  Future<FF1CommandResponse> tap({required String topicId}) async {
    if (_restClient == null) {
      throw StateError('REST client not available');
    }
    try {
      _log.info('Sending tap to device');
      const request = FF1WifiTapRequest();
      final response =
          await _restClient.sendCommand(
                topicId: topicId,
                command: request.command,
                params: request.params,
              )
              as Map<String, dynamic>;
      return FF1CommandResponse.fromJson(response);
    } catch (e) {
      _log.severe('Failed to send tap command: $e');
      rethrow;
    }
  }

  /// Send drag gesture (cursor offsets) to the device.
  Future<FF1CommandResponse> drag({
    required String topicId,
    required List<Offset> cursorOffsets,
  }) async {
    if (_restClient == null) {
      throw StateError('REST client not available');
    }
    if (cursorOffsets.isEmpty) return FF1CommandResponse();
    try {
      _log.info('Sending drag(${cursorOffsets.length} offsets) to device');
      final request = FF1WifiDragRequest(
        cursorOffsets: cursorOffsets
            .map((o) => <String, double>{'dx': o.dx, 'dy': o.dy})
            .toList(),
      );
      final response =
          await _restClient.sendCommand(
                topicId: topicId,
                command: request.command,
                params: request.params,
              )
              as Map<String, dynamic>;
      return FF1CommandResponse.fromJson(response);
    } catch (e) {
      _log.severe('Failed to send drag command: $e');
      rethrow;
    }
  }

  /// Shutdown device.
  ///
  /// [topicId] — device topic ID
  Future<FF1CommandResponse> shutdown({required String topicId}) async {
    if (_restClient == null) {
      throw StateError('REST client not available');
    }

    try {
      _log.info('Sending shutdown command to device');

      const request = FF1WifiShutdownRequest();
      final response =
          await _restClient.sendCommand(
                topicId: topicId,
                command: request.command,
                params: request.params,
              )
              as Map<String, dynamic>;

      return FF1CommandResponse.fromJson(response);
    } catch (e) {
      _log.severe('Failed to send shutdown command: $e');
      rethrow;
    }
  }

  /// Reboot device.
  ///
  /// [topicId] — device topic ID
  Future<FF1CommandResponse> reboot({required String topicId}) async {
    if (_restClient == null) {
      throw StateError('REST client not available');
    }

    try {
      _log.info('Sending reboot command to device');

      const request = FF1WifiRebootRequest();
      final response =
          await _restClient.sendCommand(
                topicId: topicId,
                command: request.command,
                params: request.params,
              )
              as Map<String, dynamic>;

      return FF1CommandResponse.fromJson(response);
    } catch (e) {
      _log.severe('Failed to send reboot command: $e');
      rethrow;
    }
  }

  /// Factory reset device.
  ///
  /// [topicId] — device topic ID
  Future<FF1CommandResponse> factoryReset({required String topicId}) async {
    if (_restClient == null) {
      throw StateError('REST client not available');
    }

    try {
      _log.info('Sending factory reset command to device');

      const request = FF1WifiFactoryResetRequest();
      final response =
          await _restClient.sendCommand(
                topicId: topicId,
                command: request.command,
                params: request.params,
              )
              as Map<String, dynamic>;

      return FF1CommandResponse.fromJson(response);
    } catch (e) {
      _log.severe('Failed to send factory reset command: $e');
      rethrow;
    }
  }

  /// Send device logs to support.
  ///
  /// [topicId] — device topic ID
  /// [userId] — user identifier used by support backend
  /// [title] — optional log title
  /// [apiKey] — support API key
  Future<FF1CommandResponse> sendLog({
    required String topicId,
    required String userId,
    required String? title,
    required String apiKey,
  }) async {
    if (_restClient == null) {
      throw StateError('REST client not available');
    }

    try {
      _log.info('Sending sendLog command to device');

      final request = FF1WifiSendLogRequest(
        userId: userId,
        title: title,
        apiKey: apiKey,
      );
      final response =
          await _restClient.sendCommand(
                topicId: topicId,
                command: request.command,
                params: request.params,
                timeout: const Duration(seconds: 30),
              )
              as Map<String, dynamic>;

      return FF1CommandResponse.fromJson(response);
    } catch (e) {
      _log.severe('Failed to send sendLog command: $e');
      rethrow;
    }
  }

  /// Set the device volume.
  ///
  /// [topicId] — device identifier on the relayer
  /// [percent] — target volume level (0–100); values outside this range are
  ///   accepted by the method but may be rejected by the device firmware.
  Future<FF1CommandResponse> setVolume({
    required String topicId,
    required int percent,
  }) async {
    if (_restClient == null) {
      throw StateError('REST client not available');
    }

    try {
      _log.info('Sending setVolume($percent) command to device');

      final request = FF1WifiSetVolumeRequest(percent: percent);
      final response =
          await _restClient.sendCommand(
                topicId: topicId,
                command: request.command,
                params: request.params,
              )
              as Map<String, dynamic>;

      return FF1CommandResponse.fromJson(response);
    } catch (e) {
      _log.severe('Failed to send setVolume command: $e');
      rethrow;
    }
  }

  /// Enable or disable shuffle playback on the device.
  ///
  /// [topicId] — device identifier on the relayer
  /// [enabled] — true to enable shuffle, false to disable it
  Future<FF1CommandResponse> setShuffle({
    required String topicId,
    required bool enabled,
  }) async {
    if (_restClient == null) {
      throw StateError('REST client not available');
    }

    try {
      _log.info('Sending setShuffle($enabled) command to device');

      final request = FF1WifiShuffleRequest(enabled: enabled);
      final response =
          await _restClient.sendCommand(
                topicId: topicId,
                command: request.command,
                params: request.params,
              )
              as Map<String, dynamic>;

      return FF1CommandResponse.fromJson(response);
    } catch (e) {
      _log.severe('Failed to send setShuffle command: $e');
      rethrow;
    }
  }

  /// Set the loop (repeat) mode on the device.
  ///
  /// [topicId] — device identifier on the relayer
  /// [mode] — none, playlist, or one
  Future<FF1CommandResponse> setLoop({
    required String topicId,
    required LoopMode mode,
  }) async {
    if (_restClient == null) {
      throw StateError('REST client not available');
    }

    try {
      _log.info('Sending setLoop(${mode.wireValue}) command to device');

      final request = FF1WifiSetLoopRequest(mode: mode);
      final response =
          await _restClient.sendCommand(
                topicId: topicId,
                command: request.command,
                params: request.params,
              )
              as Map<String, dynamic>;

      return FF1CommandResponse.fromJson(response);
    } catch (e) {
      _log.severe('Failed to send setLoop command: $e');
      rethrow;
    }
  }

  /// Toggle mute state on the device.
  ///
  /// [topicId] — device identifier on the relayer
  Future<FF1CommandResponse> toggleMute({required String topicId}) async {
    if (_restClient == null) {
      throw StateError('REST client not available');
    }

    try {
      _log.info('Sending toggleMute command to device');

      const request = FF1WifiToggleMuteRequest();
      final response =
          await _restClient.sendCommand(
                topicId: topicId,
                command: request.command,
                params: request.params,
              )
              as Map<String, dynamic>;

      return FF1CommandResponse.fromJson(response);
    } catch (e) {
      _log.severe('Failed to send toggleMute command: $e');
      rethrow;
    }
  }

  /// Fetches realtime device metrics via relayer command channel.
  Future<DeviceRealtimeMetrics> getDeviceRealtimeMetrics({
    required String topicId,
  }) async {
    if (_restClient == null) {
      throw StateError('REST client not available');
    }

    try {
      const request = FF1WifiDeviceMetricsRequest();
      final response =
          await _restClient.sendCommand(
                topicId: topicId,
                command: request.command,
                params: request.params,
              )
              as Map<String, dynamic>;
      final payload = _unwrapMetricsPayload(response);
      return DeviceRealtimeMetrics.fromJson(payload);
    } catch (e) {
      _log.severe('Failed to fetch realtime metrics: $e');
      rethrow;
    }
  }
}

Map<String, dynamic> _unwrapMetricsPayload(Map<String, dynamic> response) {
  dynamic current = response;
  while (current is Map<String, dynamic>) {
    if (current.containsKey('message') && current['message'] is Map) {
      current = Map<String, dynamic>.from(current['message'] as Map);
      continue;
    }
    if (current.containsKey('data') && current['data'] is Map) {
      current = Map<String, dynamic>.from(current['data'] as Map);
      continue;
    }
    return current;
  }
  throw StateError('Invalid realtime metrics payload type');
}
