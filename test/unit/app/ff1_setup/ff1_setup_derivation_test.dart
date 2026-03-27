import 'package:app/app/ff1_setup/ff1_setup_derivation.dart';
import 'package:app/app/ff1_setup/ff1_setup_models.dart';
import 'package:app/app/providers/connect_ff1_providers.dart';
import 'package:app/app/providers/connect_wifi_provider.dart';
import 'package:app/domain/models/ff1_device.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('deriveFf1SetupState', () {
    final blDevice = FF1Device(
      name: 'FF1',
      remoteId: '00:11',
      deviceId: 'FF1-1',
      topicId: '',
    ).toBluetoothDevice();

    test('maps ConnectFF1Initial to idle', () {
      final state = deriveFf1SetupState(
        connectAsync: AsyncValue.data(ConnectFF1Initial()),
        wifi: const WiFiConnectionState(),
        selectedDevice: null,
        deeplinkInfo: null,
      );

      expect(state.step, FF1SetupStep.idle);
      expect(state.connected, isNull);
      expect(state.connectError, isNull);
      expect(state.wifiState, isNull);
    });

    test('maps ConnectFF1Connecting to connecting', () {
      final state = deriveFf1SetupState(
        connectAsync: AsyncValue.data(ConnectFF1Connecting(blDevice: blDevice)),
        wifi: const WiFiConnectionState(),
        selectedDevice: null,
        deeplinkInfo: null,
      );

      expect(state.step, FF1SetupStep.connecting);
    });

    test('maps ConnectFF1StillConnecting to stillConnecting', () {
      final state = deriveFf1SetupState(
        connectAsync: AsyncValue.data(
          ConnectFF1StillConnecting(blDevice: blDevice),
        ),
        wifi: const WiFiConnectionState(),
        selectedDevice: null,
        deeplinkInfo: null,
      );

      expect(state.step, FF1SetupStep.stillConnecting);
    });

    test('maps ConnectFF1BluetoothOff to bluetoothOff', () {
      final state = deriveFf1SetupState(
        connectAsync: AsyncValue.data(ConnectFF1BluetoothOff()),
        wifi: const WiFiConnectionState(),
        selectedDevice: null,
        deeplinkInfo: null,
      );

      expect(state.step, FF1SetupStep.bluetoothOff);
    });

    test('maps ConnectFF1Cancelled to cancelled', () {
      final state = deriveFf1SetupState(
        connectAsync: AsyncValue.data(ConnectFF1Cancelled()),
        wifi: const WiFiConnectionState(),
        selectedDevice: null,
        deeplinkInfo: null,
      );

      expect(state.step, FF1SetupStep.cancelled);
    });

    test('maps ConnectFF1Error to error and exposes exception', () {
      final ex = Exception('boom');
      final state = deriveFf1SetupState(
        connectAsync: AsyncValue.data(ConnectFF1Error(exception: ex)),
        wifi: const WiFiConnectionState(),
        selectedDevice: null,
        deeplinkInfo: null,
      );

      expect(state.step, FF1SetupStep.error);
      expect(state.connectError, ex);
    });

    test('maps internet-connected success to readyForConfig', () {
      const connected = ConnectFF1Connected(
        ff1device: FF1Device(
          name: 'FF1',
          remoteId: '00:11',
          deviceId: 'FF1-1',
          topicId: 'topic-1',
        ),
        portalIsSet: false,
        isConnectedToInternet: true,
      );
      final state = deriveFf1SetupState(
        connectAsync: AsyncValue.data(connected),
        wifi: const WiFiConnectionState(),
        selectedDevice: null,
        deeplinkInfo: null,
      );

      expect(state.step, FF1SetupStep.readyForConfig);
      expect(state.connected, connected);
    });

    test('maps offline success to needsWiFi and exposes wifi state when active', () {
      const connected = ConnectFF1Connected(
        ff1device: FF1Device(
          name: 'FF1',
          remoteId: '00:11',
          deviceId: 'FF1-1',
          topicId: '',
        ),
        portalIsSet: false,
        isConnectedToInternet: false,
      );
      final wifi = const WiFiConnectionState().copyWith(
        status: WiFiConnectionStatus.scanningNetworks,
      );

      final state = deriveFf1SetupState(
        connectAsync: AsyncValue.data(connected),
        wifi: wifi,
        selectedDevice: null,
        deeplinkInfo: null,
      );

      expect(state.step, FF1SetupStep.wiFiScanningNetworks);
      expect(state.wifiState?.status, WiFiConnectionStatus.scanningNetworks);
    });

    test('wifi success overrides to readyForConfig', () {
      final wifi = const WiFiConnectionState().copyWith(
        status: WiFiConnectionStatus.success,
        topicId: 'topic-1',
      );
      final state = deriveFf1SetupState(
        connectAsync: AsyncValue.data(ConnectFF1Initial()),
        wifi: wifi,
        selectedDevice: null,
        deeplinkInfo: null,
      );

      expect(state.step, FF1SetupStep.readyForConfig);
      expect(state.wifiState?.status, WiFiConnectionStatus.success);
    });

    test('wifi status maps to corresponding wifi step while active', () {
      for (final (status, expectedStep) in <(WiFiConnectionStatus, FF1SetupStep)>[
        (WiFiConnectionStatus.connecting, FF1SetupStep.wiFiConnecting),
        (WiFiConnectionStatus.scanningNetworks, FF1SetupStep.wiFiScanningNetworks),
        (WiFiConnectionStatus.selectingNetwork, FF1SetupStep.wiFiSelectingNetwork),
        (WiFiConnectionStatus.sendingCredentials, FF1SetupStep.wiFiSendingCredentials),
        (
          WiFiConnectionStatus.waitingForDeviceConnection,
          FF1SetupStep.wiFiWaitingForDevice,
        ),
        (WiFiConnectionStatus.finalizingConnection, FF1SetupStep.wiFiFinalizing),
      ]) {
        final wifi = const WiFiConnectionState().copyWith(status: status);
        final state = deriveFf1SetupState(
          connectAsync: AsyncValue.data(ConnectFF1Initial()),
          wifi: wifi,
          selectedDevice: null,
          deeplinkInfo: null,
        );

        expect(state.step, expectedStep, reason: 'status=$status');
        expect(state.wifiState?.status, status, reason: 'status=$status');
      }
    });

    test('wifi error overrides to error while active', () {
      final wifi = const WiFiConnectionState().copyWith(
        status: WiFiConnectionStatus.error,
        error: Exception('wifi'),
      );
      final state = deriveFf1SetupState(
        connectAsync: AsyncValue.data(ConnectFF1Initial()),
        wifi: wifi,
        selectedDevice: null,
        deeplinkInfo: null,
      );

      expect(state.step, FF1SetupStep.error);
      expect(state.wifiState?.status, WiFiConnectionStatus.error);
    });

    test('wifi state is null when not active', () {
      final state = deriveFf1SetupState(
        connectAsync: AsyncValue.data(ConnectFF1Initial()),
        wifi: const WiFiConnectionState(),
        selectedDevice: null,
        deeplinkInfo: null,
      );

      expect(state.wifiState, isNull);
      expect(state.step, FF1SetupStep.idle);
    });

    test('connect provider loading maps to connecting', () {
      final state = deriveFf1SetupState(
        connectAsync: const AsyncValue.loading(),
        wifi: const WiFiConnectionState(),
        selectedDevice: null,
        deeplinkInfo: null,
      );

      expect(state.step, FF1SetupStep.connecting);
    });

    test('connect provider error maps to error and wraps exception', () {
      final state = deriveFf1SetupState(
        connectAsync: AsyncValue.error('boom', StackTrace.empty),
        wifi: const WiFiConnectionState(),
        selectedDevice: null,
        deeplinkInfo: null,
      );

      expect(state.step, FF1SetupStep.error);
      expect(state.connectError, isA<Exception>());
    });
  });
}

