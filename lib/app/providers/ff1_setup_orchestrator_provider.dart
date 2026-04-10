import 'dart:async';

// ignore_for_file: public_member_api_docs // Internal app module; not a public API.

import 'package:app/app/ff1_setup/ff1_setup_derivation.dart';
import 'package:app/app/ff1_setup/ff1_setup_effect.dart';
import 'package:app/app/ff1_setup/ff1_setup_models.dart';
import 'package:app/app/providers/connect_ff1_providers.dart';
import 'package:app/app/providers/connect_wifi_provider.dart';
import 'package:app/app/providers/ff1_bluetooth_device_providers.dart';
import 'package:app/app/providers/ff1_providers.dart';
import 'package:app/app/providers/ff1_wifi_providers.dart';
import 'package:app/app/providers/onboarding_provider.dart';
import 'package:app/app/routing/app_navigator_key.dart';
import 'package:app/app/routing/routes.dart';
import 'package:app/domain/models/ff1_device.dart';
import 'package:app/domain/models/ff1_device_info.dart';
import 'package:app/domain/models/ff1_error.dart';
import 'package:app/domain/models/wifi_point.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:logging/logging.dart';
import 'package:uuid/uuid.dart';

export 'package:app/app/ff1_setup/ff1_setup_models.dart';

final _log = Logger('FF1SetupOrchestrator');

/// Orchestrator provider: aggregates sub-flow providers without changing UX.
///
/// This does not re-implement flow logic; it listens to:
/// - `connectFF1Provider` (connect + info + ensure-ready outcome)
/// - `connectWiFiProvider` (Wi‑Fi provisioning)
///
/// Screens can listen to this single provider for routing decisions while
/// preserving existing UI steps and copy.
class FF1SetupOrchestratorNotifier extends Notifier<FF1SetupState> {
  BluetoothDevice? _selectedDevice;
  FF1DeviceInfo? _deeplinkInfo;
  FF1SetupSession? _activeSession;
  bool _listenersRegistered = false;
  int _effectId = 0;
  FF1SetupEffect? _pendingEffect;

  /// True after `startConnect` begins a new BLE attempt until `reset`.
  ///
  /// Connect navigation effects are emitted from
  /// `_handleConnectAsyncTransition` (driven by `ref.watch` + microtask) only
  /// when there is a recognizable
  /// prior connect state (Connecting, StillConnecting, Initial, Error, or prior
  /// Connected) or when a connect attempt is active — otherwise stale
  /// `ConnectFF1Connected` without a real in-app attempt would spuriously
  /// navigate.
  bool _connectAttemptActive = false;
  int _connectAttemptSeq = 0;
  int _connectAttemptSeqWithEmittedEffect = 0;
  String _wifiNavEmittedForTopicId = '';
  bool _wifiNavEmittedForSuccessWithoutTopicId = false;

  /// Snapshot of `connectFF1Provider` after the previous `build` completed.
  ///
  /// Used with `ref.watch` + a microtask to derive connect side-effects. A
  /// `ref.listen(connectFF1Provider)` on this notifier does not reliably
  /// observe every `AsyncNotifier` transition (e.g. fast Connecting→Connected),
  /// while `watch` always rebuilds when the async state changes.
  AsyncValue<ConnectFF1State>? _connectAsyncSnapshotAtPreviousBuild;

