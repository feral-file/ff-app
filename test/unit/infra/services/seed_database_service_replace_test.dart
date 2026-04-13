import 'dart:io';

import 'package:app/infra/services/seed_database_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart' as sqlite3;

import '../../../helpers/seed_database_test_helper.dart';

class _SeedDatabaseServiceForReplaceTest extends SeedDatabaseService {
  _SeedDatabaseServiceForReplaceTest({
    required this.dbPath,
    this.throwOnPromote = false,
  }) : super();

  final String dbPath;
  final bool throwOnPromote;

  @override
  Future<String> databasePath() async => dbPath;

  @override
  Future<void> promoteStagedArtifact({
    required String stagingPath,
    required String canonicalPath,
  }) async {
    if (throwOnPromote) {
      throw Exception('Simulated promote failure');
    }
    await super.promoteStagedArtifact(
      stagingPath: stagingPath,
      canonicalPath: canonicalPath,
    );
  }
}

/// Fails only when moving the `-shm` sidecar so WAL backup succeeds but SHM
/// does not — rollback must not delete an unmoved canonical `-wal`.
class _ThrowOnShmMoveSeedService extends _SeedDatabaseServiceForReplaceTest {
  _ThrowOnShmMoveSeedService({required super.dbPath});

  @override
  Future<void> moveExistingDatabaseToBackup({
    required String canonicalPath,
    required String backupPath,
  }) async {
    if (canonicalPath.endsWith('-shm')) {
      throw Exception('Simulated SHM move failure');
    }
    await super.moveExistingDatabaseToBackup(
      canonicalPath: canonicalPath,
      backupPath: backupPath,
    );
  }
}

void main() {
  group('SeedDatabaseService.replaceDatabaseFromTemporaryFile', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('ff_seed_replace_');
    });

    tearDown(() async {
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('replaces the canonical db with a validated temp artifact', () async {
      final canonical = File(p.join(tempDir.path, 'dp1_library.sqlite'));
      final tempSeed = File(p.join(tempDir.path, 'incoming.sqlite'));
      createSeedArtifactDatabase(file: canonical, userVersion: 2);
      createSeedArtifactDatabase(file: tempSeed);

      final service = _SeedDatabaseServiceForReplaceTest(
        dbPath: canonical.path,
      );
      final metadata = service.validateSeedArtifact(tempSeed.path);

      await service.replaceDatabaseFromTemporaryFile(
        tempSeed.path,
        prevalidatedArtifact: metadata,
      );

      expect(tempSeed.existsSync(), isFalse);
      final db = sqlite3.sqlite3.open(canonical.path);
      try {
        final versionRows = db.select('PRAGMA user_version');
        expect(versionRows.first.columnAt(0), 3);
      } finally {
        db.dispose();
      }
    });

    test('restores the previous canonical db when promote fails', () async {
      final canonical = File(p.join(tempDir.path, 'dp1_library.sqlite'));
      final tempSeed = File(p.join(tempDir.path, 'incoming.sqlite'));
      createSeedArtifactDatabase(file: canonical);
      createSeedArtifactDatabase(file: tempSeed);

      final service = _SeedDatabaseServiceForReplaceTest(
        dbPath: canonical.path,
        throwOnPromote: true,
      );

      await expectLater(
        () => service.replaceDatabaseFromTemporaryFile(tempSeed.path),
        throwsException,
      );

      final db = sqlite3.sqlite3.open(canonical.path);
      try {
        final rows = db.select('PRAGMA user_version');
        expect(rows.first.columnAt(0), 3);
      } finally {
        db.dispose();
      }
    });

    test(
      'first install: when promote fails, staged artifact is cleaned up',
      () async {
        final dbPath = p.join(tempDir.path, 'dp1_library.sqlite');
        expect(File(dbPath).existsSync(), isFalse);

        final tempSeed = File(p.join(tempDir.path, 'incoming.sqlite'));
        createSeedArtifactDatabase(file: tempSeed);

        final service = _SeedDatabaseServiceForReplaceTest(
          dbPath: dbPath,
          throwOnPromote: true,
        );

        await expectLater(
          () => service.replaceDatabaseFromTemporaryFile(tempSeed.path),
          throwsException,
        );

        expect(File(dbPath).existsSync(), isFalse);
        final staged = tempDir
            .listSync()
            .whereType<File>()
            .where((f) => p.basename(f.path).contains('.stage.'))
            .toList();
        expect(staged, isEmpty);
      },
    );

    test(
      'restores canonical db when backup move uses rename fallback '
      'and promote fails',
      () async {
        addTearDown(SeedDatabaseService.resetMoveFileDebugForTest);
        final canonical = File(p.join(tempDir.path, 'dp1_library.sqlite'));
        final tempSeed = File(p.join(tempDir.path, 'incoming.sqlite'));
        createSeedArtifactDatabase(file: canonical);
        createSeedArtifactDatabase(file: tempSeed);

        // Move order: 1) temp→staging 2) canonical→backup (sim. rename fail).
        SeedDatabaseService.debugSimulateRenameFailureOnMoveCallOneBased = 2;

        final service = _SeedDatabaseServiceForReplaceTest(
          dbPath: canonical.path,
          throwOnPromote: true,
        );

        await expectLater(
          () => service.replaceDatabaseFromTemporaryFile(tempSeed.path),
          throwsException,
        );

        final db = sqlite3.sqlite3.open(canonical.path);
        try {
          final rows = db.select('PRAGMA user_version');
          expect(rows.first.columnAt(0), 3);
        } finally {
          db.dispose();
        }
      },
    );

    test(
      'rollback restores main and WAL when SHM move fails before backup',
      () async {
        final canonical = File(p.join(tempDir.path, 'dp1_library.sqlite'));
        final tempSeed = File(p.join(tempDir.path, 'incoming.sqlite'));
        createSeedArtifactDatabase(file: canonical);
        createSeedArtifactDatabase(file: tempSeed);

        final db = sqlite3.sqlite3.open(canonical.path);
        try {
          db
            ..execute('PRAGMA journal_mode=WAL;')
            ..execute('UPDATE channels SET title = title WHERE 1=1');
        } finally {
          db.dispose();
        }

        final service = _ThrowOnShmMoveSeedService(dbPath: canonical.path);

        await expectLater(
          () => service.replaceDatabaseFromTemporaryFile(tempSeed.path),
          throwsException,
        );

        final db2 = sqlite3.sqlite3.open(canonical.path);
        try {
          final rows = db2.select('PRAGMA user_version');
          expect(rows.first.columnAt(0), 3);
        } finally {
          db2.dispose();
        }
      },
    );

    test(
      'rejects invalid temp artifacts without touching the canonical db',
      () async {
        final canonical = File(p.join(tempDir.path, 'dp1_library.sqlite'));
        final tempSeed = File(p.join(tempDir.path, 'incoming.sqlite'));
        createSeedArtifactDatabase(file: canonical);
        await tempSeed.writeAsBytes(List<int>.filled(1024, 3));

        final service = _SeedDatabaseServiceForReplaceTest(
          dbPath: canonical.path,
        );

        await expectLater(
          () => service.replaceDatabaseFromTemporaryFile(tempSeed.path),
          throwsException,
        );

        expect(tempSeed.existsSync(), isFalse);
        final db = sqlite3.sqlite3.open(canonical.path);
        try {
          final rows = db.select('PRAGMA user_version');
          expect(rows.first.columnAt(0), 3);
        } finally {
          db.dispose();
        }
      },
    );
  });
}
