import 'package:app/app/ff1_setup/ff1_setup_effect.dart';
import 'package:app/app/providers/connect_ff1_providers.dart';
import 'package:app/app/providers/connect_wifi_provider.dart';
import 'package:app/app/providers/ff1_setup_orchestrator_provider.dart';
import 'package:app/app/providers/ff1_wifi_providers.dart';
import 'package:app/domain/models/ff1_device.dart';
import 'package:app/domain/models/ff1_device_info.dart';
import 'package:app/infra/ff1/wifi_protocol/ff1_wifi_messages.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'provider_test_helpers.dart';

void main() {
  test('derives needsWiFi step when connect is offline', () async {
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
        connectFF1Provider.overrideWith(
          () => _ScriptedConnectNotifier(connected: connected),
        ),
      ],
    );
    addTearDown(container.dispose);

    final keepAlive = container.listen(
      ff1SetupOrchestratorProvider,
      (_, _) {},
    );
    addTearDown(keepAlive.close);
    final blDevice = BluetoothDevice.fromId('00:11:22:33:44:55');
    await container
        .read(ff1SetupOrchestratorProvider.notifier)
        .startConnect(device: blDevice);

    final setupState = container.read(ff1SetupOrchestratorProvider);
    expect(setupState.step, FF1SetupStep.needsWiFi);
    expect(
      setupState.connected?.ff1device.deviceId,
      'FF1-1',
    );
  });

  test('derives readyForConfig step when online', () async {
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

    final container = ProviderContainer.test(
      overrides: [
        connectFF1Provider.overrideWith(
          () => _ScriptedConnectNotifier(connected: connected),
        ),
      ],
    );
    addTearDown(container.dispose);

    final keepAlive = container.listen(
      ff1SetupOrchestratorProvider,
      (_, _) {},
    );
    addTearDown(keepAlive.close);
    final blDevice = BluetoothDevice.fromId('00:11:22:33:44:55');
    await container
        .read(ff1SetupOrchestratorProvider.notifier)
        .startConnect(device: blDevice);

    final setupState = container.read(ff1SetupOrchestratorProvider);
    expect(setupState.step, FF1SetupStep.readyForConfig);
    expect(setupState.connected, isNotNull);
  });

  test('emits Navigate(DeviceConfig) when WiFi reaches success (not on topicId '
      'alone)', () async {
    final container = ProviderContainer.test(
      overrides: [
        connectFF1Provider.overrideWith(
          () => _FakeConnectNotifier(ConnectFF1Initial()),
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

    (container.read(connectWiFiProvider.notifier) as _FakeWiFiNotifier)
        .emitSuccess(topicId: 'topic-1');
    expect(
      container.read(connectWiFiProvider).status,
      WiFiConnectionStatus.success,
    );
    await Future<void>.delayed(const Duration(milliseconds: 20));

    final setupState = container.read(ff1SetupOrchestratorProvider);
    expect(setupState.effect, isA<FF1SetupNavigate>());
    final nav = setupState.effect! as FF1SetupNavigate;
    expect(nav.route, isNotEmpty);
    expect(nav.method, FF1SetupNavigationMethod.go);
  });

  test(
    'does not emit connect navigation effect on fireImmediately when '
    'ConnectFF1Connected is stale and no connect attempt is active',
    () async {
    final container = ProviderContainer.test(
      overrides: [
        connectFF1Provider.overrideWith(
          _StaleConnectedConnectNotifier.new,
        ),
      ],
    );
      addTearDown(container.dispose);

      final keepAlive = container.listen(
        ff1SetupOrchestratorProvider,
        (_, _) {},
      );
      addTearDown(keepAlive.close);

      await Future<void>.delayed(const Duration(milliseconds: 20));

      final setupState = container.read(ff1SetupOrchestratorProvider);
      expect(setupState.connected, isNotNull);
      expect(setupState.connected?.ff1device.deviceId, 'FF1-stale');
      expect(setupState.effect, isNull);
    },
  );
}

/// Notifier whose resolved state is already [ConnectFF1Connected] before any
/// transition — exercises `fireImmediately` + stale guard.
class _StaleConnectedConnectNotifier extends ConnectFF1Notifier {
  @override
  Future<ConnectFF1State> build() async {
    return const ConnectFF1Connected(
      ff1device: FF1Device(
        name: 'FF1',
        remoteId: '00:11',
        deviceId: 'FF1-stale',
        topicId: '',
      ),
      portalIsSet: false,
      isConnectedToInternet: false,
    );
  }
}

class _FakeConnectNotifier extends ConnectFF1Notifier {
  _FakeConnectNotifier(this._state);

  final ConnectFF1State _state;

  @override
  Future<ConnectFF1State> build() async => _state;

  void emit(ConnectFF1State state) {
    this.state = AsyncValue.data(state);
  }
}

class _ScriptedConnectNotifier extends ConnectFF1Notifier {
  _ScriptedConnectNotifier({required this.connected});

  final ConnectFF1Connected connected;

  @override
  Future<ConnectFF1State> build() async => ConnectFF1Initial();

  @override
  Future<void> connectBle(
    BluetoothDevice bluetoothDevice, {
    FF1DeviceInfo? ff1DeviceInfo,
  }) async {
    state = AsyncValue.data(ConnectFF1Connecting(blDevice: bluetoothDevice));
    // Ensure a real transition (Connecting → Connected) is observable by the
    // orchestrator's listeners.
    await Future<void>.delayed(const Duration(milliseconds: 1));
    state = AsyncValue.data(connected);
  }
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
