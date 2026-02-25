import 'package:app/app/providers/api_retry_strategy.dart';
import 'package:app/infra/config/app_config.dart';
import 'package:app/infra/database/app_database.dart';
import 'package:app/infra/database/database_provider.dart';
import 'package:app/infra/database/database_service.dart';
import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Tests for Riverpod automatic retry functionality.
///
/// Following: https://riverpod.dev/docs/concepts2/retry
void main() {
  setUpAll(() async {
    await AppConfig.initialize();
  });

  group('API Retry Strategy', () {
    test('retries network timeout errors', () {
      final error = DioException(
        requestOptions: RequestOptions(path: '/test'),
        type: DioExceptionType.connectionTimeout,
      );

      // Should retry with exponential backoff
      expect(
        apiRetryStrategy(0, error),
        equals(const Duration(milliseconds: 200)),
      );
      expect(
        apiRetryStrategy(1, error),
        equals(const Duration(milliseconds: 400)),
      );
      expect(
        apiRetryStrategy(2, error),
        equals(const Duration(milliseconds: 800)),
      );
      expect(
        apiRetryStrategy(3, error),
        equals(const Duration(milliseconds: 1600)),
      );
      expect(
        apiRetryStrategy(4, error),
        equals(const Duration(milliseconds: 3200)),
      );

      // Stops after 5 retries
      expect(apiRetryStrategy(5, error), isNull);
    });

    test('does not retry client errors (4xx)', () {
      final error = DioException(
        requestOptions: RequestOptions(path: '/test'),
        type: DioExceptionType.badResponse,
        response: Response(
          requestOptions: RequestOptions(path: '/test'),
          statusCode: 404,
        ),
      );

      // Should not retry 4xx errors
      expect(apiRetryStrategy(0, error), isNull);
      expect(apiRetryStrategy(1, error), isNull);
    });

    test('retries server errors (5xx)', () {
      final error = DioException(
        requestOptions: RequestOptions(path: '/test'),
        type: DioExceptionType.badResponse,
        response: Response(
          requestOptions: RequestOptions(path: '/test'),
          statusCode: 500,
        ),
      );

      // Should retry 5xx errors
      expect(
        apiRetryStrategy(0, error),
        equals(const Duration(milliseconds: 200)),
      );
      expect(
        apiRetryStrategy(1, error),
        equals(const Duration(milliseconds: 400)),
      );
    });

    test('does not retry Errors (bugs)', () {
      final error = StateError('Bug in code');

      // Should not retry Errors
      expect(apiRetryStrategy(0, error), isNull);
      expect(apiRetryStrategy(1, error), isNull);
    });

    test('retries connection errors', () {
      final error = DioException(
        requestOptions: RequestOptions(path: '/test'),
        type: DioExceptionType.connectionError,
      );

      // Should retry connection errors
      expect(
        apiRetryStrategy(0, error),
        equals(const Duration(milliseconds: 200)),
      );
    });

    test('aggressive retry has more attempts', () {
      final error = DioException(
        requestOptions: RequestOptions(path: '/test'),
        type: DioExceptionType.connectionTimeout,
      );

      // Should retry up to 10 times
      for (var i = 0; i < 10; i++) {
        expect(
          aggressiveApiRetry(i, error),
          isNotNull,
          reason: 'Should retry attempt $i',
        );
      }

      // Stops after 10 retries
      expect(aggressiveApiRetry(10, error), isNull);
    });

    test('aggressive retry caps delay at 10 seconds', () {
      final error = DioException(
        requestOptions: RequestOptions(path: '/test'),
        type: DioExceptionType.connectionTimeout,
      );

      // Later retries should be capped at 10 seconds
      final laterRetry = aggressiveApiRetry(9, error);
      expect(laterRetry, isNotNull);
      expect(laterRetry!.inMilliseconds, lessThanOrEqualTo(10000));
    });
  });

  group('Retry Strategy Best Practices', () {
    test('custom retry strategy example', () {
      // Example: Only retry 3 times with fixed 1 second delay
      Duration? customRetry(int retryCount, Object error) {
        if (retryCount >= 3) return null;
        if (error is! DioException) return null;

        return const Duration(seconds: 1);
      }

      final error = DioException(
        requestOptions: RequestOptions(path: '/test'),
        type: DioExceptionType.connectionTimeout,
      );

      expect(customRetry(0, error), equals(const Duration(seconds: 1)));
      expect(customRetry(1, error), equals(const Duration(seconds: 1)));
      expect(customRetry(2, error), equals(const Duration(seconds: 1)));
      expect(customRetry(3, error), isNull);
    });
  });
}
