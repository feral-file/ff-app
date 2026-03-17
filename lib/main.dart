import 'package:app/app/bootstrap/app_bootstrap.dart';
import 'package:app/infra/config/app_config.dart';
import 'package:app/infra/logging/app_logger.dart';
import 'package:app/infra/logging/structured_logger.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:sentry_logging/sentry_logging.dart';

final StructuredLogger _startupLog = AppStructuredLog.forLogger(
  Logger('MainBootstrap'),
  context: {'layer': 'startup'},
);

/// Checks if a Sentry event is a transient seed sync network error.
///
/// Seed database sync uses failSilently=true on app resume to gracefully
/// handle transient connectivity issues. SocketException and DioException
/// errors are expected and handled, but sentry_dio still captures them as
/// error events. This filter prevents them from cluttering the dashboard.
bool _isSeedSyncNetworkError(SentryEvent event) {
  final exceptions = event.exceptions;
  if (exceptions == null || exceptions.isEmpty) return false;

  final exception = exceptions.first;

  // Check exception type: filter SocketException and DioException.
  final exceptionType = exception.type;
  if (exceptionType != 'SocketException' && exceptionType != 'DioException') {
    return false;
  }

  // Check if this event is from seed_database component (stack trace).
  final stackTrace = exception.stackTrace;
  if (stackTrace == null) return false;

  final frames = stackTrace.frames;
  if (frames.isEmpty) return false;

  return frames.any(
    (frame) =>
        (frame.fileName?.contains('seed_database') ?? false) ||
        (frame.function?.contains('seed_database') ?? false),
  );
}

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
            // In debug mode, suppress all events for cleaner logs.
            if (kDebugMode) return null;

            // Filter out transient seed sync network errors.
            // These are expected network issues, not bugs. Keep FormatException
            // and other persistence failures visible for debugging.
            if (_isSeedSyncNetworkError(event)) {
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
