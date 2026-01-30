import 'package:app/domain/models/ff1_device.dart';
import 'package:app/infra/config/app_config.dart';
import 'package:app/infra/ff1/wifi_control/ff1_wifi_control.dart';
import 'package:app/infra/ff1/wifi_control/ff1_wifi_rest_client.dart';
import 'package:app/infra/ff1/wifi_protocol/ff1_wifi_messages.dart';
import 'package:app/infra/ff1/wifi_transport/ff1_relayer_transport.dart';
import 'package:app/infra/ff1/wifi_transport/ff1_wifi_transport.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';

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
    this.device,
    this.error,
  });

  /// Whether device is connected over WiFi.
  final bool isConnected;

  /// Connected device.
  final FF1Device? device;

  /// Last error (if any).
  final Object? error;

  /// Copy with updated fields.
  FF1WifiConnectionState copyWith({
    bool? isConnected,
    FF1Device? device,
    Object? error,
  }) {
    return FF1WifiConnectionState(
      isConnected: isConnected ?? this.isConnected,
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

    state = state.copyWith(device: device);

    try {
      await _control.connect(
        device: device,
        userId: userId,
        apiKey: apiKey,
      );

      state = state.copyWith(
        isConnected: true,
        device: device,
      );
    } on Exception catch (e) {
      state = state.copyWith(
        isConnected: false,
        error: e,
      );
      rethrow;
    }
  }

  /// Disconnect from device
  Future<void> disconnect() async {
    if (!state.isConnected) {
      return;
    }

    try {
      await _control.disconnect();
    } finally {
      state = const FF1WifiConnectionState(isConnected: false);
    }
  }

  /// Reconnect to device (using cached params)
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

/// Current player status provider (last received value)
///
/// Returns the most recent player status or null if none received.
final ff1CurrentPlayerStatusProvider = Provider<FF1PlayerStatus?>((ref) {
  final control = ref.watch(ff1WifiControlProvider);
  return control.currentPlayerStatus;
});

/// Current device status provider (last received value)
///
/// Returns the most recent device status or null if none received.
final ff1CurrentDeviceStatusProvider = Provider<FF1DeviceStatus?>((ref) {
  final control = ref.watch(ff1WifiControlProvider);
  return control.currentDeviceStatus;
});

/// Device connected provider (per connection notification)
///
/// Returns true if device sent "connected" status, false otherwise.
final ff1DeviceConnectedProvider = Provider<bool>((ref) {
  final control = ref.watch(ff1WifiControlProvider);
  return control.isDeviceConnected;
});
