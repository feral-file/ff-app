/// FF1 Relayer Transport: WebSocket adapter for cloud communication.
///
/// This adapter connects to the Feral File relayer server using WebSockets
/// to enable bidirectional communication with FF1 devices over the internet.
///
/// Architecture:
/// - Uses isolate for WebSocket handling (non-blocking UI)
/// - Auto-reconnects on disconnect (with exponential backoff)
/// - Parses incoming messages and routes to notification stream
/// - Handles connection lifecycle and error recovery
///
/// Separation: This is transport layer - handles WebSocket I/O.
/// Protocol layer handles message parsing. Control layer orchestrates.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:isolate';

import 'package:app/domain/models/ff1_device.dart';
import 'package:app/infra/ff1/wifi_protocol/ff1_wifi_messages.dart';
import 'package:app/infra/ff1/wifi_transport/ff1_wifi_transport.dart';
import 'package:app/infra/logging/structured_logger.dart';
import 'package:logging/logging.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

// ============================================================================
// Relayer transport adapter (WebSocket over cloud)
// ============================================================================

/// Relayer transport: connects to FF1 device via relayer server.
///
/// Connection flow:
/// 1. Build WebSocket URL with topicId, apiKey, userId
/// 2. Spawn isolate for WebSocket management
/// 3. Send connect control message to isolate
/// 4. Listen for notification events from isolate
/// 5. Auto-reconnect on disconnect
class FF1RelayerTransport implements FF1WifiTransport {
  /// Creates relayer transport with given URL.
  FF1RelayerTransport({
    required String relayerUrl,
    Logger? logger,
  }) : _relayerUrl = relayerUrl,
       _log = logger ?? Logger('FF1RelayerTransport') {
    _slog = AppStructuredLog.forLogger(
      _log,
      context: {'component': 'ff1_relayer_transport'},
    );
  }

  final String _relayerUrl;
  final Logger _log;
  late final StructuredLogger _slog;

  // Connection state
  bool _isConnected = false;
  bool _isConnecting = false;
  String? _lastError;

  // Isolate communication
  Isolate? _isolate;
  ReceivePort? _receivePort;
  StreamSubscription<dynamic>? _receiveSub;
  SendPort? _isolateSendPort;
  Completer<void>? _isolateReadyCompleter;

  // Stream controllers
  final _notificationController =
      StreamController<FF1NotificationMessage>.broadcast();
  final _connectionStateController = StreamController<bool>.broadcast();
  final _errorController = StreamController<FF1WifiTransportError>.broadcast();

  // Auto-reconnect
  Timer? _reconnectTimer;
  int _reconnectAttempts = 0;
  static const _maxReconnectAttempts = 10;
  static const _baseReconnectDelay = Duration(seconds: 5);

  // Connection parameters (cached for reconnect)
  FF1Device? _device;
  String? _userId;
  String? _apiKey;

  // When true, reconnect is suppressed (app background or during teardown).
  // Cleared when connect() is called. Prevents Timer-based reconnect and
  // reconnect attempts during pause/teardown windows.
  bool _reconnectSuppressed = false;

  // Single-flight teardown: shared completer ensures concurrent disconnect()
  // and dispose() calls do not race each other on stream adds/closes.
  Completer<void>? _teardownCompleter;

  int _flowSequence = 0;

  String _nextFlowId(String stage) => '$stage-${++_flowSequence}';

  @override
  bool get isConnected => _isConnected;

  @override
  bool get isConnecting => _isConnecting;

  @override
  Stream<FF1NotificationMessage> get notificationStream =>
      _notificationController.stream;

  @override
  Stream<bool> get connectionStateStream => _connectionStateController.stream;

  @override
  Stream<FF1WifiTransportError> get errorStream => _errorController.stream;

  @override
  Future<void> sendCommand(Map<String, dynamic> command) async {
    // Not implemented yet (receive-only for now)
    throw UnimplementedError('Sending commands not yet supported');
  }