  @override
  FF1SetupState build() {
    _ensureListenersRegistered();
    final connectAsync = ref.watch(connectFF1Provider);
    final wifi = ref.watch(connectWiFiProvider);

    final prevConnectAsync = _connectAsyncSnapshotAtPreviousBuild;
    _connectAsyncSnapshotAtPreviousBuild = connectAsync;
    unawaited(
      Future<void>.microtask(() {
        final nextConnectAsync = ref.read(connectFF1Provider);
        _handleConnectAsyncTransition(prevConnectAsync, nextConnectAsync);
      }),
    );
    // Mirror connect path: ref.listen on Wi‑Fi can miss a transition in some
    // timing cases; re-check success after build the same way we use a
    // microtask for connect AsyncNotifier transitions.
    unawaited(
      Future<void>.microtask(() {
        final wifiNow = ref.read(connectWiFiProvider);
        _tryEmitWifiSuccessNavigation(wifiNow);
      }),
    );

    final derived = deriveFf1SetupState(
      connectAsync: connectAsync,
      wifi: wifi,
      selectedDevice: _selectedDevice,
      deeplinkInfo: _deeplinkInfo,
    );
    return derived.copyWith(
      effectId: _effectId,
      hasEffect: true,
      effect: _pendingEffect,
      hasActiveSession: true,
      activeSession: _activeSession,
    );
  }

  void _emitEffect(FF1SetupEffect effect) {
    _effectId += 1;
    _pendingEffect = effect;
    _log.info(
      '[effect] emit effectId=$_effectId type=${effect.runtimeType}',
    );
    state = state.copyWith(
      effectId: _effectId,
      hasEffect: true,
      effect: _pendingEffect,
    );
  }

  /// Connect navigation / error effects (replaces unreliable `ref.listen` on
  /// `connectFF1Provider` inside this `Notifier` — see
  /// `_connectAsyncSnapshotAtPreviousBuild`).
  void _handleConnectAsyncTransition(
    AsyncValue<ConnectFF1State>? previous,
    AsyncValue<ConnectFF1State> next,
  ) {
    final prev = previous?.maybeWhen<ConnectFF1State?>(
      data: (v) => v,
      orElse: () => null,
    );
    final cur = next.maybeWhen<ConnectFF1State?>(
      data: (v) => v,
      orElse: () => null,
    );
    if (cur == null) {
      return;
    }

    _log.fine(
      '[connect] snapshot: prev=${prev.runtimeType} '
      'cur=${cur.runtimeType} '
      'attemptActive=$_connectAttemptActive',
    );

    if (cur is ConnectFF1Cancelled && prev is! ConnectFF1Cancelled) {
      _connectAttemptActive = false;
      return;
    }

    if (cur is ConnectFF1Connected && prev != cur) {
      final hasPriorConnectData =
          prev is ConnectFF1Connecting ||
          prev is ConnectFF1StillConnecting ||
          prev is ConnectFF1Initial ||
          prev is ConnectFF1Error ||
          prev is ConnectFF1Connected;
      if (!hasPriorConnectData && !_connectAttemptActive) {
        _log.warning(
          '[connect] skip emit on Connected: '
          'prev=${prev.runtimeType} attemptActive=$_connectAttemptActive '
          '(likely stale Connected without in-app attempt)',
        );
        return;
      }
      if (_connectAttemptSeq > 0 &&
          _connectAttemptSeqWithEmittedEffect == _connectAttemptSeq) {
        return;
      }
      _log.info(
        '[connect] emitting effect from Connected: '
        'internet=${cur.isConnectedToInternet} '
        'portalIsSet=${cur.portalIsSet}',
      );
      if (_connectAttemptActive) {
        _connectAttemptSeqWithEmittedEffect = _connectAttemptSeq;
      }
      if (cur.isConnectedToInternet) {
        _emitEffect(FF1SetupInternetReady(connected: cur));
      } else {
        _emitEffect(FF1SetupNeedsWiFi(device: cur.ff1device));
      }
      _connectAttemptActive = false;
      return;
    }

    if (cur is ConnectFF1Connected && prev == cur) {
      _log.fine(
        '[connect] Connected repeated; no effect emitted '
        '(prev == cur identity)',
      );
    }

    if (cur is ConnectFF1Error &&
        (prev is! ConnectFF1Error ||
            prev.exception.toString() != cur.exception.toString())) {
      final ex = cur.exception;
      if (ex is FF1ResponseError) {
        _emitEffect(
          FF1SetupShowError(
            title: ex.title,
            message: ex.message,
            showSupportCta: ex.shouldShowSupport,
          ),
        );
        return;
      }

      _emitEffect(
        FF1SetupShowError(
          title: 'Connect failed',
          message: ex.toString(),
          showSupportCta: true,
        ),
      );
      _connectAttemptActive = false;
    }
  }

