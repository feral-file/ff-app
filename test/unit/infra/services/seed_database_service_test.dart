import 'package:app/infra/services/seed_database_service.dart';
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
}
