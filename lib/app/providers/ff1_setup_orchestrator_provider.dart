import 'dart:async';

import 'package:app/app/providers/connect_ff1_providers.dart';
import 'package:app/app/providers/connect_wifi_provider.dart';
import 'package:app/domain/models/ff1_device_info.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
    this.connected,
    this.connectError,
    this.wifiState,
    this.selectedDevice,
    this.deeplinkInfo,
  });

  final FF1SetupStep step;

  /// Terminal connect state (Flow 1–3 output), when available.
  final ConnectFF1Connected? connected;

  /// Connect error (BLE / flow errors), when available.
  final Exception? connectError;

  /// Wi‑Fi setup sub-flow state (Flow Wi‑Fi), when applicable.
  final WiFiConnectionState? wifiState;

  /// Input context (kept for observability/debugging).
  final BluetoothDevice? selectedDevice;
  final FF1DeviceInfo? deeplinkInfo;

  FF1SetupState copyWith({
    FF1SetupStep? step,
    ConnectFF1Connected? connected,
    Exception? connectError,
    WiFiConnectionState? wifiState,
    BluetoothDevice? selectedDevice,
    FF1DeviceInfo? deeplinkInfo,
  }) {
    return FF1SetupState(
      step: step ?? this.step,
      connected: connected ?? this.connected,
      connectError: connectError ?? this.connectError,
      wifiState: wifiState ?? this.wifiState,
      selectedDevice: selectedDevice ?? this.selectedDevice,
      deeplinkInfo: deeplinkInfo ?? this.deeplinkInfo,
    );
  }
}

/// Orchestrator provider: aggregates sub-flow providers without changing UX.
///
/// This does not re-implement flow logic; it listens to:
/// - [connectFF1Provider] (connect + info + ensure-ready outcome)
/// - [connectWiFiProvider] (Wi‑Fi provisioning)
///
/// Screens can listen to this single provider for routing decisions while
/// preserving existing UI steps and copy.
class FF1SetupOrchestratorNotifier extends Notifier<FF1SetupState> {
  BluetoothDevice? _selectedDevice;
  FF1DeviceInfo? _deeplinkInfo;

  @override
  FF1SetupState build() {
    final connectAsync = ref.watch(connectFF1Provider);
    final wifi = ref.watch(connectWiFiProvider);

    ConnectFF1Connected? connected;
    Exception? connectError;
    var step = FF1SetupStep.idle;

    connectAsync.when(
      data: (s) {
        switch (s) {
          case ConnectFF1Initial():
            step = FF1SetupStep.idle;
          case ConnectFF1Connecting():
            step = FF1SetupStep.connecting;
          case ConnectFF1StillConnecting():
            step = FF1SetupStep.stillConnecting;
          case ConnectFF1BluetoothOff():
            step = FF1SetupStep.bluetoothOff;
          case ConnectFF1Error(:final exception):
            step = FF1SetupStep.error;
            connectError = exception;
          case ConnectFF1Connected():
            connected = s;
            step = s.isConnectedToInternet
                ? FF1SetupStep.readyForConfig
                : FF1SetupStep.needsWiFi;
        }
      },
      error: (e, _) {
        step = FF1SetupStep.error;
        connectError = Exception(e.toString());
      },
      loading: () {
        step = FF1SetupStep.connecting;
      },
    );

    // When Wi‑Fi flow is active (or has emitted a non-idle state), reflect its
    // step as the single-source-of-truth for \"what happens next\".
    final hasWifiActivity =
        step == FF1SetupStep.needsWiFi || wifi.status != WiFiConnectionStatus.idle;
    if (hasWifiActivity) {
      step = switch (wifi.status) {
        WiFiConnectionStatus.idle => step,
        WiFiConnectionStatus.connecting => FF1SetupStep.wiFiConnecting,
        WiFiConnectionStatus.scanningNetworks => FF1SetupStep.wiFiScanningNetworks,
        WiFiConnectionStatus.selectingNetwork => FF1SetupStep.wiFiSelectingNetwork,
        WiFiConnectionStatus.sendingCredentials => FF1SetupStep.wiFiSendingCredentials,
        WiFiConnectionStatus.waitingForDeviceConnection =>
          FF1SetupStep.wiFiWaitingForDevice,
        WiFiConnectionStatus.finalizingConnection => FF1SetupStep.wiFiFinalizing,
        WiFiConnectionStatus.success => FF1SetupStep.readyForConfig,
        WiFiConnectionStatus.error => FF1SetupStep.error,
      };
    }

    return FF1SetupState(
      step: step,
      connected: connected,
      connectError: connectError,
      wifiState: hasWifiActivity ? wifi : null,
      selectedDevice: _selectedDevice,
      deeplinkInfo: _deeplinkInfo,
    );
  }

  Future<void> startConnect({
    required BluetoothDevice device,
    FF1DeviceInfo? deeplinkInfo,
  }) async {
    _selectedDevice = device;
    _deeplinkInfo = deeplinkInfo;
    // Refactor-only invariant: avoid stale success causing immediate navigation
    // when the connect page is opened again.
    ref.read(connectWiFiProvider.notifier).reset();
    state = FF1SetupState(
      step: FF1SetupStep.connecting,
      selectedDevice: device,
      deeplinkInfo: deeplinkInfo,
      connected: null,
      connectError: null,
      wifiState: null,
    );
    await ref
        .read(connectFF1Provider.notifier)
        .connectBle(device, ff1DeviceInfo: deeplinkInfo);
  }

  void cancel() {
    ref.read(connectFF1Provider.notifier).cancelConnection();
  }

  void reset() {
    ref.read(connectFF1Provider.notifier).reset();
    ref.read(connectWiFiProvider.notifier).reset();
    state = const FF1SetupState(step: FF1SetupStep.idle);
  }
}

final ff1SetupOrchestratorProvider =
    NotifierProvider<FF1SetupOrchestratorNotifier, FF1SetupState>(
  FF1SetupOrchestratorNotifier.new,
);

