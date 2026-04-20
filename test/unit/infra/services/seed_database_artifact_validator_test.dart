import 'dart:io';

import 'package:app/infra/services/seed_database_artifact_validator.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import '../../../helpers/seed_database_test_helper.dart';

void main() {
  group('SeedDatabaseArtifactValidator', () {
    late Directory tempDir;
    late SeedDatabaseArtifactValidator validator;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('ff_seed_validator_');
      validator = const SeedDatabaseArtifactValidator();
    });

    tearDown(() async {
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('rejects missing files', () {
      final missingPath = p.join(tempDir.path, 'missing.sqlite');

      expect(
        () => validator.validate(missingPath),
        throwsA(
          isA<SeedArtifactValidationException>().having(
            (e) => e.reasonCode,
            'reasonCode',
            'missing',
          ),
        ),
      );
    });

    test('rejects random bytes', () async {
      final file = File(p.join(tempDir.path, 'random.sqlite'));
      await file.writeAsBytes(List<int>.filled(1024, 7));

      expect(
        () => validator.validate(file.path),
        throwsA(
          isA<SeedArtifactValidationException>().having(
            (e) => e.reasonCode,
            'reasonCode',
            'magic_mismatch',
          ),
        ),
      );
    });

    test('rejects files smaller than one SQLite page', () async {
      final file = File(p.join(tempDir.path, 'tiny.sqlite'));
      await file.writeAsBytes(List<int>.filled(100, 1));

      expect(
        () => validator.validate(file.path),
        throwsA(
          isA<SeedArtifactValidationException>().having(
            (e) => e.reasonCode,
            'reasonCode',
            'too_small',
          ),
        ),
      );
    });

    test('accepts schema-compatible files with migratable user_version', () {
      final file = File(p.join(tempDir.path, 'wrong-version.sqlite'));
      createSeedArtifactDatabase(file: file, userVersion: 2);

      final metadata = validator.validate(file.path);
      expect(metadata.userVersion, 2);
    });

    test('accepts valid seed artifacts and returns metadata', () {
      final file = File(p.join(tempDir.path, 'valid.sqlite'));
      createSeedArtifactDatabase(file: file);

      final metadata = validator.validate(file.path);

      expect(metadata.fileSize, greaterThan(0));
      expect(metadata.userVersion, 3);
    });
  });
}
