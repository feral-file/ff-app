import 'package:app/infra/services/seed_database_service.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SeedDatabaseService object URI parsing', () {
    test('builds object URI from bucket URL and object key', () {
      final objectUri = SeedDatabaseService.parseObjectUriForTesting(
        bucketUrl:
            'https://example.r2.cloudflarestorage.com/ff-app-db-snapshot',
        objectKey: 'nested/ff_feed_indexer_seed.sqlite',
      );

      expect(
        objectUri.toString(),
        'https://example.r2.cloudflarestorage.com/ff-app-db-snapshot/nested/ff_feed_indexer_seed.sqlite',
      );
    });

    test('throws when bucket URL is missing bucket path', () {
      expect(
        () => SeedDatabaseService.parseObjectUriForTesting(
          bucketUrl: 'https://example.r2.cloudflarestorage.com',
          objectKey: 'ff_feed_indexer_seed.sqlite',
        ),
        throwsFormatException,
      );
    });
  });

  group('SeedDatabaseService signing', () {
    test('buildSignedHeadersForTesting returns SigV4 headers', () {
      final headers = SeedDatabaseService.buildSignedHeadersForTesting(
        method: 'HEAD',
        uri: Uri.parse(
          'https://example.r2.cloudflarestorage.com/ff-app-db-snapshot/ff_feed_indexer_seed.sqlite',
        ),
        accessKeyId: 'access-key',
        secretAccessKey: 'secret-key',
        region: 'auto',
        nowUtc: DateTime.utc(2026, 2, 27, 12),
      );

      expect(headers['x-amz-date'], '20260227T120000Z');
      expect(headers['x-amz-content-sha256'], 'UNSIGNED-PAYLOAD');
      expect(headers['authorization'], startsWith('AWS4-HMAC-SHA256 '));
      expect(
        headers['authorization'],
        contains('Credential=access-key/20260227/auto/s3/aws4_request'),
      );
      expect(
        headers['authorization'],
        contains('SignedHeaders=host;x-amz-content-sha256;x-amz-date'),
      );
    });
  });

  group('SeedDatabaseService retryable download errors', () {
    DioException dioException({
      required DioExceptionType type,
      int? statusCode,
    }) {
      return DioException(
        requestOptions: RequestOptions(path: 'https://example.invalid/seed.db'),
        type: type,
        response: statusCode == null
            ? null
            : Response<void>(
                requestOptions: RequestOptions(
                  path: 'https://example.invalid/seed.db',
                ),
                statusCode: statusCode,
              ),
      );
    }

    test('retries on timeout and connectivity failures', () {
      expect(
        SeedDatabaseService.isRetryableDownloadError(
          dioException(type: DioExceptionType.connectionTimeout),
        ),
        isTrue,
      );
      expect(
        SeedDatabaseService.isRetryableDownloadError(
          dioException(type: DioExceptionType.connectionError),
        ),
        isTrue,
      );
      expect(
        SeedDatabaseService.isRetryableDownloadError(
          dioException(type: DioExceptionType.receiveTimeout),
        ),
        isTrue,
      );
    });

    test('retries on retry-friendly HTTP status codes', () {
      expect(
        SeedDatabaseService.isRetryableDownloadError(
          dioException(type: DioExceptionType.badResponse, statusCode: 429),
        ),
        isTrue,
      );
      expect(
        SeedDatabaseService.isRetryableDownloadError(
          dioException(type: DioExceptionType.badResponse, statusCode: 504),
        ),
        isTrue,
      );
    });

    test('does not retry on non-retryable HTTP status codes', () {
      expect(
        SeedDatabaseService.isRetryableDownloadError(
          dioException(type: DioExceptionType.badResponse, statusCode: 400),
        ),
        isFalse,
      );
      expect(
        SeedDatabaseService.isRetryableDownloadError(
          dioException(type: DioExceptionType.badResponse, statusCode: 404),
        ),
        isFalse,
      );
    });

    test('does not retry cancellations', () {
      expect(
        SeedDatabaseService.isRetryableDownloadError(
          dioException(type: DioExceptionType.cancel),
        ),
        isFalse,
      );
    });

    test('retries stall watchdog cancellations', () {
      expect(
        SeedDatabaseService.isRetryableDownloadError(
          DioException(
            requestOptions: RequestOptions(path: 'https://example.invalid/seed.db'),
            type: DioExceptionType.cancel,
            message: 'seed_download_stall: no progress for 120s',
          ),
        ),
        isTrue,
      );
    });
  });
}
