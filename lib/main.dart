import 'package:app/app/app.dart';
import 'package:app/app/providers/app_provider_observer.dart';
import 'package:app/app/providers/ff1_bluetooth_device_providers.dart';
import 'package:app/app/providers/remote_config_provider.dart';
import 'package:app/infra/config/app_config.dart';
import 'package:app/infra/config/remote_app_config.dart';
import 'package:app/infra/config/remote_config_service.dart';
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

  // Validate configuration and fail fast if required values are missing
  if (!AppConfig.isValid) {
    final errorMessage = AppConfig.getValidationErrorMessage();
    debugPrint('❌ CONFIGURATION ERROR:\n$errorMessage');

    // Show error screen and prevent app from booting
    runApp(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.error_outline,
                    size: 64,
                    color: Colors.red,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Configuration Error',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.red,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      border: Border.all(color: Colors.red.shade200),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      errorMessage,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.red.shade900,
                        fontFamily: 'monospace',
                      ),
                      textAlign: TextAlign.left,
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'The app cannot start because required environment variables are missing from the .env file. '
                    'Please ensure the .env file is correctly created with all required configuration values.',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.black87,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    return;
  }

  // Initialize ObjectBox store for Bluetooth device storage
  final store = await initializeObjectBox();
  final bluetoothDeviceBox = store.box<FF1BluetoothDeviceEntity>();
  final bluetoothDeviceService = FF1BluetoothDeviceService(bluetoothDeviceBox);
  final remoteConfigBox = store.box<RemoteAppConfigEntity>();
  final remoteConfigUri = AppConfig.remoteConfigUrl.isEmpty
      ? null
      : Uri.tryParse(AppConfig.remoteConfigUrl);
  final remoteConfigService = RemoteConfigService(
    box: remoteConfigBox,
    remoteConfigUri: remoteConfigUri,
  );

  final cachedConfig = remoteConfigService.loadCached();
  late final RemoteAppConfig initialRemoteConfig;

  // First launch behavior: requires network fetch.
  if (cachedConfig == null) {
    try {
      final fetched = await remoteConfigService.fetchAndPersist();
      initialRemoteConfig = fetched.config;
    } on Exception catch (e) {
      final errorMessage =
          'Failed to load initial remote config from network.\n\n$e';
      runApp(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  errorMessage,
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
        ),
      );
      return;
    }
  } else {
    initialRemoteConfig = cachedConfig.config;
  }

  runApp(
    ProviderScope(
      observers: [AppProviderObserver()],
      // Override the ff1BluetoothDeviceServiceProvider with the initialized
      // service
      overrides: [
        ff1BluetoothDeviceServiceProvider.overrideWithValue(
          bluetoothDeviceService,
        ),
        remoteConfigServiceProvider.overrideWithValue(remoteConfigService),
        initialRemoteAppConfigProvider.overrideWithValue(initialRemoteConfig),
      ],
      child: const App(),
    ),
  );
}
