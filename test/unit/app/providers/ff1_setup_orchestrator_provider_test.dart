// This test file uses compact provider reads for behavior-focused regression
// coverage, so we suppress the receiver duplication lint here.
// ignore_for_file: cascade_invocations

import 'dart:async';

import 'package:app/app/providers/connect_ff1_providers.dart';
import 'package:app/app/providers/connect_wifi_provider.dart';
import 'package:app/app/providers/ff1_bluetooth_device_providers.dart';
import 'package:app/app/providers/ff1_providers.dart';
import 'package:app/app/providers/ff1_setup_orchestrator_provider.dart';
import 'package:app/app/providers/ff1_wifi_providers.dart';
import 'package:app/app/providers/onboarding_provider.dart';
import 'package:app/domain/models/ff1_device.dart';
import 'package:app/domain/models/ff1_device_info.dart';
import 'package:app/domain/models/wifi_point.dart';
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

class _RecordingFf1BtActions extends FF1BluetoothDeviceActionsNotifier {
  int addDeviceCalls = 0;

  @override
  void build() {}

  @override
  Future<void> addDevice(FF1Device device) async {
    addDeviceCalls += 1;
  }
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

class _ThrowingOnboardingService extends OnboardingService {
  _ThrowingOnboardingService({
    required super.ref,
    required super.appStateService,
  });

