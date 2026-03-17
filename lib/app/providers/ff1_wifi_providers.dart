import 'dart:async';

import 'package:app/app/providers/ff1_bluetooth_device_providers.dart';
import 'package:app/app/providers/version_provider.dart';
import 'package:app/domain/models/ff1_device.dart';
import 'package:app/infra/config/app_config.dart';
import 'package:app/infra/ff1/wifi_control/ff1_wifi_control.dart';
import 'package:app/infra/ff1/wifi_control/ff1_wifi_rest_client.dart';
import 'package:app/infra/ff1/wifi_protocol/ff1_wifi_messages.dart';
import 'package:app/infra/ff1/wifi_transport/ff1_relayer_transport.dart';
import 'package:app/infra/ff1/wifi_transport/ff1_wifi_transport.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:riverpod/src/providers/future_provider.dart';

// ============================================================================
// Custom Retry Logic for WiFi Operations
// ============================================================================

/// Retry logic for WiFi operations (connect, commands).
///
/// Retries up to 5 times with exponential backoff (200ms to 3.2s).
/// Does not retry on Errors (programming bugs).
Duration? _wifiRetry(int retryCount, Object error) {
  // Don't retry errors (programming bugs - indicate code issues)
  if (error is Error) {
    return null;
  }

  // Max 5 retries
  if (retryCount >= 5) return null;

  // Exponential backoff: 200ms, 400ms, 800ms, 1.6s, 3.2s
  return Duration(milliseconds: 200 * (1 << retryCount));
}

// ============================================================================
// FF1 WiFi Transport and Control providers (infrastructure)
// ============================================================================

/// FF1 WiFi transport provider (Relayer adapter)
///
/// This provides the transport layer for WiFi communication.
/// Currently uses Relayer adapter (WebSocket through cloud).
/// Future: can be swapped with LAN adapter for direct local communication.
final ff1WifiTransportProvider = Provider<FF1WifiTransport>((ref) {
  final logger = Logger('FF1RelayerTransport');
  return FF1RelayerTransport(
    relayerUrl: AppConfig.ff1RelayerUrl,
    logger: logger,
  );
});

/// FF1 WiFi REST client provider (for sending commands)
///
/// This provides the HTTP client for sending commands to FF1 devices
/// via the Relayer's REST API endpoint.
final ff1WifiRestClientProvider = Provider<FF1WifiRestClient>((ref) {
  return FF1WifiRestClient(
    castApiUrl: AppConfig.ff1CastApiUrl,
    apiKey: AppConfig.ff1RelayerApiKey,
    logger: Logger('FF1WifiRestClient'),
  );
});

/// FF1 WiFi control provider (orchestration)
///
/// This provides the control layer for WiFi communication.
/// Use this provider to:
/// - Connect/disconnect from devices over WiFi
/// - Subscribe to player status updates
/// - Subscribe to device status updates
/// - Subscribe to connection status updates
/// - Send commands to devices (rotate, pause, play, etc.)
final ff1WifiControlProvider = Provider<FF1WifiControl>((ref) {
  final transport = ref.watch(ff1WifiTransportProvider);
  final restClient = ref.watch(ff1WifiRestClientProvider);

  final control = FF1WifiControl(
    transport: transport,
    restClient: restClient,
    logger: Logger('FF1WifiControl'),
  );

  // Dispose control when provider is disposed
  ref.onDispose(control.dispose);

  return control;
});

// ============================================================================
// FF1 WiFi connection state provider
// ============================================================================

/// Connection state for a specific device.
class FF1WifiConnectionState {
  /// Creates a connection state.
  const FF1WifiConnectionState({
    required this.isConnected,
    this.isConnecting = false,
    this.device,
    this.error,
  });

  /// Whether device is connected over WiFi.
  final bool isConnected;

  /// Whether connection is in progress (establishing WebSocket).
  final bool isConnecting;

  /// Connected device.
  final FF1Device? device;

  /// Last error (if any).
  final Object? error;

  /// Copy with updated fields.
  FF1WifiConnectionState copyWith({
    bool? isConnected,
    bool? isConnecting,
    FF1Device? device,
    Object? error,
  }) {
    return FF1WifiConnectionState(
      isConnected: isConnected ?? this.isConnected,
      isConnecting: isConnecting ?? this.isConnecting,
      device: device ?? this.device,
      error: error,
    );
  }

  @override
  String toString() =>
      'FF1WifiConnectionState(connected: $isConnected, device: ${device?.deviceId})';
}

/// FF1 WiFi connection notifier
///
/// Manages connection lifecycle and state for a single device.
class FF1WifiConnectionNotifier extends Notifier<FF1WifiConnectionState> {
  FF1WifiControl get _control => ref.read(ff1WifiControlProvider);

  @override
  FF1WifiConnectionState build() {
    return const FF1WifiConnectionState(isConnected: false);
  }