  @override
  Future<void> connect({
    required FF1Device device,
    required String userId,
    required String apiKey,
    bool forceReconnect = false,
  }) async {
    final flowId = _nextFlowId(forceReconnect ? 'reconnect' : 'connect');
    _slog.info(
      category: LogCategory.wifi,
      event: 'transport_connect_requested',
      message: 'transport connect requested',
      payload: {
        'flowId': flowId,
        'deviceId': device.deviceId,
        'topicId': device.topicId,
        'forceReconnect': forceReconnect,
        'isConnected': _isConnected,
        'isConnecting': _isConnecting,
      },
    );
    // Validate topicId — emit on error stream so `FF1WifiControl` reports once
    // to Sentry (same path as other connect failures); do not rely on app
    // notifier-level capture.
    if (device.topicId.isEmpty) {
      const error = FF1WifiTransportUnavailableError(
        'Device topicId is required for relayer connection',
      );
      _errorController.add(error);
      throw error;
    }

    // Clear reconnect suppression on any connect. If only cleared on forceReconnect,
    // a manual connect after app was backgrounded (before any device connected)
    // would leave _reconnectSuppressed stuck true, silently disabling
    // auto-reconnect for the rest of the session.
    _reconnectSuppressed = false;

    // Already connected to same device (skip when forceReconnect)
    if (!forceReconnect &&
        _isConnected &&
        _device?.topicId == device.topicId &&
        _userId == userId) {
      _log.fine('Already connected to ${device.deviceId}');
      _slog.info(
        category: LogCategory.wifi,
        event: 'transport_connect_skipped_already_connected',
        message:
            'transport connect skipped because socket is already connected',
        payload: {'flowId': flowId, 'deviceId': device.deviceId},
      );
      return;
    }

    // Disconnect from previous device
    if (_isConnected) {
      await disconnect();
    }

    // Cache connection parameters for reconnect
    _device = device;
    _userId = userId;
    _apiKey = apiKey;

    _log.info('Connecting to ${device.deviceId} (topic: ${device.topicId})');

    try {
      _isConnecting = true;
      await _connectInternal(flowId: flowId);
      _slog.info(
        category: LogCategory.wifi,
        event: 'transport_connect_control_sent',
        message: 'transport connect control sent to isolate',
        payload: {
          'flowId': flowId,
          'deviceId': device.deviceId,
          'isConnected': _isConnected,
          'isConnecting': _isConnecting,
        },
      );
    } catch (e) {
      _isConnecting = false;
      _lastError = e.toString();
      final error = FF1WifiConnectionError(
        'Failed to connect to relayer',
        originalError: e,
      );
      _errorController.add(error);
      rethrow;
    } finally {
      _isConnecting = false;
    }
  }

  Future<void> _connectInternal({String? flowId}) async {
    // Build WebSocket URL
    final wsUrl =
        '$_relayerUrl/api/notification?'
        'apiKey=$_apiKey&topicID=${_device!.topicId}&clientId=$_userId';

    _log.fine('WebSocket URL: ${wsUrl.replaceAll(_apiKey!, '***')}');

    // Spawn isolate if not already running
    if (_receivePort == null) {
      _slog.info(
        category: LogCategory.wifi,
        event: 'transport_isolate_spawn_start',
        message: 'spawning relayer isolate for websocket',
        payload: {'flowId': flowId, 'deviceId': _device?.deviceId},
      );
      _receivePort = ReceivePort();
      _receiveSub = _receivePort!.listen(_handleIsolateMessage);
      _isolateReadyCompleter = Completer<void>();
      _isolate = await Isolate.spawn(
        _relayerIsolateEntry,
        _receivePort!.sendPort,
      );
      _slog.info(
        category: LogCategory.wifi,
        event: 'transport_isolate_spawn_done',
        message: 'relayer isolate spawned',
        payload: {'flowId': flowId, 'deviceId': _device?.deviceId},
      );
    }

    // Wait for isolate to send back its SendPort
    if (_isolateSendPort == null) {
      _slog.info(
        category: LogCategory.wifi,
        event: 'transport_waiting_isolate_ready',
        message: 'waiting for isolate sendPort before connect',
        payload: {'flowId': flowId, 'deviceId': _device?.deviceId},
      );
      final completer = _isolateReadyCompleter;
      if (completer != null && !completer.isCompleted) {
        await completer.future.timeout(
          const Duration(seconds: 10),
          onTimeout: () {
            throw TimeoutException('Isolate did not respond');
          },
        );
      }
    }

    // Send connect control message
    final control = _RelayerControlMessage(
      type: _RelayerControlType.connect,
      data: {'wsUrl': wsUrl},
    );
    _isolateSendPort?.send(control.toJson());
    _slog.info(
      category: LogCategory.wifi,
      event: 'transport_connect_control_dispatched',
      message: 'connect control message dispatched to isolate',
      payload: {
        'flowId': flowId,
        'deviceId': _device?.deviceId,
        'hasIsolateSendPort': _isolateSendPort != null,
      },
    );

    // Reset reconnect attempts on successful connect
    _reconnectAttempts = 0;
  }

