import 'dart:async';

import 'package:app/app/ff1_setup/ff1_setup_derivation.dart';
import 'package:app/app/ff1_setup/ff1_setup_effect.dart';
import 'package:app/app/ff1_setup/ff1_setup_models.dart';
import 'package:app/app/providers/connect_ff1_providers.dart';
import 'package:app/app/providers/connect_wifi_provider.dart';
import 'package:app/app/providers/ff1_wifi_providers.dart';
import 'package:app/app/providers/onboarding_provider.dart';
import 'package:app/app/routing/routes.dart';
import 'package:app/domain/models/ff1_device.dart';
import 'package:app/domain/models/ff1_device_info.dart';
import 'package:app/domain/models/ff1_error.dart';
import 'package:app/domain/models/wifi_point.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

export 'package:app/app/ff1_setup/ff1_setup_models.dart';

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
  bool _listenersRegistered = false;
  int _effectId = 0;
  FF1SetupEffect? _pendingEffect;

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
    return derived.copyWith(effectId: _effectId, effect: _pendingEffect);
  }

  void _emitEffect(FF1SetupEffect effect) {
    _effectId += 1;
    _pendingEffect = effect;
    state = state.copyWith(effectId: _effectId, effect: _pendingEffect);
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
            unawaited(ref.read(onboardingActionsProvider).completeOnboarding());
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
        if (previous?.status == next.status) {
          return;
        }

        if (next.status == WiFiConnectionStatus.success) {
          _emitEffect(
            const FF1SetupNavigate(
              route: Routes.deviceConfiguration,
              method: FF1SetupNavigationMethod.push,
            ),
          );
          unawaited(
            () async {
              final topicId = next.topicId;
              if (topicId != null && topicId.isNotEmpty) {
                try {
                  await ref.read(ff1WifiControlProvider).showPairingQRCode(
                        topicId: topicId,
                        show: false,
                      );
                } on Object {
                  // Best-effort: hiding the QR code should not block navigation.
                }
              }
              await ref.read(onboardingActionsProvider).completeOnboarding();
            }(),
          );
          return;
        }

        if (next.status == WiFiConnectionStatus.error) {
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
                showSupportCta: false,
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
      },
    );
  }

  /// Ensure [device] is persisted and promoted to active before navigation.
  // No longer needed: internet-ready persistence is guaranteed by ConnectFF1Notifier.

  Future<void> startConnect({
    required BluetoothDevice device,
    FF1DeviceInfo? deeplinkInfo,
  }) async {
    _ensureListenersRegistered();
    _selectedDevice = device;
    _deeplinkInfo = deeplinkInfo;
    // Refactor-only invariant: avoid stale success causing immediate navigation
    // when the connect page is opened again.
    ref.read(connectWiFiProvider.notifier).reset();
    state = FF1SetupState(
      step: FF1SetupStep.connecting,
      selectedDevice: device,
      deeplinkInfo: deeplinkInfo,
    );
    await ref
        .read(connectFF1Provider.notifier)
        .connectBle(device, ff1DeviceInfo: deeplinkInfo);
  }

  Future<void> startWifiScan({required FF1Device device}) async {
    _ensureListenersRegistered();
    await ref.read(connectWiFiProvider.notifier).connectAndScanNetworks(
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
    await ref.read(connectWiFiProvider.notifier).sendCredentialsAndConnect(
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
    ref.read(connectFF1Provider.notifier).reset();
    ref.read(connectWiFiProvider.notifier).reset();
    state = const FF1SetupState(step: FF1SetupStep.idle);
  }

  void ackEffect({required int effectId}) {
    _ensureListenersRegistered();
    if (effectId != _effectId) {
      return;
    }
    _pendingEffect = null;
    state = state.copyWith(effectId: _effectId);
  }
}

final ff1SetupOrchestratorProvider =
    NotifierProvider<FF1SetupOrchestratorNotifier, FF1SetupState>(
  FF1SetupOrchestratorNotifier.new,
);

