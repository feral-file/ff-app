import 'dart:async';
import 'dart:convert';

import 'package:app/infra/logging/log_sanitizer.dart';
import 'package:app/infra/logging/structured_log_context.dart';
import 'package:logging/logging.dart';

/// Supported structured log categories.
enum LogCategory {
  /// User interaction events.
  ui,

  /// Navigation and route transition events.
  route,

  /// HTTP request lifecycle events.
  http,

  /// GraphQL operation lifecycle events.
  graphql,

  /// BLE transport and lifecycle events.
  ble,

  /// Domain/service events.
  domain,

  /// Error events.
  error,
}

/// Lightweight structured logger facade on top of [package:logging].
class StructuredLogger {
  /// Creates a logger wrapper with optional default context metadata.
  StructuredLogger(this._logger, {Map<String, dynamic> context = const {}})
    : _context = Map<String, dynamic>.from(context);

  final Logger _logger;
  final Map<String, dynamic> _context;

  /// Returns a new logger with merged context metadata.
  StructuredLogger withContext(Map<String, dynamic> values) {
    return StructuredLogger(
      _logger,
      context: {
        ..._context,
        ...values,
      },
    );
  }

  /// Emits an INFO log entry with structured metadata.
  void info({
    required LogCategory category,
    required String event,
    required String message,
    Map<String, dynamic>? payload,
    String? entityId,
    String? flowId,
  }) {
    _emit(
      level: Level.INFO,
      category: category,
      event: event,
      message: message,
      payload: payload,
      entityId: entityId,
      flowId: flowId,
    );
  }

  /// Emits a WARNING log entry with structured metadata.
  void warning({
    required LogCategory category,
    required String event,
    required String message,
    Map<String, dynamic>? payload,
    String? entityId,
    String? flowId,
    Object? error,
    StackTrace? stackTrace,
  }) {
    _emit(
      level: Level.WARNING,
      category: category,
      event: event,
      message: message,
      payload: payload,
      entityId: entityId,
      flowId: flowId,
      error: error,
      stackTrace: stackTrace,
    );
  }

  /// Emits a SEVERE error entry with structured metadata.
  void error({
    required String event,
    required String message,
    Object? error,
    StackTrace? stackTrace,
    Map<String, dynamic>? payload,
    String? entityId,
    String? flowId,
  }) {
    final effectiveFlowId =
        flowId ??
        StructuredLogContext.flowId ??
        StructuredLogContext.recentFlowId;
    _emit(
      level: Level.SEVERE,
      category: LogCategory.error,
      event: event,
      message: message,
      payload: payload,
      entityId: entityId,
      flowId: effectiveFlowId,
      error: error,
      stackTrace: stackTrace,
    );
  }

  void _emit({
    required Level level,
    required LogCategory category,
    required String event,
    required String message,
    Map<String, dynamic>? payload,
    String? entityId,
    String? flowId,
    Object? error,
    StackTrace? stackTrace,
  }) {
    final now = DateTime.now().toUtc();
    final metadata = <String, dynamic>{
      'timestamp': now.toIso8601String(),
      'category': category.name,
      'event': event,
      'route': StructuredLogContext.currentRoute,
      'sessionId': StructuredLogContext.sessionId,
      if (flowId ?? StructuredLogContext.flowId case final String id)
        'flowId': id,
      if (StructuredLogContext.uiAction case final String action)
        'uiAction': action,
      if (entityId != null && entityId.isNotEmpty) 'entityId': entityId,
      ..._context,
      if (payload != null && payload.isNotEmpty)
        'payload': LogSanitizer.sanitizeMap(payload),
    };

    final line = '[${category.name}] $message | meta=${jsonEncode(metadata)}';
    _logger.log(level, line, error, stackTrace);
  }
}

/// Developer ergonomics helpers.
class AppStructuredLog {
  AppStructuredLog._();

  /// Wraps an existing [Logger] with structured logging behavior.
  static StructuredLogger forLogger(
    Logger logger, {
    Map<String, dynamic> context = const {},
  }) {
    return StructuredLogger(logger, context: context);
  }

  /// Convenience helper for standard UI action logs.
  static void logUiAction({
    required Logger logger,
    required String action,
    Map<String, dynamic> payload = const {},
    String? entityId,
  }) {
    forLogger(logger).info(
      category: LogCategory.ui,
      event: 'ui_action',
      message: 'tapped $action',
      payload: {
        'action': action,
        ...payload,
      },
      entityId: entityId,
    );
  }

  /// Convenience helper for domain-level event logs.
  static void logDomainEvent({
    required Logger logger,
    required String event,
    required String message,
    Map<String, dynamic> payload = const {},
    String? entityId,
  }) {
    forLogger(logger).info(
      category: LogCategory.domain,
      event: event,
      message: message,
      payload: payload,
      entityId: entityId,
    );
  }

  /// Runs an async flow while logging start/completion/failure events.
  static Future<T> runLoggedFlow<T>({
    required Logger logger,
    required String flowName,
    required Future<T> Function() action,
    Map<String, dynamic> payload = const {},
    String? flowId,
  }) async {
    final structuredLogger = forLogger(logger);
    final id = flowId ?? StructuredLogContext.createFlowId();
    structuredLogger.info(
      category: LogCategory.ui,
      event: 'flow_started',
      message: 'flow $flowName started',
      payload: {
        'flowName': flowName,
        ...payload,
      },
      flowId: id,
    );

    final stopwatch = Stopwatch()..start();
    try {
      final result = await StructuredLogContext.runFlow(
        flowId: id,
        action: action,
      );
      structuredLogger.info(
        category: LogCategory.ui,
        event: 'flow_completed',
        message: 'flow $flowName completed',
        payload: {
          'flowName': flowName,
          'durationMs': stopwatch.elapsedMilliseconds,
        },
        flowId: id,
      );
      return result;
    } catch (error, stackTrace) {
      structuredLogger.error(
        event: 'flow_failed',
        message: 'flow $flowName failed',
        error: error,
        stackTrace: stackTrace,
        payload: {
          'flowName': flowName,
          'durationMs': stopwatch.elapsedMilliseconds,
        },
        flowId: id,
      );
      rethrow;
    }
  }
}