  @override
  Future<void> disconnect() async {
    final flowId = _nextFlowId('disconnect');
    _log.info('Disconnecting from relayer');
    _slog.info(
      category: LogCategory.wifi,
      event: 'transport_disconnect_requested',
      message: 'transport disconnect requested',
      payload: {
        'flowId': flowId,
        'deviceId': _device?.deviceId,
        'isConnected': _isConnected,
        'isConnecting': _isConnecting,
      },
    );

    // Single-flight teardown: if already tearing down, wait for ongoing teardown
    if (_reconnectSuppressed && _teardownCompleter != null) {
      _slog.info(
        category: LogCategory.wifi,
        event: 'transport_disconnect_single_flight_wait',
        message: '''
disconnect requested while teardown in progress; waiting existing teardown''',
        payload: {'flowId': flowId, 'deviceId': _device?.deviceId},
      );
      await _teardownCompleter!.future;
      _slog.info(
        category: LogCategory.wifi,
        event: 'transport_disconnect_single_flight_wait_done',
        message: 'existing teardown completed; disconnect request returns',
        payload: {'flowId': flowId, 'deviceId': _device?.deviceId},
      );
      return;
    }

    _reconnectSuppressed = true;
    _teardownCompleter ??= Completer<void>();
    final completer = _teardownCompleter!;

    try {
      _reconnectTimer?.cancel();
      _reconnectTimer = null;
      _reconnectAttempts = 0;
      _slog.info(
        category: LogCategory.wifi,
        event: 'transport_disconnect_timers_cleared',
        message: 'disconnect cleared reconnect timers and attempts',
        payload: {'flowId': flowId, 'deviceId': _device?.deviceId},
      );

      // Send disconnect control message
      const control = _RelayerControlMessage(
        type: _RelayerControlType.disconnect,
      );
      _isolateSendPort?.send(control.toJson());
      _slog.info(
        category: LogCategory.wifi,
        event: 'transport_disconnect_control_dispatched',
        message: 'disconnect control message dispatched to isolate',
        payload: {
          'flowId': flowId,
          'deviceId': _device?.deviceId,
          'hasIsolateSendPort': _isolateSendPort != null,
        },
      );

      await Future<void>.delayed(const Duration(milliseconds: 100));
      _slog.info(
        category: LogCategory.wifi,
        event: 'transport_disconnect_grace_delay_done',
        message: 'disconnect grace delay completed',
        payload: {'flowId': flowId, 'deviceId': _device?.deviceId},
      );

      _isConnected = false;
      if (!_connectionStateController.isClosed) {
        _connectionStateController.add(false);
        _slog.info(
          category: LogCategory.wifi,
          event: 'transport_disconnect_emitted_disconnected',
          message: 'disconnect emitted false on transport connection stream',
          payload: {'flowId': flowId, 'deviceId': _device?.deviceId},
        );
      }

      // Kill isolate
      unawaited(_receiveSub?.cancel());
      _receiveSub = null;
      _receivePort?.close();
      _receivePort = null;
      _isolate?.kill(priority: Isolate.immediate);
      _isolate = null;
      _isolateSendPort = null;
      _isolateReadyCompleter = null;
      _slog.info(
        category: LogCategory.wifi,
        event: 'transport_disconnect_isolate_cleared',
        message: 'disconnect cleared isolate resources',
        payload: {'flowId': flowId, 'deviceId': _device?.deviceId},
      );

      // Clear cached connection params
      _device = null;
      _userId = null;
      _apiKey = null;
      _slog.info(
        category: LogCategory.wifi,
        event: 'transport_disconnect_params_cleared',
        message: 'disconnect cleared cached connection params',
        payload: {'flowId': flowId},
      );
    } finally {
      if (!completer.isCompleted) {
        completer.complete();
      }
      // Clear completer after completion to allow fresh teardown cycle next time
      _teardownCompleter = null;
      _slog.info(
        category: LogCategory.wifi,
        event: 'transport_disconnect_teardown_completed',
        message: 'disconnect teardown cycle completed',
        payload: {'flowId': flowId},
      );
    }
  }