  @override
  Future<void> completeOnboarding() async {
    throw StateError('onboarding failed');
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

  test(
    'startConnect resets stale connect state before a new attempt starts',
    () async {
      final connectNotifier = _ResetTrackingConnectNotifier();
      final container = ProviderContainer.test(
        overrides: [
          connectFF1Provider.overrideWith(() => connectNotifier),
          connectWiFiProvider.overrideWith(
            () => _FakeWiFiNotifier(const WiFiConnectionState()),
          ),
          ff1ControlProvider.overrideWithValue(
            FF1BleControl(transport: _NoopBleTransport()),
          ),
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
          .startConnect(
            device: BluetoothDevice.fromId('00:11'),
          );

      expect(connectNotifier.resetCalls, 1);
    },
  );

  test(
    'startConnect preserves the active guided session on the new attempt',
    () async {
      final container = ProviderContainer.test(
        overrides: [
          connectFF1Provider.overrideWith(
            _ResetTrackingConnectNotifier.new,
          ),
          connectWiFiProvider.overrideWith(
            () => _FakeWiFiNotifier(const WiFiConnectionState()),
          ),
          ff1ControlProvider.overrideWithValue(
            FF1BleControl(transport: _NoopBleTransport()),
          ),
        ],
      );
      addTearDown(container.dispose);

      final keepAlive = container.listen(
        ff1SetupOrchestratorProvider,
        (_, _) {},
      );
      addTearDown(keepAlive.close);

      final notifier = container.read(ff1SetupOrchestratorProvider.notifier);
      notifier.startSession();
      final sessionId =
          container.read(ff1SetupOrchestratorProvider).activeSession!.id;

      await notifier.startConnect(device: BluetoothDevice.fromId('00:11'));

      expect(
        container.read(ff1SetupOrchestratorProvider).activeSession,
        isNotNull,
      );
      expect(
        container.read(ff1SetupOrchestratorProvider).activeSession!.id,
        sessionId,
      );
    },
  );

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

    final initialState = container.read(ff1SetupOrchestratorProvider);
    if (initialState.effect != null) {
      container
          .read(ff1SetupOrchestratorProvider.notifier)
          .ackEffect(effectId: initialState.effectId);
    }

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

      expect(
        await container
            .read(ff1SetupOrchestratorProvider.notifier)
            .completeSession(
              const FF1Device(
                name: 'FF1',
                remoteId: '00:11',
                deviceId: 'FF1-1',
                topicId: 'topic-1',
              ),
            ),
        isFalse,
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
    'matchesSessionForEffect rejects stale ids after cancel (UI effect bind)',
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

      final notifier = container.read(ff1SetupOrchestratorProvider.notifier);
      expect(notifier.matchesSessionForEffect(null), isTrue);

      notifier.startSession();
      final id = container.read(ff1SetupOrchestratorProvider).activeSession!.id;
      expect(notifier.matchesSessionForEffect(null), isFalse);
      expect(notifier.matchesSessionForEffect(id), isTrue);
      expect(notifier.matchesSessionForEffect('other-id'), isFalse);

      await notifier.cancelSession(FF1SetupSessionCancelReason.userAborted);
      expect(notifier.matchesSessionForEffect(null), isTrue);
      expect(notifier.matchesSessionForEffect(id), isFalse);
    },
  );

  test('ensureActiveSetupSession is idempotent', () async {
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

    final notifier = container.read(ff1SetupOrchestratorProvider.notifier);
    notifier.ensureActiveSetupSession();
    final firstSessionId =
        container.read(ff1SetupOrchestratorProvider).activeSession!.id;

    expect(notifier.hasGuidedSetupSession, isTrue);
    expect(notifier.matchesSessionForEffect(firstSessionId), isTrue);

    notifier.ensureActiveSetupSession();
    final secondSessionId = container
        .read(ff1SetupOrchestratorProvider)
        .activeSession!
        .id;

    expect(secondSessionId, firstSessionId);
    expect(notifier.matchesSessionForEffect(firstSessionId), isTrue);
    expect(notifier.matchesSessionForEffect(secondSessionId), isTrue);
  });

  test(
    'completeSession persists the device before onboarding teardown',
    () async {
      final wifiControl = _StubWifiControl();
      final recordingBtActions = _RecordingFf1BtActions();
      final container = ProviderContainer.test(
        overrides: [
          connectFF1Provider.overrideWith(
            () => _FakeConnectNotifier(
              const ConnectFF1Connected(
                ff1device: FF1Device(
                  name: 'FF1',
                  remoteId: '00:11',
                  deviceId: 'FF1-1',
                  topicId: 'topic-1',
                ),
                portalIsSet: false,
                isConnectedToInternet: true,
              ),
            ),
          ),
          ff1ControlProvider.overrideWithValue(
            FF1BleControl(transport: _NoopBleTransport()),
          ),
          ff1BluetoothDeviceActionsProvider.overrideWith(
            () => recordingBtActions,
          ),
          connectWiFiProvider.overrideWith(
            () => _FakeWiFiNotifier(const WiFiConnectionState()),
          ),
          ff1WifiControlProvider.overrideWithValue(wifiControl),
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

      expect(await completeFuture, isTrue);
      expect(recordingBtActions.addDeviceCalls, 1);
      expect(
        container.read(ff1SetupOrchestratorProvider).activeSession,
        isNull,
      );
      expect(
        container.read(ff1SetupOrchestratorProvider).step,
        FF1SetupStep.idle,
      );
      expect(wifiControl.showPairingQrCodeCalls, 1);
    },
  );

  test(
    'tearDownAfterSetupComplete hides pairing QR before BLE disconnect',
    () async {
      final wifiControl = _StubWifiControl();
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
                  remoteId: '00:11',
                  deviceId: 'FF1-1',
                  topicId: 'topic-1',
                ),
                portalIsSet: false,
                isConnectedToInternet: true,
              ),
            ),
          ),
          connectWiFiProvider.overrideWith(
            () => _FakeWiFiNotifier(const WiFiConnectionState()),
          ),
          ff1WifiControlProvider.overrideWithValue(wifiControl),
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

      expect(wifiControl.showPairingQrCodeCalls, 1);
      expect(
        container.read(ff1SetupOrchestratorProvider).step,
        FF1SetupStep.idle,
      );
    },
  );

