/// FF1 WiFi Transport: abstract interface for WiFi adapters.
///
/// This defines the transport interface that all WiFi adapters must implement.
/// Adapters handle the actual communication (WebSocket, HTTP, LAN, etc.)
/// but expose a common interface to the control layer.
///
/// Separation: Transport handles connection/data transfer. Protocol handles
/// message encoding/decoding. Control orchestrates commands and state.
library;

import 'dart:async';

import 'package:app/domain/models/ff1_device.dart';
import 'package:app/infra/ff1/wifi_protocol/ff1_wifi_messages.dart';

// ============================================================================
// Transport interface (abstract)
// ============================================================================

/// Abstract interface for FF1 WiFi transport adapters
///
/// Implementations:
/// - FF1RelayerTransport: WebSocket connection through relayer server
/// - FF1LanTransport (future): Direct HTTP/WebSocket connection over LAN
abstract class FF1WifiTransport {
  /// Connect to device (establish transport-level connection)
  ///
  /// [device] - FF1 device with topicId
  /// [userId] - user identifier for authentication
  /// [apiKey] - API key for authentication
  ///
  /// Throws: [FF1WifiTransportError] if connection fails
  Future<void> connect({
    required FF1Device device,
    required String userId,
    required String apiKey,
  });

  /// Disconnect from device (close transport connection)
  Future<void> disconnect();

  /// Check if transport is connected
  bool get isConnected;

  /// Stream of incoming notification messages from device
  ///
  /// Only emits [FF1NotificationMessage] types (device → app status updates).
  /// Control layer subscribes to this stream to react to device state changes.
  Stream<FF1NotificationMessage> get notificationStream;

  /// Stream of connection state changes
  ///
  /// Emits true when connected, false when disconnected.
  /// Useful for UI indicators and auto-reconnect logic.
  Stream<bool> get connectionStateStream;

  /// Stream of transport errors
  ///
  /// Emits errors that occur during connection or message handling.
  /// Control layer can log these or trigger error recovery.
  Stream<FF1WifiTransportError> get errorStream;

  /// Send a command to device (future: app → device RPC)
  ///
  /// Currently not implemented (receive-only).
  /// Future versions will support bidirectional communication.
  Future<void> sendCommand(Map<String, dynamic> command) async {
    throw UnimplementedError('Sending commands not yet supported');
  }

  /// Dispose transport and clean up resources
  void dispose();
}

// ============================================================================
// Transport errors
// ============================================================================

/// Base class for WiFi transport errors.
abstract class FF1WifiTransportError implements Exception {
  /// Creates a transport error.
  const FF1WifiTransportError(this.message, {this.originalError});

  /// Error message.
  final String message;

  /// Original error (if any).
  final Object? originalError;

  @override
  String toString() => 'FF1WifiTransportError: $message'
      '${originalError != null ? ' ($originalError)' : ''}';
}

/// Connection failed (initial connection or reconnection).
class FF1WifiConnectionError extends FF1WifiTransportError {
  /// Creates a connection error.
  const FF1WifiConnectionError(super.message, {super.originalError});
}

/// WebSocket/network error during active connection.
class FF1WifiNetworkError extends FF1WifiTransportError {
  /// Creates a network error.
  const FF1WifiNetworkError(super.message, {super.originalError});
}

/// Message parsing/decoding error.
class FF1WifiMessageError extends FF1WifiTransportError {
  /// Creates a message error.
  const FF1WifiMessageError(super.message, {super.originalError});
}

/// Transport not available (no topicId, missing credentials, etc.).
class FF1WifiTransportUnavailableError extends FF1WifiTransportError {
  /// Creates a transport unavailable error.
  const FF1WifiTransportUnavailableError(
    super.message, {
    super.originalError,
  });
}
