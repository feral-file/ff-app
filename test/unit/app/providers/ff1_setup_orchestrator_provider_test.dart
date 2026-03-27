import 'package:app/app/providers/connect_ff1_providers.dart';
import 'package:app/app/providers/connect_wifi_provider.dart';
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
    final appState = _MockAppStateService();
    final container = ProviderContainer.test(
      overrides: [
        connectWiFiProvider.overrideWith(
          () => _FakeWiFiNotifier(const WiFiConnectionState()),
        ),
        ff1WifiControlProvider.overrideWithValue(_StubWifiControl()),
        onboardingActionsProvider.overrideWith(
          (ref) => OnboardingService(ref: ref, appStateService: appState),
        ),
      ],
    );
    addTearDown(container.dispose);

    // Keep orchestrator mounted; Wi‑Fi success triggers async onboarding work
    // that must finish before [container.dispose] in tearDown.
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
        )
        as Future<void>;
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
