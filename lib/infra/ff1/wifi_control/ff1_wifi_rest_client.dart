/// FF1 WiFi REST client for sending commands to device via Relayer.
library;

import 'dart:async';

import 'package:app/infra/logging/log_sanitizer.dart';
import 'package:app/infra/logging/structured_dio_logging_interceptor.dart';
import 'package:app/infra/logging/structured_logger.dart';
import 'package:dio/dio.dart';
import 'package:logging/logging.dart';
import 'package:sentry_dio/sentry_dio.dart';

/// REST client for communicating with FF1 devices through the Relayer API.
///
/// This client sends commands to FF1 devices via HTTP GET to the Relayer's
/// REST endpoint. Each command is sent to a specific device topic.
class FF1WifiRestClient {
  /// Create a new REST client.
  ///
  /// [castApiUrl] — base URL of the Relayer's cast API (e.g., `https://...`)
  /// [apiKey] — API key for authentication with the Relayer
  /// [logger] — optional logger for debugging
  FF1WifiRestClient({
    required String castApiUrl,
    required String apiKey,
    Logger? logger,
  }) : _castApiUrl = castApiUrl,
       _apiKey = apiKey,
       _dio = Dio()
         ..addSentry()
         ..interceptors.add(
           StructuredDioLoggingInterceptor(
             logger: logger ?? Logger('FF1WifiRestClient'),
             component: 'ff1_wifi_rest',
           ),
         ),
       _structuredLogger = AppStructuredLog.forLogger(
         logger ?? Logger('FF1WifiRestClient'),
       );

  final String _castApiUrl;
  final String _apiKey;
  final Dio _dio;
  final StructuredLogger _structuredLogger;

  /// Send a command to the device.
  ///
  /// [topicId] — device identifier on the relayer
  /// [command] — command name (e.g., 'rotate', 'pause', 'play')
  /// [params] — command-specific parameters
  /// [timeout] — request timeout (default 6 seconds)
  ///
  /// Returns the response from the device as a map.
  Future<Map<String, dynamic>> sendCommand({
    required String topicId,
    required String command,
    required Map<String, dynamic> params,
    Duration timeout = const Duration(seconds: 6),
  }) async {
    try {
      // Validate configuration
      if (_castApiUrl.isEmpty) {
        const msg =
            'FF1_RELAYER_URL not configured. Please set FF1_RELAYER_URL '
            'in .env file. Example: '
            'FF1_RELAYER_URL=https://tv-cast-coordination.autonomy-system.workers.dev';
        throw StateError(msg);
      }

      final url = '$_castApiUrl/api/cast';
      final body = {
        'command': command,
        'request': params,
      };

      _structuredLogger.info(
        category: LogCategory.domain,
        event: 'ff1_command_started',
        message: 'send command $command',
        payload: {
          'command': command,
          'topicId': topicId,
          'url': url,
          'request': LogSanitizer.sanitizeMap(params),
        },
      );

      final response = await _dio.get<dynamic>(
        url,
        queryParameters: {'topicID': topicId},
        data: body,
        options: Options(
          headers: {
            'API-KEY': _apiKey,
            'Content-Type': 'application/json',
          },
          connectTimeout: timeout,
          sendTimeout: timeout,
          receiveTimeout: timeout,
        ),
      );

      final responseData = response.data;

      // Handle various response formats
      if (responseData is Map<String, dynamic>) {
        return responseData;
      }

      if (responseData is Map) {
        final result = Map<String, dynamic>.from(responseData);
        return result;
      }

      _structuredLogger.warning(
        category: LogCategory.domain,
        event: 'ff1_command_unexpected_response',
        message: 'unexpected response type ${responseData.runtimeType}',
        payload: {
          'command': command,
          'topicId': topicId,
        },
      );
      return {};
    } on DioException catch (e) {
      _structuredLogger.error(
        event: 'ff1_command_failed',
        message: 'command $command failed',
        error: e,
        stackTrace: e.stackTrace,
        payload: {
          'command': command,
          'topicId': topicId,
          'error': LogSanitizer.sanitizeError(e),
        },
      );
      rethrow;
    } on Exception catch (e) {
      _structuredLogger.error(
        event: 'ff1_command_failed',
        message: 'command $command failed',
        error: e,
        payload: {
          'command': command,
          'topicId': topicId,
          'error': LogSanitizer.sanitizeError(e),
        },
      );
      rethrow;
    } catch (e) {
      _structuredLogger.error(
        event: 'ff1_command_failed',
        message: 'command $command failed',
        error: e,
        payload: {
          'command': command,
          'topicId': topicId,
          'error': LogSanitizer.sanitizeError(e),
        },
      );
      rethrow;
    }
  }

  /// Dispose of resources.
  void dispose() {
    _dio.close();
  }
}
