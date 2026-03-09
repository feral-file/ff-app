import 'package:app/infra/logging/log_sanitizer.dart';
import 'package:app/infra/logging/structured_log_context.dart';
import 'package:app/infra/logging/structured_logger.dart';
import 'package:dio/dio.dart';
import 'package:logging/logging.dart';

/// Lightweight Dio interceptor for structured request lifecycle logs.
class StructuredDioLoggingInterceptor extends Interceptor {
  StructuredDioLoggingInterceptor({
    required Logger logger,
    this.component,
  }) : _log = AppStructuredLog.forLogger(
         logger,
         context: {
           if (component != null && component!.isNotEmpty)
             'component': component,
         },
       );

  static const _startTimeKey = '_structuredLogStartMs';
  final StructuredLogger _log;
  final String? component;

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) {
    final start = DateTime.now().millisecondsSinceEpoch;
    options.extra[_startTimeKey] = start;

    _log.info(
      category: LogCategory.http,
      event: 'request_started',
      message: '${options.method.toUpperCase()} ${options.path} started',
      payload: {
        'method': options.method.toUpperCase(),
        'path': options.path,
        'query': LogSanitizer.sanitizeMap(
          options.queryParameters.map(
            (key, value) => MapEntry(key, value),
          ),
        ),
        'headers': LogSanitizer.sanitizeHeaders(options.headers),
        'body': LogSanitizer.sanitizeBody(options.data),
        'flowId': _resolveFlowId(options),
      },
    );

    handler.next(options);
  }

  @override
  void onResponse(
    Response<dynamic> response,
    ResponseInterceptorHandler handler,
  ) {
    final duration = _durationMs(response.requestOptions);
    _log.info(
      category: LogCategory.http,
      event: 'request_completed',
      message:
          '${response.requestOptions.method.toUpperCase()} '
          '${response.requestOptions.path} completed '
          'status=${response.statusCode} durationMs=$duration',
      payload: {
        'method': response.requestOptions.method.toUpperCase(),
        'path': response.requestOptions.path,
        'statusCode': response.statusCode,
        'durationMs': duration,
        'flowId': _resolveFlowId(response.requestOptions),
      },
    );
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final duration = _durationMs(err.requestOptions);
    _log.error(
      event: 'request_failed',
      message:
          '${err.requestOptions.method.toUpperCase()} '
          '${err.requestOptions.path} failed '
          'status=${err.response?.statusCode} durationMs=$duration',
      error: err,
      stackTrace: err.stackTrace,
      payload: {
        'method': err.requestOptions.method.toUpperCase(),
        'path': err.requestOptions.path,
        'statusCode': err.response?.statusCode,
        'durationMs': duration,
        'type': err.type.name,
        'error': LogSanitizer.sanitizeError(err),
        'flowId': _resolveFlowId(err.requestOptions),
      },
    );

    handler.next(err);
  }

  int _durationMs(RequestOptions options) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final start = options.extra[_startTimeKey];
    if (start is int) {
      return now - start;
    }
    return 0;
  }

  String? _resolveFlowId(RequestOptions options) {
    final requestFlowId = options.extra['flowId'];
    if (requestFlowId is String && requestFlowId.isNotEmpty) {
      return requestFlowId;
    }
    return StructuredLogContext.flowId;
  }
}
