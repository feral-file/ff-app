import 'dart:async';

import 'package:app/app/ff1_setup/ff1_setup_effect.dart';
import 'package:app/app/providers/connect_ff1_providers.dart';
import 'package:app/app/providers/connect_wifi_provider.dart';
import 'package:app/app/providers/ff1_bluetooth_device_providers.dart';
import 'package:app/app/providers/ff1_providers.dart';
import 'package:app/app/providers/ff1_setup_orchestrator_provider.dart';
import 'package:app/app/providers/ff1_wifi_providers.dart';
import 'package:app/app/providers/onboarding_provider.dart';
import 'package:app/domain/models/ff1_device.dart';
import 'package:app/infra/ff1/ble_protocol/ff1_ble_commands.dart';
import 'package:app/infra/ff1/ble_protocol/ff1_ble_protocol.dart';
import 'package:app/infra/ff1/ble_transport/ff1_ble_transport.dart';
import 'package:app/infra/ff1/wifi_protocol/ff1_wifi_messages.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'provider_test_helpers.dart';

class _NoopFf1BtActions extends FF1BluetoothDeviceActionsNotifier {
  @override
  void build() {}

  @override
  Future<void> addDevice(FF1Device device) async {}
}

class _BlockingFf1BtActions extends FF1BluetoothDeviceActionsNotifier {
  _BlockingFf1BtActions(this._completer);

  final Completer<void> _completer;
  int addDeviceCalls = 0;

  @override
  void build() {}

  @override
  Future<void> addDevice(FF1Device device) async {
    addDeviceCalls += 1;
    await _completer.future;
  }
}

class _ThrowingBtActions extends FF1BluetoothDeviceActionsNotifier {
  @override
  void build() {}

