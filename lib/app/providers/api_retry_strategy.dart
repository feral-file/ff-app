import 'package:dio/dio.dart';

/// Custom retry strategy for API providers.
/// 
/// Following Riverpod automatic retry guide:
/// https://riverpod.dev/docs/concepts2/retry
/// 
/// This strategy:
/// - Retries network errors (DioException with connection issues)
/// - Does NOT retry client errors (4xx status codes)
/// - Does NOT retry Errors (bugs in code)
/// - Uses exponential backoff (200ms, 400ms, 800ms, 1.6s, 3.2s)
/// - Max 5 retries (total 6 attempts)
Duration? apiRetryStrategy(int retryCount, Object error) {
  // Stop after 5 retries
  if (retryCount >= 5) return null;

  // Don't retry Errors (bugs in code)
  if (error is Error) return null;

  // Handle DioException
  if (error is DioException) {
    // Don't retry client errors (400-499)
    if (error.response?.statusCode != null) {
      final statusCode = error.response!.statusCode!;
      if (statusCode >= 400 && statusCode < 500) {
        // Client errors shouldn't be retried (bad request, unauthorized, etc)
        return null;
      }
    }

    // Retry these connection issues with exponential backoff
    final shouldRetry = error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.sendTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.connectionError ||
        error.type == DioExceptionType.badResponse && 
            (error.response?.statusCode ?? 0) >= 500;

    if (shouldRetry) {
      // Exponential backoff: 200ms, 400ms, 800ms, 1600ms, 3200ms
      return Duration(milliseconds: 200 * (1 << retryCount));
    }
  }

  // Don't retry other errors
  return null;
}

/// Aggressive retry strategy for critical operations.
/// Uses more retries with longer delays.
Duration? aggressiveApiRetry(int retryCount, Object error) {
  // Stop after 10 retries
  if (retryCount >= 10) return null;

  // Don't retry Errors (bugs in code)
  if (error is Error) return null;

  // Handle DioException
  if (error is DioException) {
    // Don't retry client errors (400-499)
    if (error.response?.statusCode != null) {
      final statusCode = error.response!.statusCode!;
      if (statusCode >= 400 && statusCode < 500) {
        return null;
      }
    }

    // Retry connection issues
    final shouldRetry = error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.sendTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.connectionError ||
        error.type == DioExceptionType.badResponse && 
            (error.response?.statusCode ?? 0) >= 500;

    if (shouldRetry) {
      // Exponential backoff with cap at 10 seconds
      final delay = 200 * (1 << retryCount);
      return Duration(milliseconds: delay.clamp(200, 10000));
    }
  }

  return null;
}
