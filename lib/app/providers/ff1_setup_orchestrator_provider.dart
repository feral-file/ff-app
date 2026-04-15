// Internal FF1 setup orchestration is app-private and intentionally keeps a
// compact inline API, so we suppress doc/format lints on this file.
// ignore_for_file: cascade_invocations, lines_longer_than_80_chars,
// ignore_for_file: public_member_api_docs

import 'dart:async';

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
/// - [connectFF1Provider] (connect + info + ensure-ready outcome)
/// - [connectWiFiProvider] (Wi‑Fi provisioning)
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
  bool _sessionCompletionInProgress = false;
  bool _currentConnectAttemptWasGuided = false;

  @override
  FF1SetupState build() {
    _ensureListenersRegistered();
    final connectAsync = ref.watch(connectFF1Provider);
    final wifi = ref.watch(connectWiFiProvider);
    final derived = deriveFf1SetupState(
      connectAsync: connectAsync,
      wifi: wifi,
      selectedDevice: _selectedDevice,
      deeplinkInfo: _deeplinkInfo,
    );
    return derived.copyWith(
      effectId: _effectId,
      effect: _pendingEffect,
      hasEffect: true,
      activeSession: _activeSession,
      hasActiveSession: true,
    );
  }

  void _emitEffect(FF1SetupEffect effect) {
    _effectId += 1;
    _pendingEffect = effect;
    state = state.copyWith(
      effectId: _effectId,
      effect: _pendingEffect,
      hasEffect: true,
    );
  }

  void _ensureListenersRegistered() {
    if (_listenersRegistered) {
      return;
    }
    _listenersRegistered = true;

    ref.listen<AsyncValue<ConnectFF1State>>(
      connectFF1Provider,
      (previous, next) {
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

        if (cur is ConnectFF1Cancelled && prev is! ConnectFF1Cancelled) {
          // Cancellation is an attempt lifecycle state; navigation remains owned
          // by the UI (e.g. cancel button) to avoid double-pop when the route is
          // already being popped (system back gesture / teardown).
          return;
        }

        if (cur is ConnectFF1Connected && prev != cur) {
          if (cur.isConnectedToInternet) {
            // Root-cause fix lives in ConnectFF1Notifier: it persists/promotes
            // the device before emitting ConnectFF1Connected(internet=true).
            _emitEffect(FF1SetupInternetReady(connected: cur));
          } else {
            _emitEffect(FF1SetupNeedsWiFi(device: cur.ff1device));
          }
          return;
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
        }
      },
    );

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

        // Navigation contract: once the device responds with a topicId after
        // sending Wi‑Fi credentials, we should proceed to configuration.
        //
        // Relying solely on status == success is brittle: UI can be stuck in a
        // "connecting" step if a later status transition is missed or not
        // reached. The topicId is the strongest signal that Wi‑Fi provisioning
        // completed.
        final didReceiveTopicId = prevTopicId.isEmpty && nextTopicId.isNotEmpty;
        if (didReceiveTopicId || nextStatus == WiFiConnectionStatus.success) {
          _log.info(
            '[wifi] emitting navigation: '
            'didReceiveTopicId=$didReceiveTopicId; status=$nextStatus',
          );
          _emitEffect(
            const FF1SetupNavigate(
              route: Routes.deviceConfiguration,
              method: FF1SetupNavigationMethod.go,
            ),
          );
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
                    "FF1 didn't respond in time. Make sure FF1 is nearby and try again.",
              ),
            );
            return;
          }
          if (error != null) {
            _emitEffect(
              const FF1SetupShowError(
                title: 'Wi‑Fi setup failed',
                message:
                    "FF1 couldn't complete Wi‑Fi setup because of an unexpected issue. Contact support for help.",
                showSupportCta: true,
              ),
            );
          }
        }

        // No-op: other Wi‑Fi intermediate states are reflected via derived state.
        if (prevStatus == nextStatus && prevTopicId == nextTopicId) {
          return;
        }
      },
    );
  }

  bool get hasGuidedSetupSession => _activeSession != null;

  bool matchesSessionForEffect(String? sessionIdAtEmission) {
    if (sessionIdAtEmission == null) {
      return !_currentConnectAttemptWasGuided;
    }
    return _activeSession?.id == sessionIdAtEmission;
  }

  void startSession() {
    _ensureListenersRegistered();
    if (_activeSession != null) {
      return;
    }
    _activeSession = FF1SetupSession(
      id: const Uuid().v4(),
      startedAt: DateTime.now(),
    );
    state = state.copyWith(
      activeSession: _activeSession,
      hasActiveSession: true,
    );
  }

  void _clearTransientSetupContext() {
    // Teardown must fully scrub setup-local context so retries start from a
    // blank orchestration state instead of inheriting stale device or effect
    // data from a previous attempt.
    _selectedDevice = null;
    _deeplinkInfo = null;
    _pendingEffect = null;
  }

  void ensureActiveSetupSession() {
    if (_activeSession != null) {
      return;
    }
    startSession();
  }

  /// Completes onboarding, then tears down the active setup session.
  ///
  /// The device is persisted before this helper runs on guided and
  /// direct-success paths, so this method owns the shared finish/cleanup work:
  /// hide the pairing QR when possible, disconnect BLE, and optionally reset
  /// ephemeral setup state + navigate to device configuration.
  Future<bool> completeSession(
    FF1Device device, {
    bool shouldNavigate = true,
  }) async {
    _ensureListenersRegistered();
    final session = _activeSession;
    if (session == null || _sessionCompletionInProgress) {
      return false;
    }

    _sessionCompletionInProgress = true;
    try {
      await ref
          .read(ff1BluetoothDeviceActionsProvider.notifier)
          .addDevice(device);
      await _completeOnboarding();
      await tearDownAfterSetupComplete();
      _activeSession = null;
      state = const FF1SetupState(step: FF1SetupStep.idle);
      if (shouldNavigate) {
        _goToDeviceConfigurationAfterSessionComplete();
      }
      return true;
    } finally {
      _sessionCompletionInProgress = false;
    }
  }

  /// Completes an internet-ready setup when no guided session is active.
  ///
  /// This keeps persistence, teardown, and optional navigation in one place,
  /// so standalone success paths do not duplicate onboarding writes in the UI.
  Future<void> completeInternetReadySetup(
    FF1Device device, {
    bool shouldNavigate = true,
  }) async {
    _ensureListenersRegistered();
    if (_sessionCompletionInProgress) {
      return;
    }
    if (_activeSession != null) {
      await completeSession(device, shouldNavigate: shouldNavigate);
      return;
    }

    _sessionCompletionInProgress = true;
    try {
      await ref
          .read(ff1BluetoothDeviceActionsProvider.notifier)
          .addDevice(device);
      await _completeOnboarding();
      await tearDownAfterSetupComplete();
      if (shouldNavigate) {
        _goToDeviceConfigurationAfterSessionComplete();
      }
    } finally {
      _sessionCompletionInProgress = false;
    }
  }

  /// Abandons the entire guided setup: cancels BLE, disconnects, clears
  /// session, and resets ephemeral setup state. Prefer over [cancel] when the
  /// user leaves the flow without success.
  Future<void> cancelSession(FF1SetupSessionCancelReason reason) async {
    _ensureListenersRegistered();
    final session = _activeSession;
    if (session == null || _sessionCompletionInProgress) {
      return;
    }
    _activeSession = null;
    state = const FF1SetupState(step: FF1SetupStep.idle);
    _log.info('[setupSession] cancelSession: $reason');
    cancel();
    await _disconnectBleBestEffort();
    reset();
  }

  /// After FF1 setup succeeds, disconnect BLE and clear ephemeral setup state.
  Future<void> tearDownAfterSetupComplete() async {
    _ensureListenersRegistered();
    await _hidePairingQrCodeBestEffortBeforeBleDisconnect();
    await _disconnectBleBestEffort();
    reset();
  }

  Future<void> _completeOnboarding() async {
    await ref.read(onboardingActionsProvider).completeOnboarding();
  }

  Future<void> _hidePairingQrCodeBestEffortBeforeBleDisconnect() async {
    final device = _resolveDeviceForPairingQrHide();
    final topicId = device?.topicId ?? '';
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

  FF1Device? _resolveDeviceForPairingQrHide() {
    final connectState = ref.read(connectFF1Provider).asData?.value;
    return switch (connectState) {
      ConnectFF1Connected(:final ff1device) => ff1device,
      _ => null,
    };
  }

  Future<void> _disconnectBleBestEffort() async {
    final device = _resolveBluetoothDeviceForDisconnect();
    if (device == null) {
      return;
    }
    try {
      await ref.read(ff1ControlProvider).disconnect(device);
    } on Object {
      // Best-effort cleanup.
    }
  }

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

  void _goToDeviceConfigurationAfterSessionComplete() {
    unawaited(
      Future<void>.microtask(() {
        final ctx = appNavigatorKey.currentContext;
        if (ctx == null || !ctx.mounted) {
          return;
        }
        GoRouter.of(ctx).go(Routes.deviceConfiguration);
      }),
    );
  }

  /// Ensure [device] is persisted and promoted to active before navigation.
  // No longer needed: internet-ready persistence is guaranteed by ConnectFF1Notifier.

  Future<void> startConnect({
    required BluetoothDevice device,
    FF1DeviceInfo? deeplinkInfo,
  }) async {
    _ensureListenersRegistered();
    _currentConnectAttemptWasGuided = _activeSession != null;
    _selectedDevice = device;
    _deeplinkInfo = deeplinkInfo;
    // Refactor-only invariant: avoid stale success causing immediate navigation
    // when the connect page is opened again.
    final connectNotifier = ref.read(connectFF1Provider.notifier);
    final wifiNotifier = ref.read(connectWiFiProvider.notifier);
    connectNotifier.reset();
    wifiNotifier.reset();
    state = state.copyWith(
      step: FF1SetupStep.connecting,
      selectedDevice: device,
      deeplinkInfo: deeplinkInfo,
      hasActiveSession: _activeSession != null,
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
    ref.read(connectFF1Provider.notifier).cancelConnection();
  }

  void reset() {
    _ensureListenersRegistered();
    final connectNotifier = ref.read(connectFF1Provider.notifier);
    final wifiNotifier = ref.read(connectWiFiProvider.notifier);
    connectNotifier.reset();
    wifiNotifier.reset();
    _activeSession = null;
    _clearTransientSetupContext();
    state = const FF1SetupState(step: FF1SetupStep.idle);
  }

  void ackEffect({required int effectId}) {
    _ensureListenersRegistered();
    if (effectId != _effectId) {
      return;
    }
    _pendingEffect = null;
    state = state.copyWith(effectId: _effectId, hasEffect: true);
  }
}

final ff1SetupOrchestratorProvider =
    NotifierProvider<FF1SetupOrchestratorNotifier, FF1SetupState>(
      FF1SetupOrchestratorNotifier.new,
    );
