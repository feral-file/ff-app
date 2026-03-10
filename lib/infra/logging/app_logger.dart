import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';

/// Central logging fan-out for console and file persistence.
class AppLogger {
  AppLogger._();

  static const int _maxFileSizeBytes = 1024 * 1024;
  static const int _maxBufferedCharsBeforeFlush = 8 * 1024;
  static const Duration _flushInterval = Duration(seconds: 1);
  static const _logFileName = 'app.log';

  static bool _initialized = false;
  static StreamSubscription<LogRecord>? _rootSubscription;
  static StreamController<_QueuedLogLine>? _writeQueue;
  static Timer? _flushTimer;
  static File? _logFile;
  static final StringBuffer _pendingBuffer = StringBuffer();
  static bool _isFlushing = false;

  /// Initializes app logging once.
  static Future<void> initialize({Level rootLevel = Level.ALL}) async {
    if (_initialized) {
      return;
    }

    _writeQueue = StreamController<_QueuedLogLine>();
    _writeQueue!.stream.listen(
      _enqueueLogLine,
      onError: (Object error) {
        debugPrint('Log queue error: $error');
      },
    );
    _flushTimer = Timer.periodic(_flushInterval, (_) {
      unawaited(_flushPendingBuffer());
    });

    try {
      _logFile = await _createLogFile();
    } on Object catch (error, stackTrace) {
      debugPrint('Failed to initialize log file output: $error');
      debugPrintStack(stackTrace: stackTrace);
      _logFile = null;
    }
    Logger.root.level = rootLevel;
    _rootSubscription = Logger.root.onRecord.listen(_handleLogRecord);

    _initialized = true;
  }

  /// Disposes logging resources.
  static Future<void> dispose() async {
    await _rootSubscription?.cancel();
    _flushTimer?.cancel();
    await _flushPendingBuffer(force: true);
    await _writeQueue?.close();
    _rootSubscription = null;
    _writeQueue = null;
    _flushTimer = null;
    _initialized = false;
  }

  /// Current file used for persisted logs.
  static File? get currentLogFile => _logFile;

  static Future<File> _createLogFile() async {
    final directory = Directory.systemTemp;
    return File('${directory.path}/$_logFileName').create(recursive: true);
  }

  static void _handleLogRecord(LogRecord record) {
    final line = _formatRecord(record);
    _logToConsole(line);
    _writeQueue?.add(
      _QueuedLogLine(
        line: line,
        forceFlush: record.level >= Level.SEVERE,
      ),
    );
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

  static Future<void> _enqueueLogLine(_QueuedLogLine queuedLine) async {
    _pendingBuffer.write(queuedLine.line);
    if (queuedLine.forceFlush ||
        _pendingBuffer.length >= _maxBufferedCharsBeforeFlush) {
      await _flushPendingBuffer(force: true);
    }
  }

  static Future<void> _flushPendingBuffer({bool force = false}) async {
    if (_isFlushing) {
      if (force) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
        return _flushPendingBuffer(force: force);
      }
      return;
    }
    if (!force && _pendingBuffer.isEmpty) {
      return;
    }
    if (_pendingBuffer.isEmpty) {
      return;
    }

    final targetFile = _logFile;
    if (targetFile == null) {
      _pendingBuffer.clear();
      return;
    }

    final pendingText = _pendingBuffer.toString();
    _pendingBuffer.clear();

    _isFlushing = true;
    try {
      await _rotateIfNeeded(targetFile);
      await targetFile.writeAsString(
        pendingText,
        mode: FileMode.append,
        flush: force,
      );
    } on Object catch (error, stackTrace) {
      debugPrint('Failed to persist log line: $error');
      debugPrintStack(stackTrace: stackTrace);
      _logFile = null;
    } finally {
      _isFlushing = false;
    }
  }

  static Future<void> _rotateIfNeeded(File file) async {
    if (!file.existsSync()) {
      return;
    }

    final size = file.lengthSync();
    if (size < _maxFileSizeBytes) {
      return;
    }

    final directory = file.parent.path;
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final rotatedPath = '$directory/app_$timestamp.log';
    try {
      await file.rename(rotatedPath);
      _logFile = await _createLogFile();
    } on Object catch (error, stackTrace) {
      debugPrint('Failed to rotate log file: $error');
      debugPrintStack(stackTrace: stackTrace);
      _logFile = null;
    }
  }

  static String _redact(String text) {
    if (!text.contains('Authorization') &&
        !text.contains('eyJ') &&
        !text.contains('X-Api-Signature')) {
      return text;
    }

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

class _QueuedLogLine {
  _QueuedLogLine({
    required this.line,
    required this.forceFlush,
  });

  final String line;
  final bool forceFlush;
}
