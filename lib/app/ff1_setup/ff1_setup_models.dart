// ignore_for_file: public_member_api_docs // Internal setup flow models.

import 'package:app/app/ff1_setup/ff1_setup_effect.dart';
import 'package:app/app/providers/connect_ff1_providers.dart';
import 'package:app/app/providers/connect_wifi_provider.dart';
import 'package:app/domain/models/ff1_device_info.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

/// Durable FF1 setup session (onboarding, BLE, Wi‑Fi) until success or cancel.
class FF1SetupSession {
  /// Constructor.
  const FF1SetupSession({
    required this.id,
    required this.startedAt,
  });

  /// Opaque session identifier (e.g. UUID).
  final String id;

  /// When the session was started.
  final DateTime startedAt;
}

/// Why the guided setup session was cancelled from the orchestrator.
enum FF1SetupSessionCancelReason {
  /// User left the setup flow without finishing (e.g. Cancel / back).
  userAborted,
}

enum FF1SetupStep {
  idle,
  connecting,
  stillConnecting,
  bluetoothOff,
  needsWiFi,
  wiFiConnecting,
  wiFiScanningNetworks,
  wiFiSelectingNetwork,
  wiFiSendingCredentials,
  wiFiWaitingForDevice,
  wiFiFinalizing,
  readyForConfig,
  error,
  cancelled,
}

class FF1SetupState {
  const FF1SetupState({
    required this.step,
    this.effectId = 0,
    this.effect,
    this.connected,
    this.connectError,
    this.wifiState,
    this.selectedDevice,
    this.deeplinkInfo,
    this.activeSession,
  });

  final FF1SetupStep step;

  /// Monotonic identifier for one-off orchestration effects.
  ///
  /// Consumers should handle [effect] only when [effectId] changes.
  final int effectId;
  final FF1SetupEffect? effect;

  /// Terminal connect state (Flow 1–3 output), when available.
  final ConnectFF1Connected? connected;

  /// Connect error (BLE / flow errors), when available.
  final Exception? connectError;

  /// Wi‑Fi setup sub-flow state (Flow Wi‑Fi), when applicable.
  final WiFiConnectionState? wifiState;

  /// Input context (kept for observability/debugging).
  final BluetoothDevice? selectedDevice;
  final FF1DeviceInfo? deeplinkInfo;

  /// Active guided setup session, if any (started from onboarding / start setup).
  final FF1SetupSession? activeSession;

  /// Copy; for [effect] / [activeSession], set [hasEffect] or
  /// [hasActiveSession] to apply the argument (use `null` to clear).
  FF1SetupState copyWith({
    FF1SetupStep? step,
    int? effectId,
    FF1SetupEffect? effect,
    bool hasEffect = false,
    ConnectFF1Connected? connected,
    Exception? connectError,
    WiFiConnectionState? wifiState,
    BluetoothDevice? selectedDevice,
    FF1DeviceInfo? deeplinkInfo,
    FF1SetupSession? activeSession,
    bool hasActiveSession = false,
  }) {
    return FF1SetupState(
      step: step ?? this.step,
      effectId: effectId ?? this.effectId,
      effect: hasEffect ? effect : this.effect,
      connected: connected ?? this.connected,
      connectError: connectError ?? this.connectError,
      wifiState: wifiState ?? this.wifiState,
      selectedDevice: selectedDevice ?? this.selectedDevice,
      deeplinkInfo: deeplinkInfo ?? this.deeplinkInfo,
      activeSession: hasActiveSession ? activeSession : this.activeSession,
    );
  }
}