  @override
  void pauseConnection() {
    final flowId = _nextFlowId('pause');
    _log.info('Pausing relayer connection (app background)');
    _slog.info(
      category: LogCategory.wifi,
      event: 'transport_pause_requested',
      message: 'transport pause requested for app background',
      payload: {
        'flowId': flowId,
        'deviceId': _device?.deviceId,
        'isConnected': _isConnected,
        'isConnecting': _isConnecting,
      },
    );

    // Always cancel reconnect timers and set suppression flag, even when already
    // disconnected. After a network drop, the transport can be !_isConnected
    // but still have an active _reconnectTimer from _scheduleReconnect().
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _reconnectSuppressed = true;

    // Always send disconnect when isolate exists. _connectInternal() drops
    // _isConnecting before the isolate sends its connection event, so there
    // is a window where both are false but WebSocket is still connecting.
    // Without this, the WebSocket could come up in background.
    if (_isolateSendPort != null) {
      const control = _RelayerControlMessage(
        type: _RelayerControlType.disconnect,
      );
      _isolateSendPort!.send(control.toJson());
      _slog.info(
        category: LogCategory.wifi,
        event: 'transport_pause_disconnect_control_dispatched',
        message: 'pause dispatched disconnect control to isolate',
        payload: {'flowId': flowId, 'deviceId': _device?.deviceId},
      );
    }

    if (_isConnected || _isConnecting) {
      _isConnected = false;
      _connectionStateController.add(false);
      _slog.info(
        category: LogCategory.wifi,
        event: 'transport_pause_emitted_disconnected',
        message: 'pause emitted transport disconnected to listeners',
        payload: {'flowId': flowId, 'deviceId': _device?.deviceId},
      );
    }
  }

  @override
  void dispose() {
    unawaited(_disposeAsync());
  }

  @override
  Future<void> disposeFuture() async {
    await _disposeAsync();
  }

  Future<void> _disposeAsync() async {
    try {
      await disconnect();
    } finally {
      if (!_notificationController.isClosed) {
        await _notificationController.close();
      }
      if (!_connectionStateController.isClosed) {
        await _connectionStateController.close();
      }
      if (!_errorController.isClosed) {
        await _errorController.close();
      }
    }
  }

