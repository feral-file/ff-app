import 'package:app/app/ff1_setup/ff1_setup_effect.dart';
import 'package:app/app/providers/connect_ff1_providers.dart';
import 'package:app/app/providers/connect_wifi_provider.dart';
import 'package:app/app/providers/ff1_bluetooth_device_providers.dart';
import 'package:app/app/providers/ff1_setup_orchestrator_provider.dart';
import 'package:app/app/providers/ff1_wifi_providers.dart';
import 'package:app/app/providers/onboarding_provider.dart';
import 'package:app/domain/models/ff1_device.dart';
import 'package:app/infra/config/app_state_service.dart';
import 'package:app/infra/ff1/wifi_protocol/ff1_wifi_messages.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

import 'provider_test_helpers.dart';

void main() {
  test('emits NeedsWiFi effect when connect is offline', () async {
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

    final appState = _MockAppStateService();

    final container = ProviderContainer.test(
      overrides: [
        connectFF1Provider.overrideWith(() => _FakeConnectNotifier(ConnectFF1Initial())),
        onboardingActionsProvider.overrideWith(
          (ref) => OnboardingService(ref: ref, appStateService: appState),
        ),
      ],
    );
    addTearDown(container.dispose);

    final keepAlive = container.listen(ff1SetupOrchestratorProvider, (_, __) {});
    addTearDown(keepAlive.close);

    final connectNotifier =
        container.read(connectFF1Provider.notifier) as _FakeConnectNotifier;
    connectNotifier.emit(connected);
    await Future<void>.delayed(const Duration(milliseconds: 20));

    final setupState = container.read(ff1SetupOrchestratorProvider);
    expect(setupState.effect, isA<FF1SetupNeedsWiFi>());
    expect(
      (setupState.effect as FF1SetupNeedsWiFi).device.deviceId,
      'FF1-1',
    );
  });

  test('emits InternetReady effect and persists device when online', () async {
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

    final deviceActions = _RecordingDeviceActions();
    final appState = _MockAppStateService();
    final container = ProviderContainer.test(
      overrides: [
        connectFF1Provider.overrideWith(() => _FakeConnectNotifier(ConnectFF1Initial())),
        ff1BluetoothDeviceActionsProvider.overrideWith(() => deviceActions),
        onboardingActionsProvider.overrideWith(
          (ref) => OnboardingService(ref: ref, appStateService: appState),
        ),
      ],
    );
    addTearDown(container.dispose);

    final keepAlive = container.listen(ff1SetupOrchestratorProvider, (_, __) {});
    addTearDown(keepAlive.close);

    final connectNotifier =
        container.read(connectFF1Provider.notifier) as _FakeConnectNotifier;
    connectNotifier.emit(connected);
    expect(container.read(connectFF1Provider).value, isA<ConnectFF1Connected>());
    await Future<void>.delayed(const Duration(milliseconds: 20));

    final setupState = container.read(ff1SetupOrchestratorProvider);
    expect(setupState.effect, isA<FF1SetupInternetReady>());

    // Side effect: device persistence should be triggered.
    expect(deviceActions.addedDevices, [connected.ff1device]);
  });

  test('emits Navigate(DeviceConfig) when WiFi succeeds', () async {
    final appState = _MockAppStateService();
    final container = ProviderContainer.test(
      overrides: [
        connectFF1Provider.overrideWith(() => _FakeConnectNotifier(ConnectFF1Initial())),
        connectWiFiProvider.overrideWith(() => _FakeWiFiNotifier(const WiFiConnectionState())),
        ff1WifiControlProvider.overrideWithValue(_StubWifiControl()),
        onboardingActionsProvider.overrideWith(
          (ref) => OnboardingService(ref: ref, appStateService: appState),
        ),
      ],
    );
    addTearDown(container.dispose);

    final keepAlive = container.listen(ff1SetupOrchestratorProvider, (_, __) {});
    addTearDown(keepAlive.close);

    final wifiNotifier =
        container.read(connectWiFiProvider.notifier) as _FakeWiFiNotifier;
    wifiNotifier.emitSuccess(topicId: 'topic-1');
    expect(container.read(connectWiFiProvider).status, WiFiConnectionStatus.success);
    await Future<void>.delayed(const Duration(milliseconds: 20));

    final setupState = container.read(ff1SetupOrchestratorProvider);
    expect(setupState.effect, isA<FF1SetupNavigate>());
    final nav = setupState.effect as FF1SetupNavigate;
    expect(nav.route, isNotEmpty);
    expect(nav.method, FF1SetupNavigationMethod.push);
  });

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

class _FakeWiFiNotifier extends WiFiConnectionNotifier {
  _FakeWiFiNotifier(this._initial);

  final WiFiConnectionState _initial;

  @override
  WiFiConnectionState build() => _initial;

  void emitSuccess({required String topicId}) {
    state = state.copyWith(status: WiFiConnectionStatus.success, topicId: topicId);
  }
}

class _RecordingDeviceActions extends FF1BluetoothDeviceActionsNotifier {
  final List<FF1Device> addedDevices = <FF1Device>[];

  @override
  void build() {}

  @override
  Future<void> addDevice(FF1Device device) async {
    addedDevices.add(device);
  }
}

class _MockAppStateService extends Mock implements AppStateService {
  @override
  Future<void> setHasSeenOnboarding({required bool hasSeen}) {
    return super.noSuchMethod(
      Invocation.method(
        #setHasSeenOnboarding,
        const [],
        <Symbol, Object?>{#hasSeen: hasSeen},
      ),
      returnValue: Future<void>.value(),
      returnValueForMissingStub: Future<void>.value(),
    ) as Future<void>;
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

