import 'package:app/app/bootstrap/app_bootstrap.dart';
import 'package:app/app/patrol/orbit2_patrol_config.dart';
import 'package:app/infra/config/app_config.dart';
import 'package:app/infra/logging/app_logger.dart';
import 'package:flutter/widgets.dart';
import 'package:patrol/patrol.dart';

var _patrolBootstrapInitialized = false;

/// Boots the app with the injected Orbit 2 FF1 device in ObjectBox.
Future<void> createAppForPatrol(
  PatrolIntegrationTester $, {
  required Orbit2PatrolConfig config,
}) async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!_patrolBootstrapInitialized) {
    await AppConfig.initialize();
    await AppLogger.initialize();
    _patrolBootstrapInitialized = true;
  }

  final bootstrap = await bootstrapAppDependencies();
  final injectedDevice = config.toInjectedDevice();

  await bootstrap.bluetoothDeviceService.putDevice(injectedDevice);
  await bootstrap.bluetoothDeviceService.setActiveDevice(
    injectedDevice.deviceId,
  );

  await $.pumpWidgetAndSettle(
    buildBootstrapApp(bootstrap: bootstrap),
  );
}
