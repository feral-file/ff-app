// This provider file still contains legacy analyzer noise that is outside the
// firmware-update flow; keep the ignore local so this PR can be gated on the
// new prompt/update behavior instead of a broader cleanup pass.
// ignore_for_file: lines_longer_than_80_chars, comment_references, public_member_api_docs, avoid_equals_and_hash_code_on_mutable_classes

import 'dart:async';

import 'package:app/app/providers/ff1_bluetooth_device_providers.dart';
import 'package:app/app/providers/version_provider.dart';
import 'package:app/domain/models/ff1/ffp_ddc_panel_status.dart';
import 'package:app/domain/models/ff1_device.dart';
import 'package:app/infra/config/app_config.dart';
import 'package:app/infra/ff1/wifi_control/ff1_wifi_control.dart';
import 'package:app/infra/ff1/wifi_control/ff1_wifi_rest_client.dart';
import 'package:app/infra/ff1/wifi_protocol/ff1_wifi_messages.dart';
import 'package:app/infra/ff1/wifi_transport/ff1_relayer_transport.dart';
import 'package:app/infra/ff1/wifi_transport/ff1_wifi_transport.dart';
import 'package:app/infra/logging/structured_logger.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:riverpod/riverpod.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

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
      'FF1WifiConnectionState('
      'connected: $isConnected, device: ${device?.deviceId})';
}

/// FF1 WiFi connection notifier
///
/// Manages connection lifecycle and state for a single device.
class FF1WifiConnectionNotifier extends Notifier<FF1WifiConnectionState> {
  FF1WifiControl get _control => ref.read(ff1WifiControlProvider);
  late final Logger _log;
  late final StructuredLogger _slog;
  int _connectEpoch = 0;
  int? _connectingEpoch;
  String? _requiredDeviceVersionCheckCompletedForDeviceId;
  String? _requiredDeviceVersionCheckInFlightForDeviceId;

  @override
  FF1WifiConnectionState build() {
    _log = Logger('FF1WifiConnectionNotifier');
    _slog = AppStructuredLog.forLogger(
      _log,
      context: {'component': 'ff1_wifi_connection_notifier'},
    );
    return const FF1WifiConnectionState(isConnected: false);
  }

  void _scheduleRequiredDeviceVersionCheckIfNeeded(FF1Device device) {
    if (_requiredDeviceVersionCheckCompletedForDeviceId == device.deviceId) {
      return;
    }
    if (_requiredDeviceVersionCheckInFlightForDeviceId == device.deviceId) {
      return;
    }

    // The first session that actually observes a version-bearing device
    // status owns the required-version gate. If the session is paused before
    // that status arrives, the gate must be allowed to re-arm on resume.
    _requiredDeviceVersionCheckInFlightForDeviceId = device.deviceId;
    unawaited(
      _scheduleRequiredDeviceVersionCheck(
        ref: ref,
        logger: _log,
        device: device,
      ).then((completed) {
        if (_requiredDeviceVersionCheckInFlightForDeviceId == device.deviceId) {
          _requiredDeviceVersionCheckInFlightForDeviceId = null;
        }
        if (completed) {
          _requiredDeviceVersionCheckCompletedForDeviceId = device.deviceId;
        }
      }),
    );
  }