  /// Handle message from isolate (connection events, notifications, errors).
  void _handleIsolateMessage(dynamic message) {
    if (message is! Map) {
      _slog.info(
        category: LogCategory.wifi,
        event: 'isolate_message_ignored',
        message: 'ignored non-map message from isolate',
        payload: {'runtimeType': message.runtimeType.toString()},
      );
      return;
    }

    final event = _RelayerEventMessage.fromJson(
      Map<String, dynamic>.from(message),
    );

    _slog.info(
      category: LogCategory.wifi,
      event: 'isolate_event_received',
      message: 'received event from relayer isolate',
      payload: {
        'eventType': event.type.name,
        'deviceId': _device?.deviceId,
        'isConnected': _isConnected,
        'reconnectSuppressed': _reconnectSuppressed,
      },
    );

    switch (event.type) {
      case _RelayerEventType.isolateReady:
        final sendPort = event.data?['sendPort'] as SendPort?;
        if (sendPort != null) {
          _isolateSendPort = sendPort;
          _isolateReadyCompleter ??= Completer<void>();
          if (!(_isolateReadyCompleter?.isCompleted ?? true)) {
            _isolateReadyCompleter!.complete();
          }
          _slog.info(
            category: LogCategory.wifi,
            event: 'transport_isolate_ready',
            message: 'received isolate sendPort',
            payload: {'deviceId': _device?.deviceId},
          );
        } else {
          _slog.warning(
            category: LogCategory.wifi,
            event: 'transport_isolate_ready_missing_port',
            message: 'isolateReady event had no sendPort',
            payload: {'deviceId': _device?.deviceId},
          );
        }

      case _RelayerEventType.connected:
        _isConnected = true;
        _lastError = null;
        _reconnectAttempts = 0;
        if (!_connectionStateController.isClosed) {
          _connectionStateController.add(true);
        }
        _slog.info(
          category: LogCategory.wifi,
          event: 'ws_connected',
          message: 'WebSocket connected to relayer',
          payload: {
            'deviceId': _device?.deviceId,
            'topicId': _device?.topicId,
            'transportIsConnected': _isConnected,
          },
        );

      case _RelayerEventType.disconnected:
        _isConnected = false;
        if (!_connectionStateController.isClosed) {
          _connectionStateController.add(false);
        }
        _slog.warning(
          category: LogCategory.wifi,
          event: 'ws_disconnected',
          message: 'WebSocket disconnected from relayer',
          payload: {
            'deviceId': _device?.deviceId,
            'reconnectSuppressed': _reconnectSuppressed,
            'reconnectAttempts': _reconnectAttempts,
            'lastError': _lastError,
            'willScheduleReconnect': !_reconnectSuppressed,
          },
        );
        if (!_reconnectSuppressed) {
          _scheduleReconnect();
        }

      case _RelayerEventType.error:
        final errorMsg = event.data?['error'] as String? ?? 'Unknown error';
        _lastError = errorMsg;
        _slog.warning(
          category: LogCategory.wifi,
          event: 'ws_error',
          message: 'WebSocket error: $errorMsg',
          payload: {
            'deviceId': _device?.deviceId,
            'error': errorMsg,
            'reconnectSuppressed': _reconnectSuppressed,
          },
        );
        final error = FF1WifiNetworkError(errorMsg);
        if (!_errorController.isClosed) {
          _errorController.add(error);
        }

      case _RelayerEventType.notification:
        final notificationData = event.data?['notification'] as Map?;
        if (notificationData != null) {
          try {
            final notification = FF1NotificationMessage.fromJson(
              Map<String, dynamic>.from(notificationData),
            );
            _slog.info(
              category: LogCategory.wifi,
              event: 'isolate_notification_parsed',
              message: 'parsed notification from isolate',
              payload: {
                'deviceId': _device?.deviceId,
                'notificationType': notification.notificationType.value,
              },
            );
            if (!_notificationController.isClosed) {
              _notificationController.add(notification);
            }
          } catch (e) {
            _log.warning('Failed to parse notification: $e');
            _slog.warning(
              category: LogCategory.wifi,
              event: 'isolate_notification_parse_failed',
              message: 'failed to parse notification from isolate',
              payload: {'deviceId': _device?.deviceId, 'error': e.toString()},
              error: e,
            );
            final error = FF1WifiMessageError(
              'Failed to parse notification',
              originalError: e,
            );
            if (!_errorController.isClosed) {
              _errorController.add(error);
            }
          }
        } else {
          _slog.warning(
            category: LogCategory.wifi,
            event: 'isolate_notification_missing_data',
            message: 'notification event had no data payload',
            payload: {'deviceId': _device?.deviceId},
          );
        }
    }
  }

  /// Schedule auto-reconnect with exponential backoff.
  void _scheduleReconnect() {
    if (_reconnectSuppressed) {
      _log.fine('Skipping reconnect schedule (suppressed)');
      return;
    }

    if (_reconnectAttempts >= _maxReconnectAttempts) {
      _slog.error(
        event: 'ws_reconnect_exhausted',
        message: 'max reconnect attempts reached — giving up',
        payload: {
          'deviceId': _device?.deviceId,
          'maxAttempts': _maxReconnectAttempts,
        },
      );
      const error = FF1WifiConnectionError(
        'Failed to reconnect after $_maxReconnectAttempts attempts',
      );
      if (!_errorController.isClosed) {
        _errorController.add(error);
      }
      return;
    }

    if (_device == null || _userId == null || _apiKey == null) {
      _log.fine('No cached connection params, skipping reconnect');
      return;
    }

    _reconnectTimer?.cancel();

    // Exponential backoff: 5s, 10s, 20s, 40s, ...
    final delay = _baseReconnectDelay * (1 << _reconnectAttempts);
    _reconnectAttempts++;

    _slog.info(
      category: LogCategory.wifi,
      event: 'ws_reconnect_scheduled',
      message:
          'reconnect scheduled in ${delay.inSeconds}s '
          '(attempt $_reconnectAttempts/$_maxReconnectAttempts)',
      payload: {
        'deviceId': _device?.deviceId,
        'delaySeconds': delay.inSeconds,
        'attempt': _reconnectAttempts,
        'maxAttempts': _maxReconnectAttempts,
      },
    );

    _reconnectTimer = Timer(delay, () async {
      if (_reconnectSuppressed || _isConnected || _isConnecting) {
        return;
      }

      _slog.info(
        category: LogCategory.wifi,
        event: 'ws_reconnect_attempt',
        message: 'attempting reconnect',
        payload: {
          'deviceId': _device?.deviceId,
          'attempt': _reconnectAttempts,
        },
      );
      try {
        await _connectInternal();
      } catch (e) {
        _slog.warning(
          category: LogCategory.wifi,
          event: 'ws_reconnect_attempt_failed',
          message: 'reconnect attempt failed',
          payload: {'deviceId': _device?.deviceId, 'error': e.toString()},
          error: e,
        );
        // Will schedule another reconnect via disconnect event
      }
    });
  }