  /// Connect to device over WiFi
  ///
  /// [device] - FF1 device with topicId
  /// [userId] - user identifier for authentication
  /// [apiKey] - API key for authentication
  Future<void> connect({
    required FF1Device device,
    required String userId,
    required String apiKey,
  }) async {
    if (state.isConnected && state.device?.topicId == device.topicId) {
      return;
    }

    state = state.copyWith(device: device, isConnecting: true);

    try {
      await _control.connect(
        device: device,
        userId: userId,
        apiKey: apiKey,
      );

      state = state.copyWith(
        isConnected: true,
        isConnecting: false,
        device: device,
      );
    } on Exception catch (e) {
      state = state.copyWith(
        isConnected: false,
        isConnecting: false,
        error: e,
      );
      rethrow;
    } finally {
      if (state.isConnecting) {
        state = state.copyWith(isConnecting: false);
      }
    }
  }

  /// Disconnect from device
  ///
  /// Always clears state when called, even when already disconnected (e.g.
  /// after pauseConnection). When active device becomes null while app is
  /// backgrounded, the watcher calls disconnect(); without clearing state,
  /// reconnect() on resume would use the stale cached device.
  Future<void> disconnect() async {
    if (state.isConnected) {
      try {
        await _control.disconnect();
      } finally {
        state = const FF1WifiConnectionState(isConnected: false);
      }
    } else {
      state = const FF1WifiConnectionState(isConnected: false);
    }
  }

  /// Pause connection when app goes to background.
  ///
  /// Closes WebSocket but preserves [state.device] for [reconnect] on resume.
  void pauseConnection() {
    _control.pauseConnection();
    state = state.copyWith(isConnected: false);
  }

  /// Reconnect to device (using cached params)
  ///
  /// Does not set [isConnecting]; "Connecting" status is shown only for
  /// initial connect, not for background reconnects (app resume, etc.).
  Future<void> reconnect() async {
    if (state.device == null) {
      return;
    }

    try {
      await _control.reconnect();

      state = state.copyWith(isConnected: true);
    } on Exception catch (e) {
      state = state.copyWith(
        isConnected: false,
        error: e,
      );
    }
  }
}

/// FF1 WiFi connection state provider
final ff1WifiConnectionProvider =
    NotifierProvider<FF1WifiConnectionNotifier, FF1WifiConnectionState>(
      FF1WifiConnectionNotifier.new,
    );

// ============================================================================
// FF1 WiFi device state providers (player status, device status)
// ============================================================================

/// Current player status stream provider
///
/// Emits updates when device sends player status notifications.
/// Use this to react to playback changes (playlist, work, pause/play).
final ff1PlayerStatusStreamProvider = StreamProvider<FF1PlayerStatus>((ref) {
  final control = ref.watch(ff1WifiControlProvider);
  return control.playerStatusStream;
});

/// Current device status stream provider
///
/// Emits updates when device sends device status notifications.
/// Use this to react to device state changes (WiFi, internet, version).
final ff1DeviceStatusStreamProvider = StreamProvider<FF1DeviceStatus>((ref) {
  final control = ref.watch(ff1WifiControlProvider);
  return control.deviceStatusStream;
});

/// Current connection status stream provider.
///
/// Emits updates when device sends connection status notifications.
/// Use this to display device online/offline state.
final ff1ConnectionStatusStreamProvider = StreamProvider<FF1ConnectionStatus>(
  (ref) {
    final control = ref.watch(ff1WifiControlProvider);
    return control.connectionStatusStream;
  },
);

/// Whether the connected FF1 device supports shuffle and loop modes.
///
/// Returns true only when the device has sent a player status that includes
/// [FF1PlayerStatus.shuffle] or [FF1PlayerStatus.loopMode] — these fields
/// are absent on older firmware that does not support playback modes.
final ff1SupportsPlaybackModesProvider = Provider<bool>((ref) {
  final status = ref.watch(ff1CurrentPlayerStatusProvider);
  return status != null && status.shuffle != null && status.loopMode != null;
});

/// Current player status provider (last received value)
///
/// Returns the most recent player status or null if none received.
final ff1CurrentPlayerStatusProvider = Provider<FF1PlayerStatus?>((ref) {
  final controlAsync = ref.watch(ff1PlayerStatusStreamProvider);
  return controlAsync.when(
    data: (status) => status,
    loading: () => null,
    error: (_, _) => null,
  );
});

/// Current device status provider (last received value)
///
/// Returns the most recent device status or null if none received.
final ff1CurrentDeviceStatusProvider = Provider<FF1DeviceStatus?>((ref) {
  final controlAsync = ref.watch(ff1DeviceStatusStreamProvider);
  return controlAsync.when(
    data: (status) => status,
    loading: () => null,
    error: (_, _) => null,
  );
});

/// Device connected provider (per connection notification)
///
/// Returns true if device sent "connected" status, false otherwise.
/// Uses connection status stream so UI reacts when FF1WifiControl receives
/// connection notifications (Provider over FF1WifiControl does not notify on
/// internal state changes).
final ff1DeviceConnectedProvider = Provider<bool>((ref) {
  final connectionStatusAsync = ref.watch(ff1ConnectionStatusStreamProvider);
  return connectionStatusAsync.when(
    data: (status) => status.isConnected,
    loading: () => false,
    error: (_, _) => false,
  );
});