  /// After Wi‑Fi success, builds [FF1Device] using [topicId] and connect /
  /// BLE context (same inputs as setup derivation).
  FF1Device? _ff1DeviceAfterWifiSuccess({required String topicId}) {
    if (topicId.isEmpty) {
      return null;
    }
    final connectData = ref.read(connectFF1Provider).asData?.value;
    if (connectData is ConnectFF1Connected) {
      return connectData.ff1device.copyWith(topicId: topicId);
    }
    final ble = _selectedDevice;
    final link = _deeplinkInfo;
    if (ble != null && link != null) {
      return FF1Device.fromBluetoothDeviceAndDeviceInfo(ble, link).copyWith(
        topicId: topicId,
      );
    }
    _log.warning(
      '[wifi] cannot build FF1Device: need ConnectFF1Connected or '
      'selectedDevice + deeplinkInfo',
    );
    return null;
  }

  /// Emits Navigate(deviceConfiguration) when Wi‑Fi reaches terminal success.
  ///
  /// When a guided setup session is active and `_ff1DeviceAfterWifiSuccess`
  /// returns non-null, `completeSession` runs. Otherwise only a navigate
  /// effect is emitted (e.g. Wi‑Fi reconfigure).
  ///
  /// Shared by `ref.listen` and a post-build microtask so we do not rely on a
  /// single delivery path (same motivation as `_handleConnectAsyncTransition`).
  void _tryEmitWifiSuccessNavigation(WiFiConnectionState next) {
    if (next.status != WiFiConnectionStatus.success) {
      return;
    }
    final nextTopicId = next.topicId ?? '';
    if (nextTopicId.isNotEmpty) {
      if (nextTopicId == _wifiNavEmittedForTopicId) {
        return;
      }
      _wifiNavEmittedForTopicId = nextTopicId;
    } else {
      if (_wifiNavEmittedForSuccessWithoutTopicId) {
        return;
      }
      _wifiNavEmittedForSuccessWithoutTopicId = true;
    }

    final resolved = _ff1DeviceAfterWifiSuccess(topicId: nextTopicId);
    if (resolved != null && _activeSession != null) {
      _log.info(
        '[wifi] completing setup session via completeSession '
        '(session=${_activeSession!.id})',
      );
      unawaited(
        () async {
          try {
            await completeSession(resolved);
          } on Object catch (e, st) {
            _log.severe(
              '[wifi] completeSession after Wi‑Fi success failed',
              e,
              st,
            );
          }
        }(),
      );
      return;
    }

    _log.info(
      '[wifi] emitting navigation on Wi‑Fi success (no setup session or could '
      'not build FF1Device): '
      'topicId="${nextTopicId.isEmpty ? "(empty)" : "(set)"}"',
    );
    _emitEffect(
      const FF1SetupNavigate(
        route: Routes.deviceConfiguration,
        method: FF1SetupNavigationMethod.go,
      ),
    );
    unawaited(
      () async {
        if (nextTopicId.isNotEmpty) {
          try {
            await ref
                .read(ff1WifiControlProvider)
                .showPairingQRCode(
                  topicId: nextTopicId,
                  show: false,
                );
          } on Object {
            // Best-effort: hiding the QR code should not block navigation.
          }
        }
      }(),
    );
  }

  /// Starts a new guided setup session (idempotent if one is already active).
  void startSession() {
    _ensureListenersRegistered();
    _activeSession = FF1SetupSession(
      id: const Uuid().v4(),
      startedAt: DateTime.now(),
    );
    _log.info('[setupSession] started id=${_activeSession!.id}');
    state = state.copyWith(
      hasActiveSession: true,
      activeSession: _activeSession,
    );
  }