  String? get lastError => _lastError;
}

// ============================================================================
// Isolate entry point and WebSocket management
// ============================================================================

/// Structured-ish logs from the relayer isolate
void _relayerIsolateLog(String event, String message) {
  developer.log('[$event] $message', name: 'FF1RelayerIsolate');
}

/// Isolate entry point for WebSocket management
void _relayerIsolateEntry(SendPort mainSendPort) {
  _relayerIsolateLog('isolate_entry', 'relayer isolate starting');
  final controlPort = ReceivePort();

  // Send back our SendPort
  final readyEvent = _RelayerEventMessage(
    type: _RelayerEventType.isolateReady,
    data: {'sendPort': controlPort.sendPort},
  );
  mainSendPort.send(readyEvent.toJson());
  _relayerIsolateLog(
    'isolate_ready_sent',
    'sent isolateReady with control SendPort',
  );

  WebSocketChannel? channel;
  StreamSubscription<dynamic>? channelSub;
  String? wsUrl;

  Future<void> closeChannel() async {
    _relayerIsolateLog('close_channel_start', 'closing websocket channel');
    await channelSub?.cancel();
    channelSub = null;
    await channel?.sink.close();
    channel = null;
    _relayerIsolateLog('close_channel_done', 'websocket channel closed');
  }

  Future<void> connect() async {
    if (wsUrl == null || wsUrl!.isEmpty) {
      _relayerIsolateLog(
        'connect_skipped_empty_url',
        'connect skipped: wsUrl is null or empty',
      );
      return;
    }

    try {
      final uri = Uri.parse(wsUrl!);
      _relayerIsolateLog(
        'connect_start',
        'WebSocketChannel.connect host=${uri.host} path=${uri.path}',
      );
      channel = WebSocketChannel.connect(uri);

      channelSub = channel!.stream.listen(
        (dynamic rawMessage) {
          try {
            if (rawMessage is! String) {
              _relayerIsolateLog(
                'ws_message_ignored_non_string',
                'dropping non-string frame: ${rawMessage.runtimeType}',
              );
              return;
            }

            final decoded = jsonDecode(rawMessage) as Map<String, dynamic>;
            final notification = FF1NotificationMessage.fromJson(decoded);
            _relayerIsolateLog(
              'notification_received',
              'notification_type=${notification.notificationType}',
            );

            const event = _RelayerEventMessage(
              type: _RelayerEventType.notification,
            );
            final eventData = <String, dynamic>{
              ...event.toJson(),
              'data': {'notification': notification.toJson()},
            };
            mainSendPort.send(eventData);
            _relayerIsolateLog(
              'notification_forwarded',
              'notification_type=${notification.notificationType.value}',
            );
          } on Exception catch (e) {
            _relayerIsolateLog('notification_parse_error', e.toString());
          }
        },
        onError: (Object error) {
          _relayerIsolateLog('ws_stream_error', error.toString());
          const errorEvent = _RelayerEventMessage(
            type: _RelayerEventType.error,
          );
          final errorData = <String, dynamic>{
            ...errorEvent.toJson(),
            'data': {'error': error.toString()},
          };
          mainSendPort.send(errorData);
          unawaited(closeChannel());
          const disconnectedEvent = _RelayerEventMessage(
            type: _RelayerEventType.disconnected,
          );
          mainSendPort.send(disconnectedEvent.toJson());
          _relayerIsolateLog(
            'ws_error_sent_disconnected',
            'sent error + disconnected after stream error',
          );
        },
        onDone: () {
          _relayerIsolateLog(
            'ws_stream_done',
            'websocket stream closed (onDone)',
          );
          const event = _RelayerEventMessage(
            type: _RelayerEventType.disconnected,
          );
          mainSendPort.send(event.toJson());
        },
      );

      const connectedEvent = _RelayerEventMessage(
        type: _RelayerEventType.connected,
      );
      mainSendPort.send(connectedEvent.toJson());
      _relayerIsolateLog(
        'connected_event_sent',
        'sent connected event to main (socket object created)',
      );
    } on Exception catch (e) {
      _relayerIsolateLog('connect_exception', e.toString());
      const errorEvent = _RelayerEventMessage(
        type: _RelayerEventType.error,
      );
      final errorData = <String, dynamic>{
        ...errorEvent.toJson(),
        'data': {'error': e.toString()},
      };
      mainSendPort.send(errorData);
      unawaited(closeChannel());
      // Send disconnected so main schedules reconnect (initial connect failure)
      const disconnectedEvent = _RelayerEventMessage(
        type: _RelayerEventType.disconnected,
      );
      mainSendPort.send(disconnectedEvent.toJson());
      _relayerIsolateLog(
        'connect_failed_sent_error_disconnected',
        'sent error + disconnected after connect exception',
      );
    }
  }

  controlPort.listen((dynamic rawMessage) async {
    if (rawMessage is! Map) {
      _relayerIsolateLog(
        'control_ignored_non_map',
        'ignored non-map control: ${rawMessage.runtimeType}',
      );
      return;
    }

    final control = _RelayerControlMessage.fromJson(
      Map<String, dynamic>.from(rawMessage),
    );

    switch (control.type) {
      case _RelayerControlType.connect:
        _relayerIsolateLog(
          'control_connect',
          'connect control received',
        );
        wsUrl = control.data?['wsUrl'] as String?;
        await closeChannel();
        await connect();

      case _RelayerControlType.disconnect:
        _relayerIsolateLog('control_disconnect', 'disconnect control received');
        unawaited(closeChannel());
        const event = _RelayerEventMessage(
          type: _RelayerEventType.disconnected,
        );
        mainSendPort.send(event.toJson());
        _relayerIsolateLog(
          'disconnect_event_sent',
          'sent disconnected to main after disconnect control',
        );

      case _RelayerControlType.dispose:
        _relayerIsolateLog('control_dispose', 'dispose control received');
        unawaited(closeChannel());
        controlPort.close();
        _relayerIsolateLog('control_port_closed', 'control ReceivePort closed');
    }
  });
}

