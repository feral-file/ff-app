import 'dart:io';

import 'package:app/app/app.dart';
import 'package:app/app/providers/app_provider_observer.dart';
import 'package:app/app/providers/ff1_bluetooth_device_providers.dart';
import 'package:app/app/providers/onboarding_provider.dart';
import 'package:app/app/routing/routes.dart';
import 'package:app/infra/config/app_config.dart';
import 'package:app/infra/config/app_state_service.dart';
import 'package:app/infra/database/ff1_bluetooth_device_service.dart';
import 'package:app/infra/database/objectbox_init.dart';
import 'package:app/infra/database/objectbox_models.dart';
import 'package:app/infra/database/seed_database_gate.dart';
import 'package:app/infra/logging/app_logger.dart';
import 'package:app/infra/services/legacy_storage_locator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

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
                    'The app cannot start because required environment '
                    'variables are missing from the .env file. '
                    'Please ensure the .env file is correctly created with '
                    'all required configuration values.',
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
  final appStateService = AppStateService(
    appStateBox: store.box<AppStateEntity>(),
    appStateAddressBox: store.box<AppStateAddressEntity>(),
  );

  final legacyStorageLocator = LegacyStorageLocator();
  final hasLegacySqliteDatabase = await legacyStorageLocator
      .hasLegacySqliteDatabase();

  // Read onboarding flag once before starting the app to decide initial route.
  final tempContainer = ProviderContainer();
  var hasDoneOnboarding = await tempContainer.read(
    hasDoneOnboardingProvider.future,
  );
  tempContainer.dispose();

  if (!hasDoneOnboarding && hasLegacySqliteDatabase) {
    await appStateService.setHasSeenOnboarding(hasSeen: true);
    hasDoneOnboarding = true;
  }

  // If the database file already exists (returning user), open the gate
  // immediately so no DB operation is ever delayed. On a fresh install the gate
  // stays locked and is opened by SeedDownloadNotifier once the background
  // download completes (or fails).
  final dbFolder = await getApplicationDocumentsDirectory();
  final dbFile = File(p.join(dbFolder.path, 'playlist_cache.sqlite'));
  if (dbFile.existsSync()) {
    SeedDatabaseGate.complete();
  }

  final String initialLocation;
  if (hasDoneOnboarding || hasLegacySqliteDatabase) {
    initialLocation = Routes.home;
  } else {
    initialLocation = Routes.onboardingIntroducePage;
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
      ],
      child: App(
        initialLocation: initialLocation,
      ),
    ),
  );
}
