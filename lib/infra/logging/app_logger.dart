import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';
import 'package:path_provider/path_provider.dart';

/// Central logging fan-out for console, OS logger, and file persistence.
class AppLogger {
  AppLogger._();

  static const int _maxFileSizeBytes = 1024 * 1024;
  static const _logFileName = 'app.log';

  static bool _initialized = false;
  static StreamSubscription<LogRecord>? _rootSubscription;
  static StreamController<String>? _writeQueue;
  static File? _logFile;

  /// Initializes app logging once.
  static Future<void> initialize({Level rootLevel = Level.ALL}) async {
    if (_initialized) {
      return;
    }

    _writeQueue = StreamController<String>();
    _writeQueue!.stream.listen(
      _writeLogLine,
      onError: (Object error) {
        debugPrint('Log queue error: $error');
      },
    );

    _logFile = await _createLogFile();
    Logger.root.level = rootLevel;
    _rootSubscription = Logger.root.onRecord.listen(_handleLogRecord);

    _initialized = true;
  }

  /// Disposes logging resources.
  static Future<void> dispose() async {
    await _rootSubscription?.cancel();
    await _writeQueue?.close();
    _rootSubscription = null;
    _writeQueue = null;
    _initialized = false;
  }

  /// Current file used for persisted logs.
  static File? get currentLogFile => _logFile;

  static Future<File> _createLogFile() async {
    final directory = await getTemporaryDirectory();
    return File('${directory.path}/$_logFileName').create(recursive: true);
  }

  static void _handleLogRecord(LogRecord record) {
    final line = _formatRecord(record);
    _logToConsole(line);
    _logToOs(record);
    _writeQueue?.add(line);
  }

  static String _formatRecord(LogRecord record) {
    final redactedMessage = _redact(record.message);
    final buffer = StringBuffer()
      ..write('${record.time.toIso8601String()} ')
      ..write('[${record.level.name}] ')
      ..write('${record.loggerName}: ')
      ..writeln(redactedMessage);

    if (record.error != null) {
      buffer.writeln('error=${_redact(record.error.toString())}');
    }
    if (record.stackTrace != null) {
      buffer.writeln(record.stackTrace);
    }

    return buffer.toString();
  }

  static void _logToConsole(String message) {
    debugPrint(message.trimRight());
  }

  static void _logToOs(LogRecord record) {
    developer.log(
      _redact(record.message),
      time: record.time,
      level: record.level.value,
      name: record.loggerName,
      error: record.error,
      stackTrace: record.stackTrace,
    );
  }

  static Future<void> _writeLogLine(String line) async {
    final targetFile = _logFile;
    if (targetFile == null) {
      return;
    }

    await _rotateIfNeeded(targetFile);
    await _logFile?.writeAsString(line, mode: FileMode.append, flush: true);
  }

  static Future<void> _rotateIfNeeded(File file) async {
    final size = file.lengthSync();
    if (size < _maxFileSizeBytes) {
      return;
    }

    final directory = file.parent.path;
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final rotatedPath = '$directory/app_$timestamp.log';
    await file.rename(rotatedPath);
    _logFile = await _createLogFile();
  }

  static String _redact(String text) {
    var result = text;

    result = result.replaceAllMapped(
      RegExp(r'Authorization:\s*Bearer\s+[A-Za-z0-9\-._~+/]+=*'),
      (_) => 'Authorization: Bearer REDACTED_AUTH_TOKEN',
    );

    result = result.replaceAllMapped(
      RegExp(r'eyJ[A-Za-z0-9-_]+\.[A-Za-z0-9-_]+\.[A-Za-z0-9-_.+/=]*'),
      (_) => 'REDACTED_JWT_TOKEN',
    );

    result = result.replaceAllMapped(
      RegExp(r'X-Api-Signature:\s*[^\s,]+'),
      (_) => 'X-Api-Signature: REDACTED_X_API_SIGNATURE',
    );

    return result;
  }
}