// ============================================================================
// Isolate communication messages (main ↔ isolate)
// ============================================================================

/// Control message types (main → isolate)
enum _RelayerControlType { connect, disconnect, dispose }

/// Control message (main → isolate)
class _RelayerControlMessage {
  const _RelayerControlMessage({
    required this.type,
    this.data,
  });

  factory _RelayerControlMessage.fromJson(Map<String, dynamic> json) {
    return _RelayerControlMessage(
      type: _RelayerControlType.values.byName(json['type'] as String),
      data: json['data'] as Map<String, dynamic>?,
    );
  }

  final _RelayerControlType type;
  final Map<String, dynamic>? data;

  Map<String, dynamic> toJson() => {
    'type': type.name,
    if (data != null) 'data': data,
  };
}

/// Event message types (isolate → main)
enum _RelayerEventType {
  isolateReady,
  connected,
  disconnected,
  error,
  notification,
}

/// Event message (isolate → main)
class _RelayerEventMessage {
  const _RelayerEventMessage({
    required this.type,
    this.data,
  });

  factory _RelayerEventMessage.fromJson(Map<String, dynamic> json) {
    return _RelayerEventMessage(
      type: _RelayerEventType.values.byName(json['type'] as String),
      data: json['data'] as Map<String, dynamic>?,
    );
  }

  final _RelayerEventType type;
  final Map<String, dynamic>? data;

  Map<String, dynamic> toJson() => {
    'type': type.name,
    if (data != null) 'data': data,
  };
}