  /// Ensures a guided setup session exists for flows that entered from Start /
  /// Onboarding setup entry points.
  void ensureActiveSetupSession() {
    if (_activeSession != null) {
      return;
    }
    startSession();
  }

  /// Persists [device], completes onboarding, hides pairing QR (when
  /// [FF1Device.topicId] is set), disconnects BLE, resets ephemeral setup
  /// state, then navigates to device configuration via the root router
  /// (no navigation effect — avoids duplicate UI handling).
  ///
  /// No-op when there is no active setup session (caller should treat as
  /// already-finished / abandoned cleanup).
  Future<void> completeSession(FF1Device device) async {
    _ensureListenersRegistered();
    if (_activeSession == null) {
      return;
    }
    final sessionId = _activeSession!.id;
    try {
      await ref
          .read(ff1BluetoothDeviceActionsProvider.notifier)
          .addDevice(device);
      await ref.read(onboardingActionsProvider).completeOnboarding();
      await _hidePairingQrCodeBestEffortBeforeBleDisconnect(device);
      await _disconnectBleBestEffort();
    } on Object catch (e, st) {
      _log.severe('completeSession failed (session=$sessionId)', e, st);
      rethrow;
    }
    _activeSession = null;
    ref.read(connectFF1Provider.notifier).reset();
    ref.read(connectWiFiProvider.notifier).reset();
    _connectAttemptActive = false;
    _wifiNavEmittedForTopicId = '';
    _wifiNavEmittedForSuccessWithoutTopicId = false;
    _selectedDevice = null;
    _deeplinkInfo = null;
    _connectAsyncSnapshotAtPreviousBuild = null;
    _pendingEffect = null;
    state = FF1SetupState(
      step: FF1SetupStep.idle,
      effectId: _effectId,
    );
    _goToDeviceConfigurationAfterSessionComplete();
  }

  /// Session completion routes here; legacy Wi‑Fi flow still uses effects.
  void _goToDeviceConfigurationAfterSessionComplete() {
    unawaited(
      Future<void>.microtask(() {
        final ctx = appNavigatorKey.currentContext;
        if (ctx == null || !ctx.mounted) {
          _log.warning(
            'completeSession: no navigator context; skipping go() to '
            '${Routes.deviceConfiguration}',
          );
          return;
        }
        GoRouter.of(ctx).go(Routes.deviceConfiguration);
      }),
    );
  }

  /// Abandons the entire guided setup: cancels BLE, disconnects, clears
  /// session, and resets ephemeral setup state. Prefer over [cancel] when the
  /// user leaves the flow without success.
  Future<void> cancelSession(FF1SetupSessionCancelReason reason) async {
    _ensureListenersRegistered();
    if (_activeSession == null) {
      return;
    }
    _log.info('[setupSession] cancelSession: $reason');
    cancel();
    await _disconnectBleBestEffort();
    reset();
  }

