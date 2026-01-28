import 'package:app/app/providers/ff1_bluetooth_device_providers.dart';
import 'package:app/infra/database/ff1_bluetooth_device_service.dart';
import 'package:app/infra/database/objectbox_models.dart';
import 'package:app/infra/database/objectbox_init.dart';
import 'package:app/infra/config/app_config.dart';
import 'package:app/app/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';

void _logHandler(LogRecord record) {
  // ignore: avoid_print
  print(
    '${record.level.name}: ${record.time}: '
    '${record.loggerName}: ${record.message}',
  );
  if (record.error != null) {
    // ignore: avoid_print
    print('Error: ${record.error}');
  }
  if (record.stackTrace != null) {
    // ignore: avoid_print
    print('Stack trace:\n${record.stackTrace}');
  }
}

Future<void> main() async {
  // Ensure Flutter bindings are initialized
  WidgetsFlutterBinding.ensureInitialized();

  // Configure logging
  Logger.root.level = Level.ALL;
  Logger.root.onRecord.listen(_logHandler);

  // Load configuration
  await AppConfig.initialize();

  // Initialize ObjectBox store for Bluetooth device storage
  final store = await initializeObjectBox();
  final bluetoothDeviceBox = store.box<FF1BluetoothDeviceEntity>();
  final bluetoothDeviceService = FF1BluetoothDeviceService(bluetoothDeviceBox);

  runApp(
    ProviderScope(
      // Override the ff1BluetoothDeviceServiceProvider with the initialized
      // service
      overrides: [
        ff1BluetoothDeviceServiceProvider
            .overrideWithValue(bluetoothDeviceService),
      ],
      child: const App(),
    ),
  );
}



