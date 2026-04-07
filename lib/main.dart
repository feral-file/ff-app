import 'dart:io';

import 'package:app/app/bootstrap/app_bootstrap.dart';
import 'package:app/infra/config/app_config.dart';
import 'package:app/infra/logging/app_logger.dart';
import 'package:app/infra/logging/structured_logger.dart';
import 'package:app/infra/services/seed_database_service.dart';
import 'package:dio/dio.dart';
import 'package:drift/drift.dart' hide Column;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:sentry_logging/sentry_logging.dart';

final StructuredLogger _startupLog = AppStructuredLog.forLogger(
  Logger('MainBootstrap'),
  context: {'layer': 'startup'},
);

Future<void> main() async {
  // Ensure Flutter bindings are initialized
  WidgetsFlutterBinding.ensureInitialized();

  // [database_service_provider] intentionally opens a second in-memory
  // [AppDatabase] while the seed database is not ready, alongside the
  // on-disk instance. Drift warns on multiple [AppDatabase] instances by
  // default; that pattern is expected here.
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

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
            if (kDebugMode) return null;
            if (_dropExpectedSeedOrConnectivityNoise(event)) {
              return null;
            }
            return event;
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

/// Drops Sentry events for handled seed-download failures and common offline
/// DNS noise (issues #167, #177, #211).
bool _dropExpectedSeedOrConnectivityNoise(SentryEvent event) {
  return _dropThrowableChain(event.throwable);
}

bool _dropThrowableChain(Object? t) {
  if (t == null) return false;
  if (t is SeedDownloadException) return true;
  if (t is SocketException) {
    final m = t.message.toLowerCase();
    return m.contains('failed host lookup') ||
        m.contains('no address associated');
  }
  if (t is DioException) {
    return _dropThrowableChain(t.error);
  }
  return false;
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

  final bootstrap = await bootstrapAppDependencies();

  await attachPostOnboardingSentryContext(
    hasDoneOnboarding:
        bootstrap.hasDoneOnboarding || bootstrap.hasLegacySqliteDatabase,
    appStateService: bootstrap.appStateService,
    bluetoothDeviceService: bootstrap.bluetoothDeviceService,
  );

  runApp(buildBootstrapApp(bootstrap: bootstrap));
}