  @override
  Future<void> addDevice(FF1Device device) async {
    throw StateError('persist failed');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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

  test(
    'completeSession and cancelSession ignore missing active session',
    () async {
      final container = ProviderContainer.test(
        overrides: [
          ff1ControlProvider.overrideWithValue(
            FF1BleControl(transport: _NoopBleTransport()),
          ),
          connectWiFiProvider.overrideWith(
            () => _FakeWiFiNotifier(const WiFiConnectionState()),
          ),
        ],
      );
      addTearDown(container.dispose);

      final keepAlive = container.listen(
        ff1SetupOrchestratorProvider,
        (_, _) {},
      );
      addTearDown(keepAlive.close);

      await container
          .read(ff1SetupOrchestratorProvider.notifier)
          .completeSession(
            const FF1Device(
              name: 'FF1',
              remoteId: '00:11',
              deviceId: 'FF1-1',
              topicId: 'topic-1',
            ),
          );
      await container
          .read(ff1SetupOrchestratorProvider.notifier)
          .cancelSession(FF1SetupSessionCancelReason.userAborted);

      expect(
        container.read(ff1SetupOrchestratorProvider).activeSession,
        isNull,
      );
      expect(
        container.read(ff1SetupOrchestratorProvider).step,
        FF1SetupStep.idle,
      );
    },
  );

  test(
    'completeSession keeps active session until async completion succeeds',
    () async {
      final addDeviceCompleter = Completer<void>();
      final blockingBtActions = _BlockingFf1BtActions(addDeviceCompleter);
      final container = ProviderContainer.test(
        overrides: [
          ff1ControlProvider.overrideWithValue(
            FF1BleControl(transport: _NoopBleTransport()),
          ),
          connectWiFiProvider.overrideWith(
            () => _FakeWiFiNotifier(const WiFiConnectionState()),
          ),
          ff1BluetoothDeviceActionsProvider.overrideWith(
            () => blockingBtActions,
          ),
          onboardingActionsProvider.overrideWith(
            (ref) => OnboardingService(
              ref: ref,
              appStateService: MockAppStateService(),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      final keepAlive = container.listen(
        ff1SetupOrchestratorProvider,
        (_, _) {},
      );
      addTearDown(keepAlive.close);

      container.read(ff1SetupOrchestratorProvider.notifier).startSession();
      final completeFuture = container
          .read(ff1SetupOrchestratorProvider.notifier)
          .completeSession(
            const FF1Device(
              name: 'FF1',
              remoteId: '00:11',
              deviceId: 'FF1-1',
              topicId: 'topic-1',
            ),
          );

      await Future<void>.delayed(Duration.zero);

      expect(
        container.read(ff1SetupOrchestratorProvider).activeSession,
        isNotNull,
      );

      await container
          .read(ff1SetupOrchestratorProvider.notifier)
          .cancelSession(FF1SetupSessionCancelReason.userAborted);

      expect(
        container.read(ff1SetupOrchestratorProvider).activeSession,
        isNotNull,
      );

      addDeviceCompleter.complete();
      await completeFuture;

      expect(blockingBtActions.addDeviceCalls, 1);
      expect(
        container.read(ff1SetupOrchestratorProvider).activeSession,
        isNull,
      );
    },
  );

  test(
    'completeSession failure keeps active session recoverable',
    () async {
      final container = ProviderContainer.test(
        overrides: [
          ff1ControlProvider.overrideWithValue(
            FF1BleControl(transport: _NoopBleTransport()),
          ),
          connectWiFiProvider.overrideWith(
            () => _FakeWiFiNotifier(const WiFiConnectionState()),
          ),
          ff1BluetoothDeviceActionsProvider.overrideWith(
            _ThrowingBtActions.new,
          ),
          onboardingActionsProvider.overrideWith(
            (ref) => OnboardingService(
              ref: ref,
              appStateService: MockAppStateService(),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      final keepAlive = container.listen(
        ff1SetupOrchestratorProvider,
        (_, _) {},
      );
      addTearDown(keepAlive.close);

      container.read(ff1SetupOrchestratorProvider.notifier).startSession();

      await expectLater(
        container.read(ff1SetupOrchestratorProvider.notifier).completeSession(
          const FF1Device(
            name: 'FF1',
            remoteId: '00:11',
            deviceId: 'FF1-1',
            topicId: 'topic-1',
          ),
        ),
        throwsA(isA<StateError>()),
      );

      expect(
        container.read(ff1SetupOrchestratorProvider).activeSession,
        isNotNull,
      );
    },
  );

  test('cancelSession clears published activeSession', () async {
    final container = ProviderContainer.test(
      overrides: [
        ff1ControlProvider.overrideWithValue(
          FF1BleControl(transport: _NoopBleTransport()),
        ),
        connectWiFiProvider.overrideWith(
          () => _FakeWiFiNotifier(const WiFiConnectionState()),
        ),
      ],
    );
    addTearDown(container.dispose);

    final keepAlive = container.listen(
      ff1SetupOrchestratorProvider,
      (_, _) {},
    );
    addTearDown(keepAlive.close);

    final notifier = container.read(ff1SetupOrchestratorProvider.notifier)
      ..startSession();
    expect(
      container.read(ff1SetupOrchestratorProvider).activeSession,
      isNotNull,
    );
    expect(notifier.hasGuidedSetupSession, isTrue);

    await notifier.cancelSession(FF1SetupSessionCancelReason.userAborted);

    expect(
      container.read(ff1SetupOrchestratorProvider).activeSession,
      isNull,
    );
    expect(notifier.hasGuidedSetupSession, isFalse);
  });

  test(
    'Wi‑Fi success with active session completes session using connect device',
    () async {
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
            () => _FakeConnectNotifier(connected),
          ),
          connectWiFiProvider.overrideWith(
            () => _FakeWiFiNotifier(const WiFiConnectionState()),
          ),
          ff1WifiControlProvider.overrideWithValue(_StubWifiControl()),
          ff1ControlProvider.overrideWithValue(
            FF1BleControl(transport: _NoopBleTransport()),
          ),
          ff1BluetoothDeviceActionsProvider.overrideWith(
            _NoopFf1BtActions.new,
          ),
          onboardingActionsProvider.overrideWith(
            (ref) => OnboardingService(
              ref: ref,
              appStateService: MockAppStateService(),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      final keepAlive = container.listen(
        ff1SetupOrchestratorProvider,
        (_, _) {},
      );
      addTearDown(keepAlive.close);

      container.read(ff1SetupOrchestratorProvider.notifier).startSession();
      expect(
        container.read(ff1SetupOrchestratorProvider).activeSession,
        isNotNull,
      );

      await container.read(connectFF1Provider.future);

      (container.read(connectWiFiProvider.notifier) as _FakeWiFiNotifier)
          .emitSuccess(topicId: 'topic-1');

      await Future<void>.delayed(const Duration(milliseconds: 50));

      final setupState = container.read(ff1SetupOrchestratorProvider);
      expect(setupState.activeSession, isNull);
      // completeSession navigates via appNavigatorKey (no Navigate effect).
      expect(setupState.effect, isNull);
    },
  );

  test(
    'Wi‑Fi success completeSession failure emits error; dedupe allows '
    'another success edge',
    () async {
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
            () => _FakeConnectNotifier(connected),
          ),
          connectWiFiProvider.overrideWith(
            () => _FakeWiFiNotifier(const WiFiConnectionState()),
          ),
          ff1WifiControlProvider.overrideWithValue(_StubWifiControl()),
          ff1ControlProvider.overrideWithValue(
            FF1BleControl(transport: _NoopBleTransport()),
          ),
          ff1BluetoothDeviceActionsProvider.overrideWith(
            _ThrowingBtActions.new,
          ),
          onboardingActionsProvider.overrideWith(
            (ref) => OnboardingService(
              ref: ref,
              appStateService: MockAppStateService(),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      final keepAlive = container.listen(
        ff1SetupOrchestratorProvider,
        (_, _) {},
      );
      addTearDown(keepAlive.close);

      container.read(ff1SetupOrchestratorProvider.notifier).startSession();
      await container.read(connectFF1Provider.future);

      (container.read(connectWiFiProvider.notifier) as _FakeWiFiNotifier)
          .emitSuccess(topicId: 'topic-retry');

      await Future<void>.delayed(const Duration(milliseconds: 50));

      final afterFail = container.read(ff1SetupOrchestratorProvider);
      expect(afterFail.effect, isA<FF1SetupShowError>());
      expect(
        container.read(ff1SetupOrchestratorProvider).activeSession,
        isNotNull,
      );

      (container.read(connectWiFiProvider.notifier) as _FakeWiFiNotifier)
        ..resetToIdle()
        ..emitSuccess(topicId: 'topic-retry');

      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(
        container.read(ff1SetupOrchestratorProvider).effect,
        isA<FF1SetupShowError>(),
      );
    },
  );
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

  /// Clears success so the orchestrator Wi‑Fi listener can observe a new edge.
  void resetToIdle() {
    state = _initial;
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
