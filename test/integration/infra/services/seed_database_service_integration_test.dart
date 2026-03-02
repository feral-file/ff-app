import 'dart:io';

import 'package:app/infra/config/app_config.dart';
import 'package:app/infra/services/seed_database_service.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/integration_test_harness.dart';

const String _kS3BucketEnvKey = 'S3_BUCKET';
const String _kS3SeedObjectKey = 'S3_SEED_DATABASE_OBJECT_KEY';
const String _kS3AccessKeyId = 'S3_ACCESS_KEY_ID';
const String _kS3SecretAccessKey = 'S3_SECRET_ACCESS_KEY';
const String _kS3Region = 'S3_REGION';

bool _isS3BucketConfigValid() {
  final envFile = File('.env');
  if (!envFile.existsSync()) {
    return false;
  }

  final values = <String, String>{};
  for (final line in envFile.readAsLinesSync()) {
    final trimmed = line.trim();
    if (trimmed.isEmpty || trimmed.startsWith('#')) {
      continue;
    }

    final separatorIndex = trimmed.indexOf('=');
    if (separatorIndex <= 0) {
      continue;
    }

    final key = trimmed.substring(0, separatorIndex).trim();
    final value = trimmed
        .substring(separatorIndex + 1)
        .trim()
        .replaceAll(RegExp(r'^"|"$'), '')
        .replaceAll(RegExp(r"^'|'$"), '');

    values[key] = value;
  }

  final bucketUrl = values[_kS3BucketEnvKey] ?? '';
  final accessKey = values[_kS3AccessKeyId] ?? '';
  final secretKey = values[_kS3SecretAccessKey] ?? '';
  final objectKey = values[_kS3SeedObjectKey] ?? 'ff_feed_indexer_seed.sqlite';
  final region = (values[_kS3Region] ?? 'auto').trim();

  final uri = Uri.tryParse(bucketUrl);
  final hasBucketName =
      uri != null &&
      uri.hasScheme &&
      uri.host.isNotEmpty &&
      uri.pathSegments.isNotEmpty;
  if (!hasBucketName) {
    return false;
  }

  return accessKey.trim().isNotEmpty &&
      secretKey.trim().isNotEmpty &&
      region.trim().isNotEmpty &&
      objectKey.trim().isNotEmpty;
}

final bool _skipSeedS3IntegrationTests = !_isS3BucketConfigValid();
const String _seedS3SkipReason =
    'S3 seed integration is disabled because S3_BUCKET env settings are invalid. '
    'Set S3_BUCKET (must be a valid URL with a bucket path), '
    'S3_ACCESS_KEY_ID, S3_SECRET_ACCESS_KEY, and S3_SEED_DATABASE_OBJECT_KEY.';

void main() {
  group('SeedDatabaseService S3 integration', () {
    late File provisionedEnvFile;

    setUpAll(() async {
      if (_skipSeedS3IntegrationTests) return;
      provisionedEnvFile = await provisionIntegrationEnvFile();
    });

    tearDownAll(() async {
      if (_skipSeedS3IntegrationTests) return;
      final parent = provisionedEnvFile.parent;
      if (parent.existsSync()) {
        await parent.delete(recursive: true);
      }
    });

    test(
      'headRemoteEtag returns latest remote ETag from S3 API',
      skip: _skipSeedS3IntegrationTests ? _seedS3SkipReason : null,
      () async {
        final service = SeedDatabaseService();

        final etag = await service.headRemoteEtag();

        expect(etag, isNotEmpty);
      },
    );

    test(
      'downloadToTemporaryFile downloads seed artifact from S3 API',
      skip: _skipSeedS3IntegrationTests ? _seedS3SkipReason : null,
      () async {
        final tempDir = await Directory.systemTemp.createTemp(
          'ff_app_seed_dl_',
        );
        addTearDown(() async {
          if (tempDir.existsSync()) {
            await tempDir.delete(recursive: true);
          }
        });
        final service = SeedDatabaseService(
          temporaryDirectoryProvider: () async => tempDir,
        );

        final tempPath = await service.downloadToTemporaryFile(maxBytes: 4096);
        addTearDown(() async {
          final file = File(tempPath);
          if (file.existsSync()) {
            await file.delete();
          }
        });

        final downloaded = File(tempPath);
        expect(downloaded.existsSync(), isTrue);
        final fileSize = await downloaded.length();
        expect(fileSize, greaterThan(0));
        expect(fileSize, lessThanOrEqualTo(4096));
        expect(AppConfig.s3AccessKeyId, isNotEmpty);
      },
    );
  });
}