/// Whether WebSocket connection to relayer is in progress.
///
/// Used by now displaying bar to show "Connecting to FF1-XXX" during connect.
final ff1WifiConnectingProvider = Provider<bool>((ref) {
  final connectionState = ref.watch(ff1WifiConnectionProvider);
  return connectionState.isConnecting;
});

// ============================================================================
// Auto-connect to active FF1 device
// ============================================================================

/// Auto-connect watcher provider
///
/// This provider watches the active FF1 device and automatically connects
/// to the relayer when the active device changes.
/// It also disconnects when there is no active device.
///
/// This provider should be kept alive by the app
/// (e.g., in bootstrap or root).
final ff1AutoConnectWatcherProvider = Provider<void>((ref) {
  final logger = Logger('FF1AutoConnectWatcher');
  final activeDeviceAsync = ref.watch(activeFF1BluetoothDeviceProvider);
  final connectionNotifier = ref.read(ff1WifiConnectionProvider.notifier);

  activeDeviceAsync.when(
    data: (device) async {
      // Use Future.microtask to defer the connection call
      // to avoid modifying other providers during build phase
      unawaited(
        Future.microtask(() async {
          if (device != null) {
            logger.info(
              'Active device changed: ${device.toJson()}, connecting...',
            );
            // Intentionally not awaiting to avoid blocking
            await connectionNotifier.connect(
              device: device,
              userId: 'user_id',
              apiKey: AppConfig.ff1RelayerApiKey,
            );

            final versionService = ref.read(versionServiceProvider);
            final deviceStatus = ref.read(ff1CurrentDeviceStatusProvider);
            unawaited(
              versionService.checkDeviceVersionCompatibility(
                branchName: device.branchName,
                deviceVersion: deviceStatus?.latestVersion ?? '',
                requiredDeviceUpdate: true,
              ),
            );
          } else {
            logger.info('No active device, disconnecting...');
            // Intentionally not awaiting to avoid blocking
            connectionNotifier.disconnect();
          }
        }),
      );
    },
    error: (error, stack) {
      logger.severe('Error loading active device', error, stack);
    },
    loading: () {
      logger.info('Loading active device...');
    },
  );
});

// ============================================================================
// Auto-dispose WiFi Operation Providers (with automatic retry)
// ============================================================================

/// Parameters for WiFi connection
class FF1WifiConnectParams {
  const FF1WifiConnectParams({
    required this.device,
    required this.userId,
    required this.apiKey,
  });

  final FF1Device device;
  final String userId;
  final String apiKey;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FF1WifiConnectParams &&
          runtimeType == other.runtimeType &&
          device.topicId == other.device.topicId &&
          userId == other.userId;

  @override
  int get hashCode => device.topicId.hashCode ^ userId.hashCode;
}

/// Connect to FF1 device via WiFi (auto-dispose, with retry).
///
/// This provider automatically disposes after use.
/// Uses Riverpod's automatic retry mechanism (5 attempts with exponential backoff).
///
/// Usage:
/// ```dart
/// await ref.read(
///   ff1WifiConnectOperationProvider(FF1WifiConnectParams(
///     device: device,
///     userId: userId,
///     apiKey: apiKey,
///   )).future,
/// );
/// ```
final FutureProviderFamily<void, FF1WifiConnectParams>
ff1WifiConnectOperationProvider = FutureProvider.autoDispose
    .family<void, FF1WifiConnectParams>(
      retry: _wifiRetry,
      (ref, params) async {
        final control = ref.watch(ff1WifiControlProvider);

        await control.connect(
          device: params.device,
          userId: params.userId,
          apiKey: params.apiKey,
        );
      },
    );

/// Parameters for WiFi command execution
class FF1WifiCommandParams<T> {
  const FF1WifiCommandParams({
    required this.topicId,
    required this.commandFn,
  });

  final String topicId;
  final Future<T> Function(FF1WifiControl control, String topicId) commandFn;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FF1WifiCommandParams<T> &&
          runtimeType == other.runtimeType &&
          topicId == other.topicId;

  @override
  int get hashCode => topicId.hashCode;
}

/// Send WiFi command to device (auto-dispose, with retry).
///
/// This provider automatically disposes after use.
/// Uses Riverpod's automatic retry mechanism.
///
/// Usage:
/// ```dart
/// final response = await ref.read(
///   ff1WifiSendCommandProvider<FF1CommandResponse>(FF1WifiCommandParams(
///     topicId: topicId,
///     commandFn: (control, id) => control.rotate(topicId: id, angle: 90),
///   )).future,
/// );
/// ```
final FutureProviderFamily<dynamic, FF1WifiCommandParams<dynamic>>
ff1WifiSendCommandProvider = FutureProvider.autoDispose
    .family<dynamic, FF1WifiCommandParams<dynamic>>(
      retry: _wifiRetry,
      (ref, params) async {
        final control = ref.watch(ff1WifiControlProvider);

        return params.commandFn(control, params.topicId);
      },
    );