  /// Connect to device over WiFi
  ///
  /// [device] - FF1 device with topicId
  /// [userId] - user identifier for authentication
  /// [apiKey] - API key for authentication
  ///
  /// Returns `false` when the session was not established (superseded,
  /// suppressed transport dispatch, etc.). Callers such as the auto-connect
  /// watcher use this to avoid follow-up work (e.g. version checks).
  Future<bool> connect({
    required FF1Device device,
    required String userId,
    required String apiKey,
  }) async {
    final epoch = ++_connectEpoch;
    _slog.info(
      category: LogCategory.wifi,
      event: 'connection_notifier_connect_requested',
      message: 'connect requested by app layer',
      payload: {
        'deviceId': device.deviceId,
        'topicId': device.topicId,
        'stateConnected': state.isConnected,
        'stateConnecting': state.isConnecting,
      },
    );
    if (state.isConnected && state.device?.topicId == device.topicId) {
      _scheduleRequiredDeviceVersionCheckIfNeeded(device);
      _slog.info(
        category: LogCategory.wifi,
        event: 'connection_notifier_connect_skipped',
        message: 'connect skipped because notifier is already connected',
        payload: {'deviceId': device.deviceId, 'topicId': device.topicId},
      );
      return true;
    }

    if (state.device?.deviceId != device.deviceId) {
      _requiredDeviceVersionCheckCompletedForDeviceId = null;
      _requiredDeviceVersionCheckInFlightForDeviceId = null;
    }

    state = state.copyWith(device: device, isConnecting: true);
    _connectingEpoch = epoch;

    try {
      final ok = await _control.connect(
        device: device,
        userId: userId,
        apiKey: apiKey,
      );

      if (epoch != _connectEpoch) {
        _slog.info(
          category: LogCategory.wifi,
          event: 'connection_notifier_connect_canceled',
          message: 'connect completed after a newer connection request',
          payload: {'deviceId': device.deviceId, 'topicId': device.topicId},
        );
        return false;
      }

      if (!ok) {
        state = state.copyWith(
          isConnected: false,
          isConnecting: false,
          device: device,
        );
        _slog.info(
          category: LogCategory.wifi,
          event: 'connection_notifier_connect_not_applied',
          message:
              'connect did not dispatch (suppressed or superseded at transport)',
          payload: {'deviceId': device.deviceId, 'topicId': device.topicId},
        );
        return false;
      }

      // [FF1WifiControl.connect] may return without throwing after swallowing
      // [FF1WifiConnectionCancelledError] (e.g. pause during transport prep).
      // In that case no socket is open; do not mark the notifier connected.
      if (!_control.isConnected) {
        _slog.info(
          category: LogCategory.wifi,
          event: 'connection_notifier_connect_no_transport',
          message:
              'connect returned but transport is not connected (cancelled/no-op)',
          payload: {'deviceId': device.deviceId, 'topicId': device.topicId},
        );
        state = state.copyWith(
          isConnected: false,
          isConnecting: false,
          device: device,
        );
        return false;
      }

      state = state.copyWith(
        isConnected: true,
        isConnecting: false,
        device: device,
      );
      _scheduleRequiredDeviceVersionCheckIfNeeded(device);
      _slog.info(
        category: LogCategory.wifi,
        event: 'connection_notifier_connect_completed',
        message: 'connect completed in notifier',
        payload: {'deviceId': device.deviceId, 'topicId': device.topicId},
      );
      return true;
    } on Exception catch (e) {
      if (epoch != _connectEpoch) {
        _slog.info(
          category: LogCategory.wifi,
          event: 'connection_notifier_connect_canceled_error',
          message: 'connect failed after cancellation; ignoring stale error',
          payload: {
            'deviceId': device.deviceId,
            'topicId': device.topicId,
            'error': e.toString(),
          },
        );
        return false;
      }
      state = state.copyWith(
        isConnected: false,
        isConnecting: false,
        error: e,
      );
      _slog.warning(
        category: LogCategory.wifi,
        event: 'connection_notifier_connect_failed',
        message: 'connect failed in notifier',
        payload: {'deviceId': device.deviceId, 'error': e.toString()},
        error: e,
      );
      rethrow;
    } finally {
      // Only the connect attempt that still owns the spinner may clear it.
      // Pause/disconnect already clear `isConnecting`, while a newer connect
      // must keep the UI in "connecting" until that replacement attempt ends.
      if (_connectingEpoch == epoch && state.isConnecting) {
        _connectingEpoch = null;
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
    _connectEpoch++;
    _connectingEpoch = null;
    _requiredDeviceVersionCheckCompletedForDeviceId = null;
    _requiredDeviceVersionCheckInFlightForDeviceId = null;
    _slog.info(
      category: LogCategory.wifi,
      event: 'connection_notifier_disconnect_requested',
      message: 'disconnect requested by app layer',
      payload: {
        'deviceId': state.device?.deviceId,
        'stateConnected': state.isConnected,
        'stateConnecting': state.isConnecting,
      },
    );
    if (state.isConnected || state.isConnecting) {
      try {
        await _control.disconnect();
      } finally {
        state = const FF1WifiConnectionState(isConnected: false);
      }
    } else {
      state = const FF1WifiConnectionState(isConnected: false);
    }
    _slog.info(
      category: LogCategory.wifi,
      event: 'connection_notifier_disconnect_completed',
      message: 'disconnect completed in notifier',
      payload: {'stateConnected': state.isConnected},
    );
  }

  /// Pause connection when app goes to background.
  ///
  /// Closes WebSocket but preserves [state.device] for [reconnect] on resume.
  void pauseConnection() {
    _connectEpoch++;
    _connectingEpoch = null;
    _requiredDeviceVersionCheckInFlightForDeviceId = null;
    _slog.info(
      category: LogCategory.wifi,
      event: 'connection_notifier_pause_requested',
      message: 'pause requested by app layer',
      payload: {
        'deviceId': state.device?.deviceId,
        'stateConnected': state.isConnected,
        'stateConnecting': state.isConnecting,
      },
    );
    _control.pauseConnection();
    state = state.copyWith(isConnected: false, isConnecting: false);
    _slog.info(
      category: LogCategory.wifi,
      event: 'connection_notifier_pause_completed',
      message: 'pause completed in notifier',
      payload: {
        'deviceId': state.device?.deviceId,
        'stateConnected': state.isConnected,
      },
    );
  }

  /// Reconnect to device (using cached params)
  ///
  /// Does not set [isConnecting] to true; "Connecting" is reserved for the
  /// initial [connect] path, not background reconnects (app resume, etc.).
  Future<void> reconnect() async {
    _connectingEpoch = null;
    _slog.info(
      category: LogCategory.wifi,
      event: 'connection_notifier_reconnect_requested',
      message: 'reconnect requested by app layer',
      payload: {
        'deviceId': state.device?.deviceId,
        'stateConnected': state.isConnected,
        'stateConnecting': state.isConnecting,
      },
    );
    if (state.device == null) {
      _slog.info(
        category: LogCategory.wifi,
        event: 'connection_notifier_reconnect_skipped',
        message: 'reconnect skipped: notifier has no cached device',
      );
      return;
    }

    final epoch = ++_connectEpoch;
    try {
      final ok = await _control.reconnect();

      if (epoch != _connectEpoch) {
        _slog.info(
          category: LogCategory.wifi,
          event: 'connection_notifier_reconnect_canceled',
          message: 'reconnect completed after a newer connection/pause request',
          payload: {'deviceId': state.device?.deviceId},
        );
        return;
      }

      if (!ok) {
        state = state.copyWith(isConnected: false, isConnecting: false);
        _slog.info(
          category: LogCategory.wifi,
          event: 'connection_notifier_reconnect_not_applied',
          message:
              'reconnect did not apply (skipped, superseded, or transport error)',
          payload: {'deviceId': state.device?.deviceId},
        );
        return;
      }

      state = state.copyWith(isConnected: true, isConnecting: false);
      _scheduleRequiredDeviceVersionCheckIfNeeded(state.device!);
      _slog.info(
        category: LogCategory.wifi,
        event: 'connection_notifier_reconnect_completed',
        message: 'reconnect completed in notifier',
        payload: {
          'deviceId': state.device?.deviceId,
          'stateConnected': state.isConnected,
        },
      );
    } on Exception catch (e) {
      if (epoch != _connectEpoch) {
        _slog.info(
          category: LogCategory.wifi,
          event: 'connection_notifier_reconnect_canceled_error',
          message: 'reconnect failed after cancellation; ignoring stale error',
          payload: {
            'deviceId': state.device?.deviceId,
            'error': e.toString(),
          },
        );
        return;
      }
      state = state.copyWith(
        isConnected: false,
        isConnecting: false,
        error: e,
      );
      _slog.warning(
        category: LogCategory.wifi,
        event: 'connection_notifier_reconnect_failed',
        message: 'reconnect failed in notifier',
        payload: {'deviceId': state.device?.deviceId, 'error': e.toString()},
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

/// Current FFP DDC panel status stream provider for a specific FF1 topic.
///
/// This is scoped by topic id so a stale widget cannot read panel state from
/// one active FF1 and send writes to a different FF1 topic.
// ignore: specify_nonobvious_property_types
final ff1FfpDdcPanelStatusStreamProvider = StreamProvider.autoDispose
    .family<FfpDdcPanelStatus, String>((ref, topicId) {
      if (topicId.isEmpty) {
        return const Stream<FfpDdcPanelStatus>.empty();
      }

      final activeDeviceAsync = ref.watch(activeFF1BluetoothDeviceProvider);
      final activeTopicId = activeDeviceAsync.maybeWhen(
        data: (device) => device?.topicId ?? '',
        orElse: () => '',
      );
      if (activeTopicId != topicId) {
        return Stream<FfpDdcPanelStatus>.value(const FfpDdcPanelStatus());
      }

      final control = ref.watch(ff1WifiControlProvider);
      return control.ffpDdcPanelStatusStream;
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
/// both [FF1PlayerStatus.shuffle] and [FF1PlayerStatus.loopMode] — these fields
/// are absent on older firmware that does not support playback modes.
final ff1SupportsPlaybackModesProvider = Provider<bool>((ref) {
  final status = ref.watch(ff1CurrentPlayerStatusProvider);
  return status != null && status.shuffle != null && status.loopMode != null;
});

/// Current player status provider (last received value)
///
/// Returns the most recent player status or null if none received.
///
/// This watches the stream only for invalidation and reads the control-layer
/// cache for the actual value. `FF1WifiControl.playerStatusStream` replays the
/// last payload, so after a device switch the stream may still hold device A's
/// status until device B emits its first player-status notification.
final ff1CurrentPlayerStatusProvider = Provider<FF1PlayerStatus?>((ref) {
  ref
    ..watch(ff1PlayerStatusStreamProvider)
    ..watch(ff1ConnectionStatusStreamProvider);
  final device = ref
      .watch(activeFF1BluetoothDeviceProvider)
      .maybeWhen(data: (d) => d, orElse: () => null);
  final control = ref.read(ff1WifiControlProvider);
  return control.currentPlayerStatusDeviceId == device?.deviceId
      ? control.currentPlayerStatus
      : null;
});

/// Current device status provider (last received value)
///
/// Returns the most recent device status or null if none received.
///
/// Mirrors [ff1CurrentPlayerStatusProvider] so device switches do not expose
/// replayed device-status data from the previous control session.
final ff1CurrentDeviceStatusProvider = Provider<FF1DeviceStatus?>((ref) {
  ref
    ..watch(ff1DeviceStatusStreamProvider)
    ..watch(ff1ConnectionStatusStreamProvider);
  final device = ref
      .watch(activeFF1BluetoothDeviceProvider)
      .maybeWhen(data: (d) => d, orElse: () => null);
  final control = ref.read(ff1WifiControlProvider);
  return control.currentDeviceStatusDeviceId == device?.deviceId
      ? control.currentDeviceStatus
      : null;
});

/// Device connected provider (per connection notification)
///
/// Returns true if device sent "connected" status, false otherwise.
/// Uses connection status stream so UI reacts when FF1WifiControl receives
/// connection notifications (Provider over FF1WifiControl does not notify on
/// internal state changes).
final ff1DeviceConnectedProvider = Provider<bool>((ref) {
  ref.watch(ff1ConnectionStatusStreamProvider);
  return ref.read(ff1WifiControlProvider).isDeviceConnected;
});

/// Stream of transport-level (e.g. WebSocket) connected from `FF1WifiControl`.
///
/// Unlike [ff1WifiConnectionProvider], this tracks real transport up/down
/// events from `FF1WifiTransport.connectionStateStream` (seeded with the
/// current flag) so unexpected drops are visible immediately.
final ff1WifiTransportConnectedStreamProvider = StreamProvider<bool>((ref) {
  final control = ref.watch(ff1WifiControlProvider);
  return control.transportConnectionStates();
});

/// Latest transport (WebSocket) connected flag aligned with the transport
/// layer.
///
/// Do not substitute `FF1WifiConnectionNotifier.isConnected` here: that
/// value is only updated by connect / reconnect / pause / disconnect and can
/// stay true after an unhandled socket drop.
final ff1WifiTransportConnectedProvider = Provider<bool>((ref) {
  final async = ref.watch(ff1WifiTransportConnectedStreamProvider);
  return async.when(
    data: (connected) => connected,
    loading: () => ref.read(ff1WifiControlProvider).isConnected,
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

Future<void> _runRequiredDeviceVersionCheck({
  required Ref ref,
  required Logger logger,
  required FF1Device device,
  FF1DeviceStatus? deviceStatus,
}) async {
  final deviceVersion = deviceStatus?.latestVersion;
  if (deviceVersion == null || deviceVersion.isEmpty) {
    logger.warning(
      'Skipping device version compatibility check: '
      'device version not available in device status',
    );
    return;
  }

  await ref
      .read(versionServiceProvider)
      .checkDeviceVersionCompatibility(
        branchName: device.branchName,
        deviceVersion: deviceVersion,
        requiredDeviceUpdate: true,
      );
}

Future<bool> _scheduleRequiredDeviceVersionCheck({
  required Ref ref,
  required Logger logger,
  required FF1Device device,
}) async {
  final control = ref.read(ff1WifiControlProvider);
  // This runs in an unawaited background task, so do not impose an arbitrary
  // timeout. We want the required-update gate to wait until this connection
  // session publishes a usable device version, and FF1WifiControl resolves
  // the future with null automatically on teardown / device switch.
  final deviceStatus = await control.freshDeviceVersionFuture();
  if (!ref.mounted) {
    return false;
  }
  if (deviceStatus == null) {
    logger.warning(
      'Skipping device version compatibility check: '
      'fresh device status unavailable for this session',
    );
    return false;
  }
  final activeDevice = ref
      .read(activeFF1BluetoothDeviceProvider)
      .when(
        data: (value) => value,
        loading: () => null,
        error: (_, _) => null,
      );
  if (activeDevice?.deviceId != device.deviceId) {
    logger.info(
      'Skipping device version compatibility check for '
      '${device.deviceId}: active device changed before status arrived',
    );
    return false;
  }
  try {
    await _runRequiredDeviceVersionCheck(
      ref: ref,
      logger: logger,
      device: device,
      deviceStatus: deviceStatus,
    );
    return true;
  } on Object catch (error, stack) {
    logger.severe(
      'Failed required device version compatibility check for '
      '${device.deviceId}',
      error,
      stack,
    );
    return false;
  }
}

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
  final connectionNotifier = ref.read(ff1WifiConnectionProvider.notifier);

  ref.listen<AsyncValue<FF1Device?>>(
    activeFF1BluetoothDeviceProvider,
    (previous, next) {
      final previousDevice = previous?.maybeWhen(
        data: (device) => device,
        orElse: () => null,
      );
      final device = next.maybeWhen(
        data: (device) => device,
        orElse: () => null,
      );
      if (previousDevice == null && device == null) {
        return;
      }
      final switchingDevice =
          previousDevice != null &&
          device != null &&
          previousDevice.deviceId != device.deviceId;

      if (device != null) {
        // Clear stale relayer/device state synchronously so UI consumers see
        // the handoff before the deferred connection attempt begins.
        ref.read(ff1WifiControlProvider).prepareForDeviceSwitch(device);
      }

      // Use Future.microtask to defer transport mutations out of the build
      // phase and preserve the existing provider-driven connect flow.
      unawaited(
        Future.microtask(() async {
          if (switchingDevice) {
            logger.info(
              'Active device switched from ${previousDevice.deviceId} to '
              '${device.deviceId}, disconnecting old device first...',
            );
            try {
              await connectionNotifier.disconnect();
            } on Exception catch (error, stackTrace) {
              logger.warning(
                'Disconnect failed during active-device switch; '
                'continuing with connect attempt.',
                error,
                stackTrace,
              );
            }
          }

          if (device != null) {
            logger.info(
              'Active device changed: ${device.toJson()}, connecting...',
            );
            await connectionNotifier.connect(
              device: device,
              userId: 'user_id',
              apiKey: AppConfig.ff1RelayerApiKey,
            );
          } else {
            logger.info('No active device, disconnecting...');
            await connectionNotifier.disconnect();
          }
        }),
      );
    },
    fireImmediately: true,
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
/// Uses Riverpod's automatic retry mechanism (5 attempts with exponential
/// backoff).
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
// ignore: specify_nonobvious_property_types
final ff1WifiConnectOperationProvider = FutureProvider.autoDispose
    .family<void, FF1WifiConnectParams>(
      retry: _wifiRetry,
      (ref, params) async {
        final control = ref.watch(ff1WifiControlProvider);

        final ok = await control.connect(
          device: params.device,
          userId: params.userId,
          apiKey: params.apiKey,
        );
        // Suppressed/no-dispatch (e.g. lifecycle pause) is a controlled no-op,
        // not a hard failure — avoid retry storms that would churn transport.
        if (!ok) {
          return;
        }
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
// ignore: specify_nonobvious_property_types
final ff1WifiSendCommandProvider = FutureProvider.autoDispose
    .family<dynamic, FF1WifiCommandParams<dynamic>>(
      retry: _wifiRetry,
      (ref, params) async {
        final control = ref.watch(ff1WifiControlProvider);

        return params.commandFn(control, params.topicId);
      },
    );

// ============================================================================
// Connection discrepancy watcher
// ============================================================================

/// How long actual transport (WebSocket) can be up while device-level
/// "connected" is false before we consider it a discrepancy worth reporting.
const ff1ConnectionDiscrepancyThreshold = Duration(seconds: 10);

/// Notifier backing [ff1ConnectionDiscrepancyWatcherProvider].
///
/// Holds the timer as a field so it persists across dependency-driven rebuilds.
/// A `Provider` body re-runs on each watched dependency change, which would
/// silently drop a locally-scoped timer; a `Notifier` field survives rebuilds.
class FF1ConnectionDiscrepancyWatcher extends Notifier<void> {
  /// Shared [Logger] for structured log wiring; must be static so [_slog] can
  /// be initialized in a field initializer (instance members are not allowed
  /// there).
  static final _log = Logger('FF1ConnectionDiscrepancyWatcher');

  // Initialized once at notifier construction — not in build(), which re-runs
  // on every watched dependency change (re-assigning `late final` would throw).
  final StructuredLogger _slog = AppStructuredLog.forLogger(
    _log,
    context: {'component': 'ff1_discrepancy_watcher'},
  );
  Timer? _timer;

  @override
  void build() {
    // Transport truth from WebSocket events — not [ff1WifiConnectionProvider],
    // whose isConnected is only updated by explicit notifier calls.
    final transportConnected = ref.watch(ff1WifiTransportConnectedProvider);
    // Watch the device-level connection notification (FF1 connection message).
    final deviceConnected = ref.watch(ff1DeviceConnectedProvider);

    if (transportConnected && !deviceConnected) {
      // Arm the timer once per gap opening — field persists across rebuilds
      // so subsequent dependency-change rebuilds while the gap is still open
      // will hit the already-running timer and skip re-arming.
      _timer ??= Timer(
        ff1ConnectionDiscrepancyThreshold,
        _onDiscrepancyDetected,
      );
    } else {
      // Gap closed (transport dropped or device confirmed connected).
      _cancelTimer();
    }

    ref.onDispose(_cancelTimer);
  }

  void _cancelTimer() {
    _timer?.cancel();
    _timer = null;
  }

  void _onDiscrepancyDetected() {
    _timer = null;

    // Re-read to confirm the discrepancy still exists at fire time; the timer
    // fires asynchronously so state may have resolved by then.
    final stillTransportUp = ref.read(ff1WifiTransportConnectedProvider);
    final stillDeviceDown = !ref.read(ff1DeviceConnectedProvider);
    if (!stillTransportUp || !stillDeviceDown) {
      return;
    }

    _slog.warning(
      category: LogCategory.wifi,
      event: 'connection_discrepancy',
      message:
          'transport connected but device-level not connected for '
          '>${ff1ConnectionDiscrepancyThreshold.inSeconds}s - possible '
          'false "Device not connected" in UI',
      payload: {
        'thresholdSeconds': ff1ConnectionDiscrepancyThreshold.inSeconds,
      },
    );
    unawaited(
      Sentry.captureEvent(
        SentryEvent(
          message: SentryMessage(
            'FF1 connection discrepancy: transport up but device-level '
            'not connected for >'
            '${ff1ConnectionDiscrepancyThreshold.inSeconds}s',
          ),
          level: SentryLevel.warning,
          tags: {'component': 'ff1_wifi'},
        ),
      ),
    );
  }
}

/// Connection discrepancy watcher provider.
///
/// Watches [ff1WifiTransportConnectedProvider] (live WebSocket state) and
/// [ff1DeviceConnectedProvider] (device connection notifications). When the
/// transport is up but the device has not confirmed "connected" within
/// [ff1ConnectionDiscrepancyThreshold], captures a Sentry
/// event so we can track the frequency and circumstances of the false
/// "Device not connected" UI state in production.
///
/// Keep this provider alive at the root level alongside
/// [ff1AutoConnectWatcherProvider].
final ff1ConnectionDiscrepancyWatcherProvider =
    NotifierProvider<FF1ConnectionDiscrepancyWatcher, void>(
      FF1ConnectionDiscrepancyWatcher.new,
    );
