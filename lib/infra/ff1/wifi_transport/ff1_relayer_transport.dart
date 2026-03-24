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

  // When true, disconnected event does not schedule Timer-based reconnect
  // (used for app background pause; reconnect happens on app resume)
  bool _pausedForBackground = false;

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

    // Clear paused state on any connect. If only cleared on forceReconnect,
    // a manual connect after app was backgrounded (before any device connected)
    // would leave _pausedForBackground stuck true, silently disabling
    // auto-reconnect for the rest of the session.
    _pausedForBackground = false;

    // Already connected to same device (skip when forceReconnect)
    if (!forceReconnect &&
        _isConnected &&
        _device?.topicId == device.topicId &&
        _userId == userId) {
      _log.fine('Already connected to ${device.deviceId}');
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
      await _connectInternal();
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

  Future<void> _connectInternal() async {
    // Build WebSocket URL
    final wsUrl =
        '$_relayerUrl/api/notification?'
        'apiKey=$_apiKey&topicID=${_device!.topicId}&clientId=$_userId';

    _log.fine('WebSocket URL: ${wsUrl.replaceAll(_apiKey!, '***')}');

    // Spawn isolate if not already running
    if (_receivePort == null) {
      _receivePort = ReceivePort();
      _receiveSub = _receivePort!.listen(_handleIsolateMessage);
      _isolateReadyCompleter = Completer<void>();
      _isolate = await Isolate.spawn(
        _relayerIsolateEntry,
        _receivePort!.sendPort,
      );
    }

    // Wait for isolate to send back its SendPort
    if (_isolateSendPort == null) {
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

    // Reset reconnect attempts on successful connect
    _reconnectAttempts = 0;
  }

  @override
  Future<void> disconnect() async {
    _log.info('Disconnecting from relayer');

    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _reconnectAttempts = 0;

    // Send disconnect control message
    const control = _RelayerControlMessage(
      type: _RelayerControlType.disconnect,
    );
    _isolateSendPort?.send(control.toJson());

    await Future<void>.delayed(const Duration(milliseconds: 100));

    _isConnected = false;
    _connectionStateController.add(false);

    // Kill isolate
    unawaited(_receiveSub?.cancel());
    _receiveSub = null;
    _receivePort?.close();
    _receivePort = null;
    _isolate?.kill(priority: Isolate.immediate);
    _isolate = null;
    _isolateSendPort = null;
    _isolateReadyCompleter = null;

    // Clear cached connection params
    _device = null;
    _userId = null;
    _apiKey = null;
  }

  @override
  void pauseConnection() {
    _log.info('Pausing relayer connection (app background)');

    // Always cancel reconnect timers and set pause flag, even when already
    // disconnected. After a network drop, the transport can be !_isConnected
    // but still have an active _reconnectTimer from _scheduleReconnect().
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _pausedForBackground = true;

    // Always send disconnect when isolate exists. _connectInternal() drops
    // _isConnecting before the isolate sends its connection event, so there
    // is a window where both are false but WebSocket is still connecting.
    // Without this, the WebSocket could come up in background.
    if (_isolateSendPort != null) {
      const control = _RelayerControlMessage(
        type: _RelayerControlType.disconnect,
      );
      _isolateSendPort!.send(control.toJson());
    }

    if (_isConnected || _isConnecting) {
      _isConnected = false;
      _connectionStateController.add(false);
    }
  }

  @override
  void dispose() {
    unawaited(disconnect());
    unawaited(_notificationController.close());
    unawaited(_connectionStateController.close());
    unawaited(_errorController.close());
  }

  /// Handle message from isolate (connection events, notifications, errors).
  void _handleIsolateMessage(dynamic message) {
    if (message is! Map) {
      return;
    }

    final event = _RelayerEventMessage.fromJson(
      Map<String, dynamic>.from(message),
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
        }

      case _RelayerEventType.connected:
        _isConnected = true;
        _lastError = null;
        _reconnectAttempts = 0;
        _connectionStateController.add(true);
        _slog.info(
          category: LogCategory.wifi,
          event: 'ws_connected',
          message: 'WebSocket connected to relayer',
          payload: {'deviceId': _device?.deviceId, 'topicId': _device?.topicId},
        );

      case _RelayerEventType.disconnected:
        _isConnected = false;
        _connectionStateController.add(false);
        _slog.warning(
          category: LogCategory.wifi,
          event: 'ws_disconnected',
          message: 'WebSocket disconnected from relayer',
          payload: {
            'deviceId': _device?.deviceId,
            'pausedForBackground': _pausedForBackground,
            'reconnectAttempts': _reconnectAttempts,
            'lastError': _lastError,
          },
        );
        if (!_pausedForBackground) {
          _scheduleReconnect();
        }

      case _RelayerEventType.error:
        final errorMsg = event.data?['error'] as String? ?? 'Unknown error';
        _lastError = errorMsg;
        _slog.warning(
          category: LogCategory.wifi,
          event: 'ws_error',
          message: 'WebSocket error: $errorMsg',
          payload: {'deviceId': _device?.deviceId, 'error': errorMsg},
        );
        final error = FF1WifiNetworkError(errorMsg);
        _errorController.add(error);

      case _RelayerEventType.notification:
        final notificationData = event.data?['notification'] as Map?;
        if (notificationData != null) {
          try {
            final notification = FF1NotificationMessage.fromJson(
              Map<String, dynamic>.from(notificationData),
            );
            _notificationController.add(notification);
          } catch (e) {
            _log.warning('Failed to parse notification: $e');
            final error = FF1WifiMessageError(
              'Failed to parse notification',
              originalError: e,
            );
            _errorController.add(error);
          }
        }
    }
  }

  /// Schedule auto-reconnect with exponential backoff.
  void _scheduleReconnect() {
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
      _errorController.add(error);
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
      if (_isConnected || _isConnecting) {
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

/// Isolate entry point for WebSocket management
void _relayerIsolateEntry(SendPort mainSendPort) {
  final controlPort = ReceivePort();

  // Send back our SendPort
  final readyEvent = _RelayerEventMessage(
    type: _RelayerEventType.isolateReady,
    data: {'sendPort': controlPort.sendPort},
  );
  mainSendPort.send(readyEvent.toJson());

  WebSocketChannel? channel;
  StreamSubscription<dynamic>? channelSub;
  String? wsUrl;

  Future<void> closeChannel() async {
    await channelSub?.cancel();
    channelSub = null;
    await channel?.sink.close();
    channel = null;
  }

  Future<void> connect() async {
    if (wsUrl == null || wsUrl!.isEmpty) {
      return;
    }

    try {
      final uri = Uri.parse(wsUrl!);
      channel = WebSocketChannel.connect(uri);

      channelSub = channel!.stream.listen(
        (dynamic rawMessage) {
          try {
            if (rawMessage is! String) {
              return;
            }

            final decoded = jsonDecode(rawMessage) as Map<String, dynamic>;
            final notification = FF1NotificationMessage.fromJson(decoded);

            const event = _RelayerEventMessage(
              type: _RelayerEventType.notification,
            );
            final eventData = <String, dynamic>{
              ...event.toJson(),
              'data': {'notification': notification.toJson()},
            };
            mainSendPort.send(eventData);
          } on Exception {
            // Ignore parse errors
          }
        },
        onError: (Object error) {
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
        },
        onDone: () {
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
    } on Exception catch (e) {
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
    }
  }

  controlPort.listen((dynamic rawMessage) async {
    if (rawMessage is! Map) {
      return;
    }

    final control = _RelayerControlMessage.fromJson(
      Map<String, dynamic>.from(rawMessage),
    );

    switch (control.type) {
      case _RelayerControlType.connect:
        wsUrl = control.data?['wsUrl'] as String?;
        await closeChannel();
        await connect();

      case _RelayerControlType.disconnect:
        unawaited(closeChannel());
        const event = _RelayerEventMessage(
          type: _RelayerEventType.disconnected,
        );
        mainSendPort.send(event.toJson());

      case _RelayerControlType.dispose:
        unawaited(closeChannel());
        controlPort.close();
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
