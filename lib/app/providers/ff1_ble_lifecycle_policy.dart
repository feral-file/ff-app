import 'package:app/app/routing/routes.dart';
import 'package:flutter/widgets.dart';

/// Returns true when BLE should be closed for the current app route.
bool shouldCloseBleForRoute(String routePath) {
  return routePath == Routes.home;
}

/// Returns true when app lifecycle indicates app is in background.
bool isBackgroundLifecycleState(AppLifecycleState state) {
  return state == AppLifecycleState.paused ||
      state == AppLifecycleState.inactive ||
      state == AppLifecycleState.detached;
}

/// Returns true when BLE should reconnect after lifecycle change.
bool shouldReconnectBleOnLifecycle({
  required AppLifecycleState state,
  required String routePath,
}) {
  return state == AppLifecycleState.resumed &&
      !shouldCloseBleForRoute(routePath);
}
