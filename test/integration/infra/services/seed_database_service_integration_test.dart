import 'dart:io';

import 'package:app/infra/config/app_config.dart';
import 'package:app/infra/services/seed_database_service.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/integration_test_harness.dart';

void main() {
  group('SeedDatabaseService S3 integration', () {
    late File provisionedEnvFile;

    setUpAll(() async {
      provisionedEnvFile = await provisionIntegrationEnvFile();
    });

    tearDownAll(() async {
      final parent = provisionedEnvFile.parent;
      if (parent.existsSync()) {
        await parent.delete(recursive: true);
      }
    });

    test('headRemoteEtag returns latest remote ETag from S3 API', () async {
      final service = SeedDatabaseService();

      final etag = await service.headRemoteEtag();

      expect(etag, isNotEmpty);
    });

    test(
      'downloadToTemporaryFile downloads seed artifact from S3 API',
      () async {
      final tempDir = await Directory.systemTemp.createTemp('ff_app_seed_dl_');
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
