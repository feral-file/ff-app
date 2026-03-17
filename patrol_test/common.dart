import 'package:app/app/bootstrap/app_bootstrap.dart';
import 'package:app/app/patrol/gold_path_patrol_config.dart';
import 'package:app/infra/config/app_config.dart';
import 'package:app/infra/logging/app_logger.dart';
import 'package:flutter/widgets.dart';
import 'package:patrol/patrol.dart';

var _patrolBootstrapInitialized = false;
AppBootstrapResult? _patrolBootstrap;

/// Boots the app with the injected test FF1 device in ObjectBox.
Future<void> createAppForPatrol(
  PatrolIntegrationTester $, {
  required GoldPathPatrolConfig config,
}) async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!_patrolBootstrapInitialized) {
    await AppConfig.initialize();
    await AppLogger.initialize();
    _patrolBootstrapInitialized = true;
  }

  final bootstrap = await bootstrapAppDependencies();
  _patrolBootstrap = bootstrap;
  final injectedDevice = config.toInjectedDevice();

  await bootstrap.bluetoothDeviceService.putDevice(injectedDevice);
  await bootstrap.bluetoothDeviceService.setActiveDevice(
    injectedDevice.deviceId,
  );

  await $.pumpWidgetAndSettle(
    buildBootstrapApp(bootstrap: bootstrap),
  );
}

/// Reasserts the injected FF1 device as active for Patrol flows.
///
/// This protects against transient active-device resets during long onboarding
/// and indexing sequences before the play step runs.
Future<void> ensurePatrolActiveDevice(GoldPathPatrolConfig config) async {
  final bootstrap = _patrolBootstrap;
  if (bootstrap == null) {
    return;
  }

  final injectedDevice = config.toInjectedDevice();
  await bootstrap.bluetoothDeviceService.putDevice(injectedDevice);
  await bootstrap.bluetoothDeviceService.setActiveDevice(
    injectedDevice.deviceId,
  );
}