  void _ensureListenersRegistered() {
    if (_listenersRegistered) {
      return;
    }
    _listenersRegistered = true;

    ref.listen<WiFiConnectionState>(
      connectWiFiProvider,
      (previous, next) {
        final prevStatus = previous?.status;
        final nextStatus = next.status;
        final prevTopicId = previous?.topicId ?? '';
        final nextTopicId = next.topicId ?? '';

        _log.info(
          '[wifi] transition: '
          'status=$prevStatus -> $nextStatus; '
          'topicId="${prevTopicId.isEmpty ? '(empty)' : '(set)'}" -> '
          '"${nextTopicId.isEmpty ? '(empty)' : '(set)'}"',
        );

        if (nextStatus == WiFiConnectionStatus.success) {
          _tryEmitWifiSuccessNavigation(next);
          return;
        }

        if (nextStatus == WiFiConnectionStatus.error) {
          final error = next.error;
          if (error is FF1ResponseError) {
            if (error is DeviceUpdatingError) {
              _emitEffect(const FF1SetupDeviceUpdating());
              return;
            }
            _emitEffect(
              FF1SetupShowError(
                title: error.title,
                message: error.message,
                showSupportCta: error.shouldShowSupport,
              ),
            );
            return;
          }
          if (error is TimeoutException) {
            _emitEffect(
              const FF1SetupShowError(
                title: "Can't reach FF1",
                message:
                    "FF1 didn't respond in time. Make sure FF1 is nearby and "
                    'try again.',
              ),
            );
            return;
          }
          if (error != null) {
            _emitEffect(
              const FF1SetupShowError(
                title: 'Wi‑Fi setup failed',
                message:
                    "FF1 couldn't complete Wi‑Fi setup because of an "
                    'unexpected issue. Contact support for help.',
                showSupportCta: true,
              ),
            );
          }
        }

        // No-op: other Wi‑Fi intermediate states are reflected via derived
        // state.
        if (prevStatus == nextStatus && prevTopicId == nextTopicId) {
          return;
        }
      },
    );
  }

  /// Ensure `device` is persisted and promoted to active before navigation.
  // No longer needed: internet-ready persistence is guaranteed by
  // ConnectFF1Notifier.

  Future<void> startConnect({
    required BluetoothDevice device,
    FF1DeviceInfo? deeplinkInfo,
  }) async {
    _ensureListenersRegistered();
    final attemptSeq = ++_connectAttemptSeq;
    _log.info(
      '[connect] startConnect: attemptSeq=$attemptSeq '
      'deviceId='
      '${device.remoteId.str.isEmpty ? '(empty)' : device.remoteId.str} '
      'deviceName=${device.advName.isEmpty ? '(unknown)' : device.advName} '
      'hasDeeplinkInfo=${deeplinkInfo != null}',
    );
    _selectedDevice = device;
    _deeplinkInfo = deeplinkInfo;
    _connectAttemptActive = true;
    _wifiNavEmittedForTopicId = '';
    _wifiNavEmittedForSuccessWithoutTopicId = false;
    // Refactor-only invariant: avoid stale success causing immediate navigation
    // when the connect page is opened again.
    ref.read(connectWiFiProvider.notifier).reset();
    // Clear any terminal ConnectFF1Connected left from a prior attempt so the
    // connect listener observes real transitions (Connecting → Connected) and
    // fireImmediately does not conflate stale data with a missed transition.
    ref.read(connectFF1Provider.notifier).reset();
    // Clear any one-off effect from a prior attempt without wiping monotonic
    // `_effectId`. Omitting `effect` in copyWith used to null the effect
    // unintentionally; constructor + explicit fields keep notifier state
    // consistent with `build` output.
    _pendingEffect = null;
    state = FF1SetupState(
      step: FF1SetupStep.connecting,
      effectId: _effectId,
      selectedDevice: device,
      deeplinkInfo: deeplinkInfo,
      activeSession: _activeSession,
    );
    await ref
        .read(connectFF1Provider.notifier)
        .connectBle(device, ff1DeviceInfo: deeplinkInfo);
  }

  Future<void> startWifiScan({required FF1Device device}) async {
    _ensureListenersRegistered();
    await ref
        .read(connectWiFiProvider.notifier)
        .connectAndScanNetworks(
          device: device,
        );
  }

  void selectWiFiNetwork(WiFiNetwork network) {
    _ensureListenersRegistered();
    ref.read(connectWiFiProvider.notifier).selectNetwork(network);
  }

  void requestEnterWifiPassword({
    required FF1Device device,
    required WifiPoint wifiAccessPoint,
  }) {
    _ensureListenersRegistered();
    _emitEffect(
      FF1SetupEnterWifiPassword(
        device: device,
        wifiAccessPoint: wifiAccessPoint,
      ),
    );
  }

