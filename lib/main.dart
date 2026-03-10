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
import 'package:app/infra/logging/structured_logger.dart';
import 'package:app/infra/services/legacy_storage_locator.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:sentry_logging/sentry_logging.dart';

final StructuredLogger _startupLog = AppStructuredLog.forLogger(
  Logger('MainBootstrap'),
  context: {'layer': 'startup'},
);

Future<void> main() async {
  // Ensure Flutter bindings are initialized
  WidgetsFlutterBinding.ensureInitialized();

  // Load configuration.
  await AppConfig.initialize();

  final sentryDsn = AppConfig.sentryDsn;
  if (sentryDsn.isNotEmpty) {
    await SentryFlutter.init(
      (options) {
        options
          ..dsn = sentryDsn
          ..environment = kReleaseMode ? 'release' : 'debug'
          ..tracesSampleRate = 0.1
          ..addIntegration(LoggingIntegration())
          ..beforeSend = (event, hint) {
            return kDebugMode ? null : event;
          }
          ..beforeSendTransaction = (transaction, hint) {
            return kDebugMode ? null : transaction;
          };
      },
      appRunner: _bootstrapApp,
    );
    return;
  }

  await _bootstrapApp();
}

Future<void> _bootstrapApp() async {
  // Configure logging sinks (console, file, and Sentry when enabled).
  await AppLogger.initialize();
  _startupLog.info(
    category: LogCategory.domain,
    event: 'app_launch',
    message: 'app launch initialized',
  );
  final logFilePath = AppLogger.currentLogFile?.path;
  if (logFilePath != null) {
    debugPrint('Log file path: $logFilePath');
  }

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
  final bluetoothDeviceService = FF1BluetoothDeviceService(
    store,
    bluetoothDeviceBox,
  );
  final appStateService = AppStateService(
    store: store,
    appStateBox: store.box<AppStateEntity>(),
    appStateAddressBox: store.box<AppStateAddressEntity>(),
    trackedAddressBox: store.box<TrackedAddressEntity>(),
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
  final dbFile = File(p.join(dbFolder.path, 'dp1_library.sqlite'));
  if (dbFile.existsSync()) {
    SeedDatabaseGate.complete();
  }

  final String initialLocation;
  if (hasDoneOnboarding || hasLegacySqliteDatabase) {
    initialLocation = Routes.home;
  } else {
    initialLocation = Routes.onboardingIntroducePage;
  }

  await _attachPostOnboardingSentryContext(
    hasDoneOnboarding: hasDoneOnboarding || hasLegacySqliteDatabase,
    appStateService: appStateService,
    bluetoothDeviceService: bluetoothDeviceService,
  );

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

Future<void> _attachPostOnboardingSentryContext({
  required bool hasDoneOnboarding,
  required AppStateService appStateService,
  required FF1BluetoothDeviceService bluetoothDeviceService,
}) async {
  if (!hasDoneOnboarding || !Sentry.isEnabled) {
    return;
  }

  try {
    final addedAddresses = await appStateService.getTrackedPersonalAddresses();
    final ff1DeviceIds =
        bluetoothDeviceService
            .getAllDevices()
            .map((device) => device.deviceId.trim())
            .where((id) => id.isNotEmpty)
            .toSet()
            .toList()
          ..sort();

    return Sentry.configureScope((scope) async {
      await scope.setContexts('post_onboarding_state', {
        'added_addresses': addedAddresses,
        'ff1_device_ids': ff1DeviceIds,
      });
    });
  } on Object catch (error, stackTrace) {
    debugPrint('Failed to attach post-onboarding Sentry context: $error');
    debugPrintStack(stackTrace: stackTrace);
  }
}
