import 'dart:io';

import 'package:app/infra/services/seed_database_artifact_validator.dart';
import 'package:app/infra/services/seed_database_service.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import '../../../helpers/seed_database_test_helper.dart';

/// Fails staging after validation so the live DB must not be deleted (#337).
class _ThrowingMaterializeSeedService extends SeedDatabaseService {
  _ThrowingMaterializeSeedService({
    required this.dbPath,
    required Future<Directory> Function() tempDirProvider,
  }) : super(temporaryDirectoryProvider: tempDirProvider);

  final String dbPath;

  @override
  Future<String> databasePath() async => dbPath;

  @override
  Future<void> materializeValidatedArtifactInDatabaseDirectory({
    required String sourcePath,
    required String stagingPath,
  }) async {
    throw Exception('Simulated materialize failure');
  }
}

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
            requestOptions: RequestOptions(
              path: 'https://example.invalid/seed.db',
            ),
            type: DioExceptionType.cancel,
            message: 'seed_download_stall: no progress for 120s',
          ),
        ),
        isTrue,
      );
    });
  });

  group('SeedDatabaseService recoverable replace', () {
    test(
      'failure before main DB is backed up leaves canonical database readable',
      () async {
        final tempDir = await Directory.systemTemp.createTemp(
          'ff_seed_replace_recover_',
        );
        addTearDown(() async {
          if (tempDir.existsSync()) {
            await tempDir.delete(recursive: true);
          }
        });

        final dbPath = p.join(tempDir.path, 'dp1_library.sqlite');
        createSeedArtifactDatabase(file: File(dbPath));

        final incoming = File(p.join(tempDir.path, 'incoming.sqlite'));
        createSeedArtifactDatabase(file: incoming);

        final svc = _ThrowingMaterializeSeedService(
          dbPath: dbPath,
          tempDirProvider: () async => tempDir,
        );

        await expectLater(
          svc.replaceDatabaseFromTemporaryFile(incoming.path),
          throwsException,
        );

        expect(File(dbPath).existsSync(), isTrue);
        const validator = SeedDatabaseArtifactValidator();
        expect(() => validator.validate(dbPath), returnsNormally);
      },
    );

    test(
      'startup repair clears stale reset marker and completes interrupted swap',
      () async {
        final tempDir = await Directory.systemTemp.createTemp(
          'ff_seed_reset_marker_',
        );
        addTearDown(() async {
          if (tempDir.existsSync()) {
            await tempDir.delete(recursive: true);
          }
        });

        final dbPath = p.join(tempDir.path, 'dp1_library.sqlite');
        final marker = File('$dbPath.reset_in_progress');
        final stage = File(p.join(tempDir.path, 'dp1_library.sqlite.stage.9'));
        createSeedArtifactDatabase(file: stage);
        await marker.writeAsString('1');
        await File('$dbPath.swap_in_progress').writeAsString('9');

        final svc = _ThrowingMaterializeSeedService(
          dbPath: dbPath,
          tempDirProvider: () async => tempDir,
        );

        expect(await svc.repairInterruptedSeedSwapIfNeeded(), isTrue);
        expect(File(dbPath).existsSync(), isTrue);
        expect(stage.existsSync(), isFalse);
        expect(marker.existsSync(), isFalse);
      },
    );

    test(
      'startup repair preserves reset marker when no swap marker exists',
      () async {
        final tempDir = await Directory.systemTemp.createTemp(
          'ff_seed_stale_reset_marker_',
        );
        addTearDown(() async {
          if (tempDir.existsSync()) {
            await tempDir.delete(recursive: true);
          }
        });

        final dbPath = p.join(tempDir.path, 'dp1_library.sqlite');
        final marker = File('$dbPath.reset_in_progress');
        await marker.writeAsString('1');

        final svc = _ThrowingMaterializeSeedService(
          dbPath: dbPath,
          tempDirProvider: () async => tempDir,
        );

        expect(await svc.repairInterruptedSeedSwapIfNeeded(), isFalse);
        expect(marker.existsSync(), isTrue);
      },
    );

    test(
      'startup repair prefers the newest artifact even when backup is newer '
      'than stage',
      () async {
        final tempDir = await Directory.systemTemp.createTemp(
          'ff_seed_mixed_artifacts_',
        );
        addTearDown(() async {
          if (tempDir.existsSync()) {
            await tempDir.delete(recursive: true);
          }
        });

        final dbPath = p.join(tempDir.path, 'dp1_library.sqlite');
        final olderStage = File(
          p.join(tempDir.path, 'dp1_library.sqlite.stage.100'),
        );
        final newerBackup = File(
          p.join(tempDir.path, 'dp1_library.sqlite.backup.200'),
        );
        createSeedArtifactDatabase(file: olderStage);
        createSeedArtifactDatabase(file: newerBackup);
        await File('$dbPath.swap_in_progress').writeAsString('200');

        final svc = _ThrowingMaterializeSeedService(
          dbPath: dbPath,
          tempDirProvider: () async => tempDir,
        );

        final repaired = await svc.repairInterruptedSeedSwapIfNeeded();

        expect(repaired, isTrue);
        expect(File(dbPath).existsSync(), isTrue);
        expect(olderStage.existsSync(), isFalse);
        expect(newerBackup.existsSync(), isFalse);
      },
    );
  });
}
