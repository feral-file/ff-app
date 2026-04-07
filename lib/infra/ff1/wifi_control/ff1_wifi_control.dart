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

// This file predates the stricter lint profile. The new device-switch fix only
// touches connection-state caching, so we keep the existing command-surface
// debt isolated instead of refactoring the entire control layer here.
// ignore_for_file: avoid_dynamic_calls, discarded_futures, lines_longer_than_80_chars

import 'dart:async';
import 'dart:ui' show Offset;

import 'package:app/domain/models/ff1/art_framing.dart';
import 'package:app/domain/models/ff1/canvas_cast_request_reply.dart';
import 'package:app/domain/models/ff1/ffp_ddc_command_errors.dart';
import 'package:app/domain/models/ff1/ffp_ddc_panel_status.dart';
import 'package:app/domain/models/ff1/loop_mode.dart';
import 'package:app/domain/models/ff1_device.dart';
import 'package:app/infra/ff1/wifi_control/ff1_wifi_control_verifier.dart';
import 'package:app/infra/ff1/wifi_protocol/ff1_wifi_messages.dart';
import 'package:app/infra/ff1/wifi_protocol/ff1_wifi_payload_unwrap.dart';
import 'package:app/infra/ff1/wifi_transport/ff1_wifi_transport.dart';
import 'package:app/infra/logging/structured_logger.dart';
import 'package:logging/logging.dart';
import 'package:rxdart/rxdart.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

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
    _slog = AppStructuredLog.forLogger(
      _log,
      context: {'component': 'ff1_wifi_control'},
    );
    _startListening();
  }

  final FF1WifiTransport _transport;
  final dynamic _restClient;
  final Logger _log;
  late final StructuredLogger _slog;

  // Stream controllers for state changes
  final _playerStatusController = BehaviorSubject<FF1PlayerStatus>();
  final _deviceStatusController = BehaviorSubject<FF1DeviceStatus>();
  final _ffpDdcPanelStatusController = BehaviorSubject<FfpDdcPanelStatus>();
  final _connectionStatusController = BehaviorSubject<FF1ConnectionStatus>();

  // Current device state
  FF1PlayerStatus? _currentPlayerStatus;
  String? _currentPlayerStatusDeviceId;
  FF1DeviceStatus? _currentDeviceStatus;
  String? _currentDeviceStatusDeviceId;
  FfpDdcPanelStatus? _currentFfpDdcPanelStatus;
  bool _isDeviceConnected = false;
  Completer<FF1DeviceStatus?>? _freshDeviceStatusCompleter;
  Completer<FF1DeviceStatus?>? _freshDeviceVersionCompleter;

  // Stream subscriptions
  StreamSubscription<FF1NotificationMessage>? _notificationSub;
  StreamSubscription<bool>? _connectionStateSub;
  StreamSubscription<FF1WifiTransportError>? _errorSub;

  /// When true, ignore transport callbacks — [dispose] has started and subjects
  /// may be closed after subscription cancel completes.
  bool _isTearingDown = false;

  /// Single in-flight dispose; repeated [dispose] calls are ignored.
  Future<void>? _ongoingDispose;

  // Current device and auth (for reconnect)
  FF1Device? _device;
  String? _userId;
  String? _apiKey;
  int _flowSequence = 0;

  String _nextFlowId(String stage) => '$stage-${++_flowSequence}';

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
    final flowId = _nextFlowId('connect');
    final previousDevice = _device;
    final previousDeviceId = previousDevice?.deviceId;
    _freshDeviceStatusCompleter?.complete(null);
    _freshDeviceVersionCompleter?.complete(null);
    final switchingDevice =
        _device != null && _device!.deviceId != device.deviceId;
    if (switchingDevice) {
      _currentPlayerStatus = null;
      _currentDeviceStatus = null;
      _deviceStatusController.add(const FF1DeviceStatus());
      _clearFfpDdcPanelStatus();
      _isDeviceConnected = false;
      _connectionStatusController.add(
        const FF1ConnectionStatus(isConnected: false),
      );
    }

    if (previousDevice != null && previousDevice.deviceId != device.deviceId) {
      // Reset the last replayed state before the new device starts publishing.
      // Without this handoff clear, provider consumers can evaluate the next
      // active device against the previous device's relayer status/version.
      _clearRealtimeState(
        emitDisconnectedStatus: true,
        flowId: flowId,
        reason: 'switch_device',
      );
    }

    _device = device;
    _userId = userId;
    _apiKey = apiKey;

    // Clear cached status before the new transport session starts.
    //
    // Why: `playerStatusStream` is a BehaviorSubject and will continue to hold
    // the previous device's last payload until the new device emits a fresh
    // player-status notification. Clearing the live cache here prevents app
    // providers from reusing device A's playback state for device B during the
    // switch-over gap.
    _currentPlayerStatus = null;
    _currentDeviceStatus = null;
    _isDeviceConnected = false;
    _freshDeviceStatusCompleter = Completer<FF1DeviceStatus?>();
    _freshDeviceVersionCompleter = Completer<FF1DeviceStatus?>();
    _connectionStatusController.add(
      const FF1ConnectionStatus(isConnected: false),
    );

    _log.info('Connecting to ${device.deviceId}');
    _slog.info(
      category: LogCategory.wifi,
      event: 'control_connect_requested',
      message: 'control connect requested',
      payload: {
        'flowId': flowId,
        'deviceId': device.deviceId,
        'previousDeviceId': previousDeviceId,
        'topicId': device.topicId,
        'transportConnected': _transport.isConnected,
        'transportConnecting': _transport.isConnecting,
      },
    );

    try {
      await _transport.connect(
        device: device,
        userId: userId,
        apiKey: apiKey,
      );
      _slog.info(
        category: LogCategory.wifi,
        event: 'control_connect_dispatched',
        message: 'control connect dispatched to transport',
        payload: {
          'flowId': flowId,
          'deviceId': device.deviceId,
          'transportConnected': _transport.isConnected,
          'transportConnecting': _transport.isConnecting,
        },
      );
    } catch (e) {
      _log.severe('Failed to connect: $e');
      _slog.warning(
        category: LogCategory.wifi,
        event: 'control_connect_failed',
        message: 'control connect failed',
        payload: {'flowId': flowId, 'deviceId': device.deviceId, 'error': '$e'},
        error: e,
      );
      rethrow;
    }
  }

  /// Clears replayed realtime state before switching to a different device.
  ///
  /// This is a handoff guard for the auto-connect watcher: consumers must
  /// stop seeing the previous device's relayer state before the new device's
  /// connection attempt begins.
  void prepareForDeviceSwitch(FF1Device device) {
    if (_device?.deviceId == device.deviceId) {
      return;
    }

    _clearRealtimeState(
      emitDisconnectedStatus: true,
      reason: 'watcher_device_switch',
    );
  }

  /// Disconnect from device
  Future<void> disconnect() async {
    final flowId = _nextFlowId('disconnect');
    _log.info('Disconnecting');
    _slog.info(
      category: LogCategory.wifi,
      event: 'control_disconnect_requested',
      message: 'control disconnect requested',
      payload: {
        'flowId': flowId,
        'deviceId': _device?.deviceId,
        'transportConnected': _transport.isConnected,
        'transportConnecting': _transport.isConnecting,
      },
    );

    // Clear current state immediately so the UI cannot keep rendering stale
    // values while the relayer transport finishes shutting down.
    _deviceStatusController.add(const FF1DeviceStatus());
    _clearFfpDdcPanelStatus();
    _clearRealtimeState(flowId: flowId, reason: 'disconnect');

    _freshDeviceStatusCompleter?.complete(null);
    _freshDeviceStatusCompleter = null;
    _freshDeviceVersionCompleter?.complete(null);
    _freshDeviceVersionCompleter = null;
    _connectionStatusController.add(
      const FF1ConnectionStatus(isConnected: false),
    );
    _slog.info(
      category: LogCategory.wifi,
      event: 'control_disconnect_completed',
      message: 'control disconnect completed and state cleared',
      payload: {
        'flowId': flowId,
        'transportConnected': _transport.isConnected,
        'transportConnecting': _transport.isConnecting,
      },
    );

    await _transport.disconnect();

    // Clear cached connection params so the next connect starts clean.
    _device = null;
    _userId = null;
    _apiKey = null;
  }

  /// Check if transport is connected
  bool get isConnected => _transport.isConnected;

  /// Emits the current transport connected flag, then every change from
  /// `FF1WifiTransport.connectionStateStream`.
  ///
  /// The first value mirrors the transport's `isConnected` because connection
  /// streams are typically broadcast and do not replay, so listeners would
  /// otherwise miss the current state until the next edge.
  Stream<bool> transportConnectionStates() async* {
    yield _transport.isConnected;
    yield* _transport.connectionStateStream;
  }

  /// Check if transport is currently connecting
  bool get isConnecting => _transport.isConnecting;

  /// Current player status (last received)
  FF1PlayerStatus? get currentPlayerStatus => _currentPlayerStatus;

  /// Current device status (last received)
  FF1DeviceStatus? get currentDeviceStatus => _currentDeviceStatus;

  /// Device id that produced [currentPlayerStatus].
  String? get currentPlayerStatusDeviceId => _currentPlayerStatusDeviceId;

  /// Device id that produced [currentDeviceStatus].
  String? get currentDeviceStatusDeviceId => _currentDeviceStatusDeviceId;

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

  /// Waits for the first device status observed after the most recent connect
  /// reset. Returns the already-received fresh status immediately when
  /// available, or `null` on timeout / teardown.
  Future<FF1DeviceStatus?> waitForFreshDeviceStatus({
    Duration timeout = const Duration(seconds: 5),
  }) async {
    final future = freshDeviceStatusFuture();
    return future.timeout(timeout, onTimeout: () => null);
  }

  /// Future for the first device status observed after the most recent connect
  /// reset.
  ///
  /// Why: callers that do an initial short timeout can keep awaiting this same
  /// future later without switching to the replaying device-status stream,
  /// which may still buffer a previous session's payload.
  Future<FF1DeviceStatus?> freshDeviceStatusFuture() {
    final completer = _freshDeviceStatusCompleter;
    if (completer == null) {
      return Future<FF1DeviceStatus?>.value(_currentDeviceStatus);
    }
    return completer.future;
  }

  /// Future for the first device status in the current session that carries a
  /// usable device version.
  ///
  /// Why: the required-update gate must not treat a version-less status as
  /// terminal for the session, because FF1 can emit a later fresh status that
  /// fills in `latestVersion` after the initial connect handshake.
  Future<FF1DeviceStatus?> freshDeviceVersionFuture() {
    final completer = _freshDeviceVersionCompleter;
    if (completer == null) {
      final deviceStatus = _currentDeviceStatus;
      if (deviceStatus?.latestVersion?.isNotEmpty == true) {
        return Future<FF1DeviceStatus?>.value(deviceStatus);
      }
      return Future<FF1DeviceStatus?>.value();
    }
    return completer.future;
  }

  /// Current FFP DDC panel status (last received).
  FfpDdcPanelStatus? get currentFfpDdcPanelStatus => _currentFfpDdcPanelStatus;

  /// Stream of FFP DDC panel status updates.
  Stream<FfpDdcPanelStatus> get ffpDdcPanelStatusStream =>
      _ffpDdcPanelStatusController.stream;

  /// Emits an empty status to flush replayed FFP state across disconnects and
  /// device switches. Without this, new subscribers can immediately render the
  /// previous device's monitor snapshot before the relayer pushes fresh data.
  void _clearFfpDdcPanelStatus() {
    _currentFfpDdcPanelStatus = null;
    _ffpDdcPanelStatusController.add(const FfpDdcPanelStatus());
  }

  /// Handle incoming notification from transport
  void _handleNotification(FF1NotificationMessage notification) {
    if (_isTearingDown) {
      return;
    }
    _log.fine('Notification: ${notification.notificationType}');

    switch (notification.notificationType) {
      case FF1NotificationType.playerStatus:
        final playerStatus = FF1PlayerStatus.fromJson(notification.message);
        _currentPlayerStatusDeviceId = _device?.deviceId;
        _currentPlayerStatus = playerStatus;
        _playerStatusController.add(playerStatus);

      case FF1NotificationType.deviceStatus:
        final deviceStatus = FF1DeviceStatus.fromJson(notification.message);
        _currentDeviceStatusDeviceId = _device?.deviceId;
        _currentDeviceStatus = deviceStatus;
        _deviceStatusController.add(deviceStatus);
        _freshDeviceStatusCompleter?.complete(deviceStatus);
        _freshDeviceStatusCompleter = null;
        if (deviceStatus.latestVersion?.isNotEmpty == true) {
          _freshDeviceVersionCompleter?.complete(deviceStatus);
          _freshDeviceVersionCompleter = null;
        }

      case FF1NotificationType.ffpDdcPanelStatus:
        final panelStatus = FfpDdcPanelStatus.fromJson(notification.message);
        _currentFfpDdcPanelStatus = panelStatus;
        _ffpDdcPanelStatusController.add(panelStatus);

      case FF1NotificationType.connection:
        final connectionStatus = FF1ConnectionStatus.fromJson(
          notification.message,
        );
        final prev = _isDeviceConnected;
        _isDeviceConnected = connectionStatus.isConnected;
        _connectionStatusController.add(connectionStatus);
        if (!connectionStatus.isConnected) {
          // Transport can still be up while the device reports disconnected;
          // clear cached FFP/DDC snapshot so UI cannot drive stale controls.
          _clearFfpDdcPanelStatus();
        }
        // Track every device-level connection notification so we can see
        // when the device sends "connected" vs "disconnected" and correlate
        // with the WebSocket transport state.
        _slog.info(
          category: LogCategory.wifi,
          event: 'device_connection_notification',
          message:
              'device connection notification: isConnected=${connectionStatus.isConnected}',
          payload: {
            'isConnected': connectionStatus.isConnected,
            'prevIsDeviceConnected': prev,
            'transportConnected': _transport.isConnected,
            'deviceId': _device?.deviceId,
          },
        );
    }
  }

  /// Handle connection state change from transport
  void _handleConnectionStateChange(bool isConnected) {
    if (_isTearingDown) {
      return;
    }
    final flowId = _nextFlowId('transport_state');
    _log.info('Connection state changed: $isConnected');
    _slog.info(
      category: LogCategory.wifi,
      event: 'transport_state_observed',
      message: 'control observed transport connection state change',
      payload: {
        'transportConnected': isConnected,
        'deviceConnectedBeforeHandling': _isDeviceConnected,
        'deviceId': _device?.deviceId,
      },
    );

    if (!isConnected) {
      // Transport dropped — clear all cached state and push a disconnected
      // status so the UI reacts immediately. Device-level "connected" will
      // only be restored once the device re-sends a connection notification
      // after the WebSocket reconnects.
      _slog.warning(
        category: LogCategory.wifi,
        event: 'transport_disconnected',
        message: 'transport disconnected — clearing device-connected state',
        payload: {
          'prevIsDeviceConnected': _isDeviceConnected,
          'deviceId': _device?.deviceId,
        },
      );
      _clearRealtimeState(
        emitDisconnectedStatus: true,
        flowId: flowId,
        reason: 'transport_disconnect',
      );
      _clearFfpDdcPanelStatus();

      _freshDeviceStatusCompleter?.complete(null);
      _freshDeviceStatusCompleter = null;
      _freshDeviceVersionCompleter?.complete(null);
      _freshDeviceVersionCompleter = null;
      _slog.info(
        category: LogCategory.wifi,
        event: 'control_connection_status_emitted',
        message: 'emitted connection status after transport disconnect',
        payload: {
          'isConnected': isConnected,
          'deviceId': _device?.deviceId,
        },
      );
    } else {
      // Transport (WebSocket) reconnected. Device-level "connected" flag is
      // NOT updated here — it will only change once the device sends a
      // FF1NotificationType.connection notification. This gap (transport up,
      // device-level still false) is the root cause of the false "Device not
      // connected" display after reconnect; app-layer telemetry compares live
      // WebSocket state (not the connection notifier cache) to this flag.
      _slog.info(
        category: LogCategory.wifi,
        event: 'transport_connected',
        message:
            'transport connected — waiting for device connection notification',
        payload: {
          'isDeviceConnected': _isDeviceConnected,
          'deviceId': _device?.deviceId,
        },
      );
    }
  }

  /// Handle transport error
  void _handleTransportError(FF1WifiTransportError error) {
    _log.warning('Transport error: $error');
    unawaited(_reportTransportErrorToSentry(error));
  }

  /// Sends transport errors to Sentry. Network errors use a warning event to
  /// limit noise from transient WebSocket failures.
  Future<void> _reportTransportErrorToSentry(
    FF1WifiTransportError error,
  ) async {
    if (error is FF1WifiNetworkError) {
      await Sentry.captureEvent(
        SentryEvent(
          message: SentryMessage(error.message),
          level: SentryLevel.warning,
          tags: const {
            'component': 'ff1_wifi_transport',
            'error_kind': 'network',
          },
        ),
      );
      return;
    }

    await Sentry.captureException(
      error,
      stackTrace: StackTrace.current,
      withScope: (scope) {
        scope
          ..setTag('component', 'ff1_wifi_transport')
          ..setTag('error_kind', error.runtimeType.toString());
      },
    );
  }

  /// Reconnect to device (using cached connection params)
  ///
  /// Useful for app lifecycle changes (foreground/background).
  /// Uses the `forceReconnect` flag to bypass the "already connected" check
  /// when the connection may be stale (e.g. the app was suspended and the
  /// timer-based reconnect did not fire).
  Future<void> reconnect() async {
    final flowId = _nextFlowId('reconnect');
    if (_device == null || _userId == null || _apiKey == null) {
      _log.warning('Cannot reconnect: no cached connection params');
      _slog.warning(
        category: LogCategory.wifi,
        event: 'reconnect_skipped_missing_params',
        message: 'cannot reconnect due to missing cached params',
        payload: {'flowId': flowId, 'deviceId': _device?.deviceId},
      );
      return;
    }

    _slog.info(
      category: LogCategory.wifi,
      event: 'reconnect_start',
      message: 'reconnecting to device',
      payload: {
        'flowId': flowId,
        'deviceId': _device!.deviceId,
        'isDeviceConnected': _isDeviceConnected,
        'isTransportConnected': _transport.isConnected,
        'isTransportConnecting': _transport.isConnecting,
      },
    );

    try {
      _slog.info(
        category: LogCategory.wifi,
        event: 'reconnect_transport_call_started',
        message: 'calling transport.connect(forceReconnect: true)',
        payload: {'flowId': flowId, 'deviceId': _device?.deviceId},
      );
      await _transport.connect(
        device: _device!,
        userId: _userId!,
        apiKey: _apiKey!,
        forceReconnect: true,
      );
      _slog
        ..info(
          category: LogCategory.wifi,
          event: 'reconnect_transport_call_completed',
          message: 'transport.connect(forceReconnect: true) returned',
          payload: {
            'flowId': flowId,
            'deviceId': _device?.deviceId,
            'isTransportConnected': _transport.isConnected,
            'isTransportConnecting': _transport.isConnecting,
          },
        )
        ..info(
          category: LogCategory.wifi,
          event: 'reconnect_transport_ok',
          message: '''
transport reconnected — waiting for device connection notification''',
          payload: {
            'flowId': flowId,
            'deviceId': _device?.deviceId,
            'isDeviceConnected': _isDeviceConnected,
          },
        );
    } catch (e) {
      _slog.warning(
        category: LogCategory.wifi,
        event: 'reconnect_failed',
        message: 'reconnect failed',
        payload: {
          'flowId': flowId,
          'deviceId': _device?.deviceId,
          'error': e.toString(),
        },
        error: e,
      );
      rethrow;
    }
  }

  /// Pause connection when app goes to background.
  ///
  /// Closes WebSocket but preserves connection params for [reconnect] on resume.
  void pauseConnection() {
    if (_isTearingDown) {
      return;
    }

    final flowId = _nextFlowId('pause');
    _slog.info(
      category: LogCategory.wifi,
      event: 'connection_paused',
      message: 'pausing connection for background',
      payload: {
        'flowId': flowId,
        'isDeviceConnected': _isDeviceConnected,
        'isTransportConnected': _transport.isConnected,
        'isTransportConnecting': _transport.isConnecting,
        'deviceId': _device?.deviceId,
      },
    );
    _transport.pauseConnection();
    _slog.info(
      category: LogCategory.wifi,
      event: 'control_pause_transport_called',
      message: 'called transport.pauseConnection from control',
      payload: {
        'flowId': flowId,
        'deviceId': _device?.deviceId,
        'isTransportConnected': _transport.isConnected,
        'isTransportConnecting': _transport.isConnecting,
      },
    );

    // Clear current state but preserve _device, _userId, _apiKey for reconnect
    _clearRealtimeState(
      emitDisconnectedStatus: true,
      flowId: flowId,
      reason: 'pause',
    );
    _deviceStatusController.add(const FF1DeviceStatus());
    _clearFfpDdcPanelStatus();
    _freshDeviceStatusCompleter?.complete(null);
    _freshDeviceStatusCompleter = null;
    _freshDeviceVersionCompleter?.complete(null);
    _freshDeviceVersionCompleter = null;
    _slog.info(
      category: LogCategory.wifi,
      event: 'control_pause_state_cleared',
      message: 'pause cleared device/player state and emitted disconnected',
      payload: {'flowId': flowId, 'deviceId': _device?.deviceId},
    );
  }

  /// Dispose control and clean up resources.
  void dispose() {
    _ongoingDispose ??= _disposeAsync();
    unawaited(_ongoingDispose);
  }

  /// Clears replayed device/player state.
  ///
  /// When [emitDisconnectedStatus] is true, consumers that only react to the
  /// connection stream are immediately told that any previous device-level
  /// connection is no longer valid for the current handoff.
  void _clearRealtimeState({
    required String reason,
    bool emitDisconnectedStatus = false,
    String? flowId,
  }) {
    _currentPlayerStatus = null;
    _currentPlayerStatusDeviceId = null;
    _currentDeviceStatus = null;
    _currentDeviceStatusDeviceId = null;
    _isDeviceConnected = false;
    if (emitDisconnectedStatus) {
      _connectionStatusController.add(
        const FF1ConnectionStatus(isConnected: false),
      );
    }
    _slog.info(
      category: LogCategory.wifi,
      event: 'control_realtime_state_cleared',
      message: 'cleared replayed realtime state',
      payload: {
        'flowId': flowId,
        'reason': reason,
        'deviceId': _device?.deviceId,
        'emitDisconnectedStatus': emitDisconnectedStatus,
      },
    );
  }

  /// Cancels transport subscriptions before closing subjects so a delayed
  /// `connectionStateStream` event (e.g. relayer [disconnect] window) cannot
  /// call [_handleConnectionStateChange] after [_connectionStatusController] is
  /// closed.
  Future<void> _disposeAsync() async {
    _log.info('Disposing WiFi control');
    _isTearingDown = true;

    await Future.wait<void>([
      if (_notificationSub != null) _notificationSub!.cancel(),
      if (_connectionStateSub != null) _connectionStateSub!.cancel(),
      if (_errorSub != null) _errorSub!.cancel(),
    ]);
    _notificationSub = null;
    _connectionStateSub = null;
    _errorSub = null;

    await Future.wait<void>([
      _playerStatusController.close(),
      _deviceStatusController.close(),
      _ffpDdcPanelStatusController.close(),
      _connectionStatusController.close(),
    ]);

    await _transport.disposeFuture();
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

  /// Trigger firmware update to the latest available version.
  ///
  /// Instructs the device to fetch and install the latest firmware. The device
  /// reboots automatically on completion. Only succeeds when the device has an
  /// active internet connection and a newer version is available.
  ///
  /// [topicId] — device topic ID
  Future<FF1CommandResponse> updateToLatestVersion({
    required String topicId,
  }) async {
    if (_restClient == null) {
      throw StateError('REST client not available');
    }

    try {
      _log.info('Sending updateToLatestVersion command to device');

      const request = FF1WifiUpdateToLatestVersionRequest();
      final response =
          await _restClient.sendCommand(
                topicId: topicId,
                command: request.command,
                params: request.params,
              )
              as Map<String, dynamic>;

      return FF1CommandResponse.fromJson(response);
    } catch (e) {
      _log.severe('Failed to send updateToLatestVersion command: $e');
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
  /// [mode] — playlist or one
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
      final payload = unwrapFf1RelayerPayload(response);
      return DeviceRealtimeMetrics.fromJson(payload);
    } catch (e) {
      _log.severe('Failed to fetch realtime metrics: $e');
      rethrow;
    }
  }

  /// FFP / DDC: set monitor brightness (may throw [FfpDdcUnsupportedException]).
  Future<void> setFfpMonitorBrightness({
    required String topicId,
    required String monitorId,
    required int percent,
  }) async {
    final r = await _sendFfpDdcCommand(
      topicId: topicId,
      request: FfpDdcMonitorSetBrightnessRequest(
        monitorId: monitorId,
        percent: percent.clamp(0, 100),
      ),
    );
    _throwIfFfpCommandFailed(r, 'setFfpMonitorBrightness');
  }

  /// FFP / DDC: set monitor contrast.
  Future<void> setFfpMonitorContrast({
    required String topicId,
    required String monitorId,
    required int percent,
  }) async {
    final r = await _sendFfpDdcCommand(
      topicId: topicId,
      request: FfpDdcMonitorSetContrastRequest(
        monitorId: monitorId,
        percent: percent.clamp(0, 100),
      ),
    );
    _throwIfFfpCommandFailed(r, 'setFfpMonitorContrast');
  }

  /// FFP / DDC: power (on / off / standby).
  Future<void> setFfpMonitorPower({
    required String topicId,
    required String monitorId,
    required String powerState,
  }) async {
    final r = await _sendFfpDdcCommand(
      topicId: topicId,
      request: FfpDdcMonitorSetPowerRequest(
        monitorId: monitorId,
        powerState: powerState,
      ),
    );
    _throwIfFfpCommandFailed(r, 'setFfpMonitorPower');
  }

  Future<FF1CommandResponse> _sendFfpDdcCommand({
    required String topicId,
    required FF1WifiCommandRequest request,
  }) async {
    final restClient = _restClient;
    if (restClient == null) {
      throw StateError('REST client not available');
    }
    final response =
        await restClient.sendCommand(
              topicId: topicId,
              command: request.command,
              params: request.params,
            )
            as Map<String, dynamic>;
    return FF1CommandResponse.fromJson(response);
  }
}

void _throwIfFfpCommandFailed(FF1CommandResponse r, String action) {
  if (ff1CommandResponseSucceeded(r)) {
    return;
  }
  final data = r.data ?? {};
  final errMap = data['error'];
  var message = '';
  if (errMap is Map) {
    message = errMap['message']?.toString() ?? '';
  }
  message = message.isNotEmpty ? message : (data['message']?.toString() ?? '');
  final code =
      data['code']?.toString().toLowerCase() ??
      (errMap is Map ? errMap['code']?.toString().toLowerCase() : null);
  final lower = message.toLowerCase();
  final unsupported = code == 'unsupported' || lower.contains('unsupported');
  if (unsupported) {
    throw FfpDdcUnsupportedException(
      message.isNotEmpty ? message : 'Operation not supported ($action)',
    );
  }
  throw FfpDdcCommandException(
    message.isNotEmpty ? message : 'FFP DDC command failed: $action',
  );
}
