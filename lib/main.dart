import 'package:app/app/app.dart';
import 'package:app/app/providers/app_provider_observer.dart';
import 'package:app/app/providers/ff1_bluetooth_device_providers.dart';
import 'package:app/infra/config/app_config.dart';
import 'package:app/infra/database/ff1_bluetooth_device_service.dart';
import 'package:app/infra/database/objectbox_init.dart';
import 'package:app/infra/database/objectbox_models.dart';
import 'package:app/infra/logging/app_logger.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

Future<void> main() async {
  // Ensure Flutter bindings are initialized
  WidgetsFlutterBinding.ensureInitialized();

  // Configure logging sinks (console, OS logger, and file).
  await AppLogger.initialize();
  final logFilePath = AppLogger.currentLogFile?.path;
  if (logFilePath != null) {
    debugPrint('Log file path: $logFilePath');
  }

  // Load configuration
  await AppConfig.initialize();

  // Initialize ObjectBox store for Bluetooth device storage
  final store = await initializeObjectBox();
  final bluetoothDeviceBox = store.box<FF1BluetoothDeviceEntity>();
  final bluetoothDeviceService = FF1BluetoothDeviceService(bluetoothDeviceBox);

  runApp(
    ProviderScope(
      observers: [AppProviderObserver()],
      // Override the ff1BluetoothDeviceServiceProvider with the initialized
      // service
      overrides: [
        ff1BluetoothDeviceServiceProvider.overrideWithValue(
          bluetoothDeviceService,
        ),
      ],
      child: const App(),
    ),
  );
}
