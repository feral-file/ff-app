import 'package:app/app/providers/connect_ff1_providers.dart';
import 'package:app/app/providers/connect_wifi_provider.dart';
import 'package:app/domain/models/ff1_device_info.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'ff1_setup_models.dart';

FF1SetupState deriveFf1SetupState({
  required AsyncValue<ConnectFF1State> connectAsync,
  required WiFiConnectionState wifi,
  required BluetoothDevice? selectedDevice,
  required FF1DeviceInfo? deeplinkInfo,
}) {
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
        case ConnectFF1Cancelled():
          step = FF1SetupStep.cancelled;
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
    selectedDevice: selectedDevice,
    deeplinkInfo: deeplinkInfo,
  );
}

