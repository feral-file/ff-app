import 'package:app/app/providers/connect_ff1_providers.dart';
import 'package:app/domain/models/ff1_device.dart';
import 'package:app/domain/models/wifi_point.dart';

sealed class FF1SetupEffect {
  const FF1SetupEffect();
}

/// Navigation intent emitted by FF1 setup orchestration.
final class FF1SetupNavigate extends FF1SetupEffect {
  const FF1SetupNavigate({
    required this.route,
    this.extra,
    this.method = FF1SetupNavigationMethod.replace,
  });

  final String route;
  final Object? extra;
  final FF1SetupNavigationMethod method;
}

enum FF1SetupNavigationMethod {
  push,
  replace,
  go,
}

final class FF1SetupPop extends FF1SetupEffect {
  const FF1SetupPop();
}

/// Internet-ready connect outcome. Use this to drive navigation overrides while
/// keeping side effects owned by the orchestration layer.
final class FF1SetupInternetReady extends FF1SetupEffect {
  const FF1SetupInternetReady({
    required this.connected,
  });

  final ConnectFF1Connected connected;
}

/// FF1 setup requires Wi‑Fi provisioning to proceed.
final class FF1SetupNeedsWiFi extends FF1SetupEffect {
  const FF1SetupNeedsWiFi({
    required this.device,
  });

  final FF1Device device;
}

final class FF1SetupEnterWifiPassword extends FF1SetupEffect {
  const FF1SetupEnterWifiPassword({
    required this.device,
    required this.wifiAccessPoint,
  });

  final FF1Device device;
  final WifiPoint wifiAccessPoint;
}

final class FF1SetupShowError extends FF1SetupEffect {
  const FF1SetupShowError({
    required this.title,
    required this.message,
    this.showSupportCta = false,
  });

  final String title;
  final String message;
  final bool showSupportCta;
}

final class FF1SetupDeviceUpdating extends FF1SetupEffect {
  const FF1SetupDeviceUpdating();
}

