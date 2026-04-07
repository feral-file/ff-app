import 'dart:async';

import 'package:app/app/providers/connect_ff1_providers.dart';
import 'package:app/app/providers/connect_wifi_provider.dart';
import 'package:app/app/providers/ff1_providers.dart';
import 'package:app/app/providers/ff1_setup_orchestrator_provider.dart';
import 'package:app/app/providers/ff1_wifi_providers.dart';
import 'package:app/domain/models/ff1_device.dart';
import 'package:app/infra/ff1/ble_protocol/ff1_ble_commands.dart';
import 'package:app/infra/ff1/ble_protocol/ff1_ble_protocol.dart';
import 'package:app/infra/ff1/ble_transport/ff1_ble_transport.dart';
import 'package:app/infra/ff1/wifi_protocol/ff1_wifi_messages.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'provider_test_helpers.dart';

void main() {
  test('orchestrator maps connect success to needsWiFi step', () async {
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

    final container = ProviderContainer.test(
      overrides: [
        connectFF1Provider.overrideWith(() => _FakeConnectNotifier(connected)),
      ],
    );
    addTearDown(container.dispose);

    await container.read(connectFF1Provider.future);

    final state = container.read(ff1SetupOrchestratorProvider);
    expect(state.step, FF1SetupStep.needsWiFi);
    expect(state.connected, connected);
  });

  test('orchestrator maps WiFi success to readyForConfig', () async {
    final container = ProviderContainer.test(
      overrides: [
        connectWiFiProvider.overrideWith(
          () => _FakeWiFiNotifier(const WiFiConnectionState()),
        ),
        ff1WifiControlProvider.overrideWithValue(_StubWifiControl()),
      ],
    );
    addTearDown(container.dispose);

    // Keep orchestrator mounted so Wi‑Fi listener runs.
    final keepAlive = container.listen(
      ff1SetupOrchestratorProvider,
      (_, _) {},
    );
    addTearDown(keepAlive.close);

    (container.read(connectWiFiProvider.notifier) as _FakeWiFiNotifier)
        .emitSuccess(topicId: 'topic-1');

    await Future<void>.delayed(const Duration(milliseconds: 20));

    final state = container.read(ff1SetupOrchestratorProvider);
    expect(state.step, FF1SetupStep.readyForConfig);
    expect(state.wifiState?.status, WiFiConnectionStatus.success);
  });

  test('tearDownAfterSetupComplete resets setup state', () async {
    final container = ProviderContainer.test(
      overrides: [
        ff1ControlProvider.overrideWithValue(
          FF1BleControl(transport: _NoopBleTransport()),
        ),
        connectFF1Provider.overrideWith(
          () => _FakeConnectNotifier(
            const ConnectFF1Connected(
              ff1device: FF1Device(
                name: 'FF1',
                remoteId: 'AA:BB:CC:DD:EE:FF',
                deviceId: 'FF1-1',
                topicId: 't1',
              ),
              portalIsSet: false,
              isConnectedToInternet: true,
            ),
          ),
        ),
        connectWiFiProvider.overrideWith(
          () => _FakeWiFiNotifier(const WiFiConnectionState()),
        ),
        ff1WifiControlProvider.overrideWithValue(_StubWifiControl()),
      ],
    );
    addTearDown(container.dispose);

    final keepAlive = container.listen(
      ff1SetupOrchestratorProvider,
      (_, _) {},
    );
    addTearDown(keepAlive.close);

    await container.read(connectFF1Provider.future);

    await container
        .read(ff1SetupOrchestratorProvider.notifier)
        .tearDownAfterSetupComplete();

    expect(
      container.read(ff1SetupOrchestratorProvider).step,
      FF1SetupStep.idle,
    );
    final connectAsync = container.read(connectFF1Provider);
    expect(connectAsync.asData?.value, isA<ConnectFF1Initial>());
  });
}

class _FakeConnectNotifier extends ConnectFF1Notifier {
  _FakeConnectNotifier(this._state);

  final ConnectFF1State _state;

  @override
  Future<ConnectFF1State> build() async => _state;
}

class _FakeWiFiNotifier extends WiFiConnectionNotifier {
  _FakeWiFiNotifier(this._initial);

  final WiFiConnectionState _initial;

  @override
  WiFiConnectionState build() => _initial;

  void emitSuccess({required String topicId}) {
    state = state.copyWith(
      status: WiFiConnectionStatus.success,
      topicId: topicId,
    );
  }
}

class _StubWifiControl extends FakeWifiControl {
  @override
  Future<FF1CommandResponse> showPairingQRCode({
    required String topicId,
    required bool show,
  }) async {
    return FF1CommandResponse(status: 'ok');
  }
}

/// Minimal BLE transport for unit tests (no radio).
class _NoopBleTransport implements FF1BleTransport {
  @override
  BluetoothAdapterState get adapterState => BluetoothAdapterState.on;

  @override
  Stream<BluetoothAdapterState> get adapterStateStream =>
      const Stream<BluetoothAdapterState>.empty();

  @override
  Future<void> connect({
    required BluetoothDevice blDevice,
    Duration timeout = const Duration(seconds: 30),
    int maxRetries = 0,
    bool Function()? shouldContinue,
  }) async {}

  @override
  Future<void> disconnect(BluetoothDevice device) async {}

  @override
  Future<bool> get isSupported async => true;

  @override
  Future<void> scan({
    required FutureOr<bool> Function(List<BluetoothDevice> devices) onDevice,
    Duration timeout = const Duration(seconds: 30),
  }) async {}

  @override
  Future<BluetoothDevice?> scanForName({
    required String name,
    Duration timeout = const Duration(seconds: 15),
  }) async {
    return null;
  }

  @override
  Future<FF1BleResponse> sendCommand({
    required BluetoothDevice blDevice,
    required FF1BleCommand command,
    required FF1BleRequest request,
    Duration timeout = const Duration(seconds: 10),
  }) async {
    return const FF1BleResponse(topic: 'noop', errorCode: 0, data: <String>[]);
  }

  @override
  Future<void> waitUntilReady({
    required BluetoothDevice blDevice,
    Duration timeout = const Duration(seconds: 20),
  }) async {}
}
