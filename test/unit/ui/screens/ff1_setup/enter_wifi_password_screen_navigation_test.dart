import 'dart:async';

import 'package:app/app/ff1_setup/ff1_setup_effect.dart';
import 'package:app/app/providers/connect_ff1_providers.dart';
import 'package:app/app/providers/connect_wifi_provider.dart';
import 'package:app/app/providers/ff1_providers.dart';
import 'package:app/app/providers/ff1_setup_orchestrator_provider.dart';
import 'package:app/app/providers/ff1_wifi_providers.dart';
import 'package:app/app/providers/onboarding_provider.dart';
import 'package:app/app/routing/routes.dart';
import 'package:app/domain/models/ff1_device.dart';
import 'package:app/domain/models/wifi_point.dart';
import 'package:app/infra/config/app_state_service.dart';
import 'package:app/infra/ff1/ble_protocol/ff1_ble_commands.dart';
import 'package:app/infra/ff1/ble_protocol/ff1_ble_protocol.dart';
import 'package:app/infra/ff1/ble_transport/ff1_ble_transport.dart';
import 'package:app/infra/ff1/wifi_protocol/ff1_wifi_messages.dart';
import 'package:app/ui/screens/send_wifi_credentials_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mockito/mockito.dart';

import '../../../app/providers/provider_test_helpers.dart';

void main() {
  testWidgets('orchestrator emits navigate on WiFi success (widget env)', (
    tester,
  ) async {
    final appState = _MockAppStateService();
    final container = ProviderContainer(
      overrides: [
        connectFF1Provider.overrideWith(
          () => _FakeConnectNotifier(ConnectFF1Initial()),
        ),
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

    final effects = <FF1SetupEffect>[];
    final sub = container.listen(
      ff1SetupOrchestratorProvider,
      (previous, next) {
        if (previous?.effectId != next.effectId && next.effect != null) {
          effects.add(next.effect!);
        }
      },
      fireImmediately: true,
    );
    addTearDown(sub.close);

    (container.read(connectWiFiProvider.notifier) as _FakeWiFiNotifier)
        .emitSuccess(topicId: 'topic-1');

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(effects.whereType<FF1SetupNavigate>(), isNotEmpty);
  });

  testWidgets('navigates to device config when navigate effect arrives', (
    tester,
  ) async {
    final container = ProviderContainer(
      overrides: [
        ff1ControlProvider.overrideWithValue(
          FF1BleControl(transport: _NoopBleTransport()),
        ),
        onboardingActionsProvider.overrideWith(
          (ref) => OnboardingService(
            ref: ref,
            appStateService: _MockAppStateService(),
          ),
        ),
        ff1SetupOrchestratorProvider.overrideWith(
          _ScriptedOrchestratorNotifier.new,
        ),
      ],
    );
    addTearDown(container.dispose);

    final router = GoRouter(
      initialLocation: Routes.enterWifiPassword,
      routes: [
        GoRoute(
          path: Routes.enterWifiPassword,
          builder: (context, state) {
            final payload = EnterWifiPasswordPagePayload(
              device: const FF1Device(
                name: 'FF1',
                remoteId: '00:11',
                deviceId: 'FF1-1',
                topicId: '',
              ),
              wifiAccessPoint: const WifiPoint('Office'),
            );
            return EnterWiFiPasswordScreen(payload: payload);
          },
        ),
        GoRoute(
          path: Routes.deviceConfiguration,
          builder: (context, state) => const Scaffold(
            body: Text('DEVICE_CONFIGURATION_MARKER'),
          ),
        ),
      ],
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(EnterWiFiPasswordScreen), findsOneWidget);

    (container.read(ff1SetupOrchestratorProvider.notifier)
            as _ScriptedOrchestratorNotifier)
        .emitNavigate();

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    for (var i = 0; i < 200; i++) {
      if (find
          .text('DEVICE_CONFIGURATION_MARKER', skipOffstage: false)
          .evaluate()
          .isNotEmpty) {
        break;
      }
      await tester.pump(const Duration(milliseconds: 50));
    }

    expect(
      find.text('DEVICE_CONFIGURATION_MARKER', skipOffstage: false),
      findsOneWidget,
    );
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

  void emitTopicIdArrived({required String topicId}) {
    state = state.copyWith(
      status: WiFiConnectionStatus.waitingForDeviceConnection,
      topicId: topicId,
    );
  }

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

/// Minimal BLE transport for widget tests (no radio).
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

class _ScriptedOrchestratorNotifier extends FF1SetupOrchestratorNotifier {
  var _effectId = 0;
  FF1SetupEffect? _effect;

  @override
  FF1SetupState build() {
    return FF1SetupState(
      step: FF1SetupStep.idle,
      effectId: _effectId,
      effect: _effect,
    );
  }

  void emitNavigate() {
    _effectId += 1;
    _effect = const FF1SetupNavigate(
      route: Routes.deviceConfiguration,
      method: FF1SetupNavigationMethod.go,
    );
    state = state.copyWith(
      effectId: _effectId,
      hasEffect: true,
      effect: _effect,
    );
  }

  @override
  void ackEffect({required int effectId}) {
    if (effectId != _effectId) return;
    _effect = null;
    state = state.copyWith(
      effectId: _effectId,
      hasEffect: true,
    );
  }
}
