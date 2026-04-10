import 'dart:async';

import 'package:app/infra/logging/structured_logger.dart';
import 'package:flutter/widgets.dart';

/// Debounce duration for [AppLifecycleState.inactive] before pausing the FF1
/// relayer Wi‑Fi session. iOS emits `inactive` for transient overlays (Control
/// Center, notification shade), not only real backgrounding.
const kInactiveRelayerWifiPauseDebounce = Duration(milliseconds: 350);

/// What to do for relayer Wi‑Fi pause when the app lifecycle changes.
enum WifiPauseDebouncerAction {
  /// Cancel any pending inactive debounce timer only.
  cancelTimerOnly,

  /// Cancel timer and pause relayer Wi‑Fi immediately.
  cancelTimerAndPauseWifiNow,

  /// Start the inactive debounce timer if none is running.
  scheduleInactiveTimerIfNone,
}

/// Maps lifecycle state to debouncer action (pure; easy to unit test).
WifiPauseDebouncerAction wifiPauseDebouncerActionFor(AppLifecycleState state) {
  switch (state) {
    case AppLifecycleState.resumed:
      return WifiPauseDebouncerAction.cancelTimerOnly;
    case AppLifecycleState.inactive:
      return WifiPauseDebouncerAction.scheduleInactiveTimerIfNone;
    case AppLifecycleState.paused:
    case AppLifecycleState.detached:
    case AppLifecycleState.hidden:
      return WifiPauseDebouncerAction.cancelTimerAndPauseWifiNow;
  }
}

/// When the inactive debounce timer fires, run relayer pause only if the app
/// is not back in the foreground. Primary guard: **never** pause from this
/// timer while [AppLifecycleState.resumed].
bool shouldRunDebouncedInactiveWifiPause(AppLifecycleState lifecycleNow) {
  return lifecycleNow != AppLifecycleState.resumed;
}

/// Coordinates debounced relayer pause on `inactive` vs immediate pause on
/// real background transitions.
class InactiveRelayerWifiPauseCoordinator {
  /// Creates a coordinator.
  InactiveRelayerWifiPauseCoordinator({
    required this.debounce,
    required this.structuredLog,
  });

  /// Debounce length for [AppLifecycleState.inactive].
  final Duration debounce;

  /// Logger with `component: app_lifecycle` (or similar).
  final StructuredLogger structuredLog;

  Timer? _timer;

  /// Clears any pending timer (e.g. on provider dispose).
  void dispose() {
    _timer?.cancel();
    _timer = null;
  }

  /// Handles one lifecycle transition for relayer Wi‑Fi pause policy.
  void onLifecycle({
    required AppLifecycleState state,
    required AppLifecycleState Function() readLifecycle,
    required void Function() pauseRelayerWifi,
  }) {
    final action = wifiPauseDebouncerActionFor(state);
    switch (action) {
      case WifiPauseDebouncerAction.cancelTimerOnly:
        _cancelPendingTimer(reason: 'lifecycle_${state.name}');
      case WifiPauseDebouncerAction.cancelTimerAndPauseWifiNow:
        _cancelPendingTimer(reason: 'lifecycle_${state.name}_immediate_pause');
        pauseRelayerWifi();
      case WifiPauseDebouncerAction.scheduleInactiveTimerIfNone:
        if (_timer != null) {
          structuredLog.info(
            category: LogCategory.wifi,
            event: 'inactive_wifi_pause_debounce_ignored_duplicate',
            message:
                'inactive received while debounce timer already pending — '
                'not rescheduling',
            payload: {'lifecycleState': state.name},
          );
          return;
        }
        structuredLog.info(
          category: LogCategory.wifi,
          event: 'inactive_wifi_pause_debounce_scheduled',
          message: 'scheduling debounced relayer pause for inactive',
          payload: {
            'lifecycleState': state.name,
            'debounceMs': debounce.inMilliseconds,
          },
        );
        _timer = Timer(debounce, () {
          _timer = null;
          final now = readLifecycle();
          if (!shouldRunDebouncedInactiveWifiPause(now)) {
            structuredLog.info(
              category: LogCategory.wifi,
              event: 'inactive_wifi_pause_debounce_fire_skipped',
              message:
                  'debounced inactive pause skipped — app is foreground again',
              payload: {'lifecycleStateNow': now.name},
            );
            return;
          }
          structuredLog.info(
            category: LogCategory.wifi,
            event: 'inactive_wifi_pause_debounce_fired',
            message: 'debounced inactive pause firing — pausing relayer Wi‑Fi',
            payload: {'lifecycleStateNow': now.name},
          );
          pauseRelayerWifi();
        });
    }
  }

  void _cancelPendingTimer({required String reason}) {
    if (_timer == null) {
      return;
    }
    _timer!.cancel();
    _timer = null;
    structuredLog.info(
      category: LogCategory.wifi,
      event: 'inactive_wifi_pause_debounce_canceled',
      message: 'canceled debounced inactive relayer pause',
      payload: {'reason': reason},
    );
  }
}