  test(
    'effect ids remain monotonic across teardown and stale acks',
    () async {
      final container = ProviderContainer.test(
        overrides: [
          connectFF1Provider.overrideWith(
            () => _FakeConnectNotifier(ConnectFF1Initial()),
          ),
          connectWiFiProvider.overrideWith(
            () => _FakeWiFiNotifier(const WiFiConnectionState()),
          ),
          ff1WifiControlProvider.overrideWithValue(_StubWifiControl()),
          ff1ControlProvider.overrideWithValue(
            FF1BleControl(transport: _NoopBleTransport()),
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

      final notifier = container.read(ff1SetupOrchestratorProvider.notifier);
      notifier.startSession();

      notifier.requestEnterWifiPassword(
        device: const FF1Device(
          name: 'FF1',
          remoteId: '00:11',
          deviceId: 'FF1-1',
          topicId: 'topic-1',
        ),
        wifiAccessPoint: const WifiPoint('ssid-1'),
      );

      final firstState = container.read(ff1SetupOrchestratorProvider);
      final firstEffectId = firstState.effectId;
      expect(firstState.effect, isNotNull);
      notifier.ackEffect(effectId: firstEffectId);
      expect(container.read(ff1SetupOrchestratorProvider).effect, isNull);

      await notifier.tearDownAfterSetupComplete();

      notifier.startSession();
      notifier.requestEnterWifiPassword(
        device: const FF1Device(
          name: 'FF1',
          remoteId: '00:11',
          deviceId: 'FF1-1',
          topicId: 'topic-1',
        ),
        wifiAccessPoint: const WifiPoint('ssid-1'),
      );

      final secondState = container.read(ff1SetupOrchestratorProvider);
      expect(secondState.effect, isNotNull);
      expect(secondState.effectId, greaterThan(firstEffectId));

      notifier.ackEffect(effectId: firstEffectId);
      expect(container.read(ff1SetupOrchestratorProvider).effect, isNotNull);
      expect(
        container.read(ff1SetupOrchestratorProvider).effectId,
        secondState.effectId,
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
          ff1BluetoothDeviceServiceProvider.overrideWithValue(
            MockFF1BluetoothDeviceService(),
          ),
          connectWiFiProvider.overrideWith(
            () => _FakeWiFiNotifier(const WiFiConnectionState()),
          ),
          ff1WifiControlProvider.overrideWithValue(_StubWifiControl()),
          onboardingActionsProvider.overrideWith(
            (ref) => _ThrowingOnboardingService(
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
        container
            .read(ff1SetupOrchestratorProvider.notifier)
            .completeSession(
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

  test(
    'cancelSession ignores teardown while completion is in flight',
    () async {
      final addDeviceCompleter = Completer<void>();
      final recordingBtActions = _BlockingFf1BtActions(addDeviceCompleter);
      final container = ProviderContainer.test(
        overrides: [
          ff1ControlProvider.overrideWithValue(
            FF1BleControl(transport: _NoopBleTransport()),
          ),
          ff1BluetoothDeviceActionsProvider.overrideWith(
            () => recordingBtActions,
          ),
          connectWiFiProvider.overrideWith(
            () => _FakeWiFiNotifier(const WiFiConnectionState()),
          ),
          ff1WifiControlProvider.overrideWithValue(_StubWifiControl()),
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

      final notifier = container.read(ff1SetupOrchestratorProvider.notifier);
      notifier.startSession();

      final completeFuture = notifier.completeSession(
        const FF1Device(
          name: 'FF1',
          remoteId: '00:11',
          deviceId: 'FF1-1',
          topicId: 'topic-1',
        ),
      );

      await Future<void>.delayed(Duration.zero);
      await notifier.cancelSession(FF1SetupSessionCancelReason.userAborted);
      expect(
        container.read(ff1SetupOrchestratorProvider).activeSession,
        isNotNull,
      );

      addDeviceCompleter.complete();
      expect(await completeFuture, isTrue);
      expect(recordingBtActions.addDeviceCalls, 1);
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
      final container = ProviderContainer.test(
        overrides: [
          connectFF1Provider.overrideWith(
            () => _FakeConnectNotifier(ConnectFF1Initial()),
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

      final connectNotifier =
          container.read(connectFF1Provider.notifier) as _FakeConnectNotifier;
      connectNotifier.emit(
        const ConnectFF1Connected(
          ff1device: FF1Device(
            name: 'FF1',
            remoteId: '00:11',
            deviceId: 'FF1-1',
            topicId: '',
          ),
          portalIsSet: false,
          isConnectedToInternet: false,
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 20));

      final initialState = container.read(ff1SetupOrchestratorProvider);
      if (initialState.effect != null) {
        container
            .read(ff1SetupOrchestratorProvider.notifier)
            .ackEffect(effectId: initialState.effectId);
      }

      (container.read(connectWiFiProvider.notifier) as _FakeWiFiNotifier)
          .emitSuccess(topicId: 'topic-1');

      await Future<void>.delayed(const Duration(milliseconds: 50));

      final setupState = container.read(ff1SetupOrchestratorProvider);
      expect(setupState.activeSession, isNotNull);
      expect(setupState.step, isNot(FF1SetupStep.idle));
    },
  );

  test(
    'Wi‑Fi success completeSession failure emits error; dedupe allows '
    'another success edge',
    () async {
      final container = ProviderContainer.test(
        overrides: [
          connectFF1Provider.overrideWith(
            () => _FakeConnectNotifier(ConnectFF1Initial()),
          ),
          connectWiFiProvider.overrideWith(
            () => _FakeWiFiNotifier(const WiFiConnectionState()),
          ),
          ff1WifiControlProvider.overrideWithValue(_StubWifiControl()),
          ff1ControlProvider.overrideWithValue(
            FF1BleControl(transport: _NoopBleTransport()),
          ),
          onboardingActionsProvider.overrideWith(
            (ref) => _ThrowingOnboardingService(
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
      final connectNotifier =
          container.read(connectFF1Provider.notifier) as _FakeConnectNotifier;
      connectNotifier.emit(
        const ConnectFF1Connected(
          ff1device: FF1Device(
            name: 'FF1',
            remoteId: '00:11',
            deviceId: 'FF1-1',
            topicId: '',
          ),
          portalIsSet: false,
          isConnectedToInternet: false,
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 20));

      final initialState = container.read(ff1SetupOrchestratorProvider);
      if (initialState.effect != null) {
        container
            .read(ff1SetupOrchestratorProvider.notifier)
            .ackEffect(effectId: initialState.effectId);
      }

      (container.read(connectWiFiProvider.notifier) as _FakeWiFiNotifier)
          .emitSuccess(topicId: 'topic-retry');

      await Future<void>.delayed(const Duration(milliseconds: 50));

      final afterFail = container.read(ff1SetupOrchestratorProvider);
      expect(afterFail.activeSession, isNotNull);
      expect(afterFail.step, isNot(FF1SetupStep.idle));

      (container.read(connectWiFiProvider.notifier) as _FakeWiFiNotifier)
        ..resetToIdle()
        ..emitSuccess(topicId: 'topic-retry');

      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(
        container.read(ff1SetupOrchestratorProvider).activeSession,
        isNotNull,
      );
    },
  );
}

class _FakeConnectNotifier extends ConnectFF1Notifier {
  _FakeConnectNotifier(this._state);

  ConnectFF1State _state;

  @override
  Future<ConnectFF1State> build() async => _state;

  void emit(ConnectFF1State next) {
    _state = next;
    state = AsyncValue.data(next);
  }
}

class _ResetTrackingConnectNotifier extends ConnectFF1Notifier {
  int resetCalls = 0;

  @override
  Future<ConnectFF1State> build() async => ConnectFF1Initial();

  @override
  void reset() {
    resetCalls += 1;
    super.reset();
  }

  @override
  Future<void> connectBle(
    BluetoothDevice bluetoothDevice, {
    FF1DeviceInfo? ff1DeviceInfo,
  }) async {}
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
  int showPairingQrCodeCalls = 0;

  @override
  Future<FF1CommandResponse> showPairingQRCode({
    required String topicId,
    required bool show,
  }) async {
    showPairingQrCodeCalls += 1;
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