  Future<void> sendWifiCredentialsAndConnect({
    required FF1Device device,
    required String ssid,
    required String password,
  }) async {
    _ensureListenersRegistered();
    _wifiNavEmittedForTopicId = '';
    _wifiNavEmittedForSuccessWithoutTopicId = false;
    await ref
        .read(connectWiFiProvider.notifier)
        .sendCredentialsAndConnect(
          device: device,
          ssid: ssid,
          password: password,
        );
  }

  void cancel() {
    _ensureListenersRegistered();
    _connectAttemptActive = false;
    ref.read(connectFF1Provider.notifier).cancelConnection();
  }

  /// After FF1 setup succeeds (Internet-ready or Wi‑Fi done), disconnect BLE
  /// and clear ephemeral setup state. Does not remove persisted FF1 devices or
  /// onboarding flags — callers own onboarding completion
  /// (`completeOnboarding`).
  ///
  /// Safe to call more than once; disconnect is best-effort.
  Future<void> tearDownAfterSetupComplete() async {
    _ensureListenersRegistered();
    await _disconnectBleBestEffort();
    reset();
  }

  /// Sends hide-QR over the relayer while BLE is still connected, so the
  /// device can clear the pairing QR before we drop the BLE link.
  Future<void> _hidePairingQrCodeBestEffortBeforeBleDisconnect(
    FF1Device device,
  ) async {
    final topicId = device.topicId;
    if (topicId.isEmpty) {
      return;
    }
    try {
      await ref
          .read(ff1WifiControlProvider)
          .showPairingQRCode(
            topicId: topicId,
            show: false,
          );
    } on Object {
      // Best-effort: hiding the QR must not block session completion.
    }
  }

  Future<void> _disconnectBleBestEffort() async {
    final device = _resolveBluetoothDeviceForDisconnect();
    if (device == null) {
      _log.fine('[tearDown] skip BLE disconnect: no resolvable device');
      return;
    }
    try {
      await ref.read(ff1ControlProvider).disconnect(device);
      _log.info(
        '[tearDown] BLE disconnect requested for ${device.remoteId.str}',
      );
    } on Object catch (e, st) {
      _log.warning('[tearDown] BLE disconnect failed', e, st);
    }
  }

  /// Prefer the device from `startConnect`; fall back to the connected state's
  /// device when the deeplink path left an empty BLE `remoteId` in the
  /// orchestrator snapshot.
  BluetoothDevice? _resolveBluetoothDeviceForDisconnect() {
    final selected = _selectedDevice;
    if (selected != null && selected.remoteId.str.isNotEmpty) {
      return selected;
    }
    final connectData = ref.read(connectFF1Provider).asData?.value;
    if (connectData is ConnectFF1Connected) {
      final rid = connectData.ff1device.remoteId;
      if (rid.isNotEmpty) {
        return BluetoothDevice.fromId(rid);
      }
    }
    return null;
  }

  void reset() {
    _ensureListenersRegistered();
    _connectAttemptActive = false;
    _wifiNavEmittedForTopicId = '';
    _wifiNavEmittedForSuccessWithoutTopicId = false;
    _selectedDevice = null;
    _deeplinkInfo = null;
    _activeSession = null;
    ref.read(connectFF1Provider.notifier).reset();
    ref.read(connectWiFiProvider.notifier).reset();
    _pendingEffect = null;
    _connectAsyncSnapshotAtPreviousBuild = null;
    state = FF1SetupState(
      step: FF1SetupStep.idle,
      effectId: _effectId,
    );
  }

  void ackEffect({required int effectId}) {
    _ensureListenersRegistered();
    if (effectId != _effectId) {
      return;
    }
    _pendingEffect = null;
    state = state.copyWith(
      effectId: _effectId,
      hasEffect: true,
    );
  }
}

final ff1SetupOrchestratorProvider =
    NotifierProvider<FF1SetupOrchestratorNotifier, FF1SetupState>(
      FF1SetupOrchestratorNotifier.new,
    );
