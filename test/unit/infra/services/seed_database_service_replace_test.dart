import 'dart:io';

import 'package:app/infra/services/seed_database_artifact_validator.dart';
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

/// [repairInterruptedSeedSwapIfNeeded] validates the backup main file, which
/// opens SQLite and may recreate `-wal` / `-shm` next to it. Real mid-crash
/// artifacts can be asymmetric; strip the sidecar we want absent after
/// validation so `_restoreFromBackupSet` sees the intended layout.
class _AsymmetricBackupAfterValidateService
    extends _SeedDatabaseServiceForReplaceTest {
  _AsymmetricBackupAfterValidateService({
    required super.dbPath,
    required this.removeBackupWal,
    required this.removeBackupShm,
  });

  final bool removeBackupWal;
  final bool removeBackupShm;

  @override
  SeedDatabaseArtifactMetadata validateSeedArtifact(String path) {
    final meta = super.validateSeedArtifact(path);
    if (removeBackupWal) {
      final wal = File('$path-wal');
      if (wal.existsSync()) {
        wal.deleteSync();
      }
    }
    if (removeBackupShm) {
      final shm = File('$path-shm');
      if (shm.existsSync()) {
        shm.deleteSync();
      }
    }
    return meta;
  }
}

class _MaterializeBackupSidecarsDuringValidateService
    extends _SeedDatabaseServiceForReplaceTest {
  _MaterializeBackupSidecarsDuringValidateService({
    required super.dbPath,
    required this.materializeWal,
    required this.materializeShm,
  });

  final bool materializeWal;
  final bool materializeShm;

  @override
  SeedDatabaseArtifactMetadata validateSeedArtifact(String path) {
    final meta = super.validateSeedArtifact(path);
    if (materializeWal) {
      final wal = File('$path-wal');
      if (!wal.existsSync()) {
        wal.writeAsStringSync('validator-created-wal');
      }
    }
    if (materializeShm) {
      final shm = File('$path-shm');
      if (!shm.existsSync()) {
        shm.writeAsStringSync('validator-created-shm');
      }
    }
    return meta;
  }
}

class _ThrowingSidecarCleanupAfterStagePromotionService
    extends _SeedDatabaseServiceForReplaceTest {
  _ThrowingSidecarCleanupAfterStagePromotionService({
    required super.dbPath,
  });

  @override
  Future<void> cleanupCanonicalSidecarsAfterStagedPromotion(
    String dbPath,
  ) async {
    throw Exception('Simulated sidecar cleanup failure');
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

    test(
      'repairInterruptedSeedSwapIfNeeded restores backup sidecars over stale '
      'canonical sidecars',
      () async {
        final dbPath = p.join(tempDir.path, 'dp1_library.sqlite');
        final marker = File('$dbPath.swap_in_progress');
        final backup = File(
          p.join(tempDir.path, 'dp1_library.sqlite.backup.9009'),
        );
        final canonicalWal = File('$dbPath-wal');
        final canonicalShm = File('$dbPath-shm');

        createSeedArtifactDatabase(file: backup);
        await File('${backup.path}-wal').writeAsString('backup-wal');
        await File('${backup.path}-shm').writeAsString('backup-shm');
        await canonicalWal.writeAsString('stale-wal');
        await canonicalShm.writeAsString('stale-shm');
        await marker.writeAsString('9009');

        final service = _SeedDatabaseServiceForReplaceTest(dbPath: dbPath);
        final repaired = await service.repairInterruptedSeedSwapIfNeeded();

        expect(repaired, isTrue);
        expect(File(dbPath).existsSync(), isTrue);
        expect(canonicalWal.existsSync(), isTrue);
        expect(canonicalShm.existsSync(), isTrue);
        expect(canonicalWal.lengthSync(), greaterThan(0));
        expect(canonicalShm.lengthSync(), greaterThan(0));
      },
    );

    test(
      'repairInterruptedSeedSwapIfNeeded restores canonical WAL when moving '
      'canonical SHM to rollback fails',
      () async {
        SeedDatabaseService.resetMoveFileDebugForTest();
        addTearDown(SeedDatabaseService.resetMoveFileDebugForTest);
        final dbPath = p.join(tempDir.path, 'dp1_library.sqlite');
        final marker = File('$dbPath.swap_in_progress');
        final backup = File(
          p.join(tempDir.path, 'dp1_library.sqlite.backup.9011'),
        );
        final canonicalWal = File('$dbPath-wal');
        final canonicalShm = File('$dbPath-shm');

        createSeedArtifactDatabase(file: backup);
        await File('${backup.path}-wal').writeAsString('backup-wal');
        await File('${backup.path}-shm').writeAsString('backup-shm');
        await canonicalWal.writeAsString('canonical-wal');
        await canonicalShm.writeAsString('canonical-shm');
        await marker.writeAsString('9011');

        // Move order in this restore path:
        // 1) backup main -> restore main
        // 2) backup wal -> restore wal
        // 3) backup shm -> restore shm
        // 4) canonical wal -> rollback wal
        // 5) canonical shm -> rollback shm (fail here)
        SeedDatabaseService.debugSimulateRenameFailureOnMoveCallOneBased = 5;
        SeedDatabaseService.debugSimulateDeleteFailureAfterCopyMove = true;

        final service = _SeedDatabaseServiceForReplaceTest(dbPath: dbPath);
        final repaired = await service.repairInterruptedSeedSwapIfNeeded();

        expect(repaired, isFalse);
        expect(canonicalWal.existsSync(), isTrue);
        expect(canonicalShm.existsSync(), isTrue);
        expect(await canonicalWal.readAsString(), 'canonical-wal');
        expect(await canonicalShm.readAsString(), 'canonical-shm');
      },
    );

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
      'repairInterruptedSeedSwapIfNeeded preserves canonical sidecars when '
      'staged promotion fails',
      () async {
        final dbPath = p.join(tempDir.path, 'dp1_library.sqlite');
        final staged = File(
          p.join(tempDir.path, 'dp1_library.sqlite.stage.1010'),
        );
        final canonicalWal = File('$dbPath-wal');
        final canonicalShm = File('$dbPath-shm');

        createSeedArtifactDatabase(file: staged);
        await File('$dbPath.swap_in_progress').writeAsString('1010');
        await canonicalWal.writeAsString('stale-wal');
        await canonicalShm.writeAsString('stale-shm');

        final service = _SeedDatabaseServiceForReplaceTest(
          dbPath: dbPath,
          throwOnPromote: true,
        );
        final repaired = await service.repairInterruptedSeedSwapIfNeeded();

        expect(repaired, isFalse);
        expect(canonicalWal.existsSync(), isTrue);
        expect(canonicalShm.existsSync(), isTrue);
        expect(await canonicalWal.readAsString(), 'stale-wal');
        expect(await canonicalShm.readAsString(), 'stale-shm');
      },
    );

    test(
      'first install: restores orphan canonical WAL from backup when promote '
      'fails after WAL was moved aside',
      () async {
        final dbPath = p.join(tempDir.path, 'dp1_library.sqlite');
        expect(File(dbPath).existsSync(), isFalse);

        final canonicalWal = File('$dbPath-wal');
        await canonicalWal.writeAsString('orphan-wal-payload');

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

        expect(await canonicalWal.readAsString(), 'orphan-wal-payload');
      },
    );

    test(
      'repairInterruptedSeedSwapIfNeeded clears swap marker when canonical '
      'validates and leaves no repair work',
      () async {
        final dbPath = p.join(tempDir.path, 'dp1_library.sqlite');
        final staged = File(
          p.join(tempDir.path, 'dp1_library.sqlite.stage.5000'),
        );
        createSeedArtifactDatabase(file: File(dbPath));
        createSeedArtifactDatabase(file: staged);
        final swapMarker = File('$dbPath.swap_in_progress');
        await swapMarker.writeAsString('5000');

        final service = _SeedDatabaseServiceForReplaceTest(dbPath: dbPath);
        expect(await service.repairInterruptedSeedSwapIfNeeded(), isFalse);
        expect(swapMarker.existsSync(), isFalse);
        expect(File(dbPath).existsSync(), isTrue);
      },
    );

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
      'repairInterruptedSeedSwapIfNeeded promotes staged artifact when '
      'canonical is missing',
      () async {
        final dbPath = p.join(tempDir.path, 'dp1_library.sqlite');
        expect(File(dbPath).existsSync(), isFalse);

        final staged = File(
          p.join(tempDir.path, 'dp1_library.sqlite.stage.1001'),
        );
        createSeedArtifactDatabase(file: staged);
        await File('$dbPath.swap_in_progress').writeAsString('1001');

        final service = _SeedDatabaseServiceForReplaceTest(dbPath: dbPath);
        final repaired = await service.repairInterruptedSeedSwapIfNeeded();
        expect(repaired, isTrue);
        expect(File(dbPath).existsSync(), isTrue);

        final db = sqlite3.sqlite3.open(dbPath);
        try {
          final rows = db.select('PRAGMA user_version');
          expect(rows.first.columnAt(0), 3);
        } finally {
          db.dispose();
        }
      },
    );

    test(
      'repairInterruptedSeedSwapIfNeeded removes stale canonical WAL/SHM '
      'before promoting staged artifact',
      () async {
        final dbPath = p.join(tempDir.path, 'dp1_library.sqlite');
        final wal = File('$dbPath-wal');
        final shm = File('$dbPath-shm');
        final staged = File(
          p.join(tempDir.path, 'dp1_library.sqlite.stage.1002'),
        );

        createSeedArtifactDatabase(file: staged);
        await File('$dbPath.swap_in_progress').writeAsString('1002');
        await wal.writeAsString('stale-wal');
        await shm.writeAsString('stale-shm');

        final service = _SeedDatabaseServiceForReplaceTest(dbPath: dbPath);
        final repaired = await service.repairInterruptedSeedSwapIfNeeded();

        expect(repaired, isTrue);
        expect(File(dbPath).existsSync(), isTrue);
        expect(wal.existsSync(), isFalse);
        expect(shm.existsSync(), isFalse);

        final db = sqlite3.sqlite3.open(dbPath);
        try {
          final rows = db.select('PRAGMA user_version');
          expect(rows.first.columnAt(0), 3);
        } finally {
          db.dispose();
        }
      },
    );

    test(
      'repairInterruptedSeedSwapIfNeeded overwrites corrupt canonical db '
      'when promoting staged artifact',
      () async {
        final dbPath = p.join(tempDir.path, 'dp1_library.sqlite');
        final staged = File(
          p.join(tempDir.path, 'dp1_library.sqlite.stage.1003'),
        );

        createSeedArtifactDatabase(file: staged);
        await File(dbPath).writeAsBytes(List<int>.filled(512, 9));
        await File('$dbPath.swap_in_progress').writeAsString('1003');

        final service = _SeedDatabaseServiceForReplaceTest(dbPath: dbPath);
        final repaired = await service.repairInterruptedSeedSwapIfNeeded();

        expect(repaired, isTrue);
        final db = sqlite3.sqlite3.open(dbPath);
        try {
          final rows = db.select('PRAGMA user_version');
          expect(rows.first.columnAt(0), 3);
        } finally {
          db.dispose();
        }
      },
    );

    test(
      'repairInterruptedSeedSwapIfNeeded restores canonical db when staged '
      'promotion fails',
      () async {
        final dbPath = p.join(tempDir.path, 'dp1_library.sqlite');
        final staged = File(
          p.join(tempDir.path, 'dp1_library.sqlite.stage.1004'),
        );

        createSeedArtifactDatabase(file: staged);
        createSeedArtifactDatabase(file: File(dbPath));
        await File('$dbPath.swap_in_progress').writeAsString('1004');

        final service = _SeedDatabaseServiceForReplaceTest(
          dbPath: dbPath,
          throwOnPromote: true,
        );
        final repaired = await service.repairInterruptedSeedSwapIfNeeded();

        expect(repaired, isFalse);
        final db = sqlite3.sqlite3.open(dbPath);
        try {
          final rows = db.select('PRAGMA user_version');
          expect(rows.first.columnAt(0), 3);
        } finally {
          db.dispose();
        }
      },
    );

    test(
      'repairInterruptedSeedSwapIfNeeded preserves canonical WAL/SHM while '
      'restoring the main db',
      () async {
        final dbPath = p.join(tempDir.path, 'dp1_library.sqlite');
        final marker = File('$dbPath.swap_in_progress');
        final backup = File(
          p.join(tempDir.path, 'dp1_library.sqlite.backup.2002'),
        );
        final wal = File('$dbPath-wal');
        final shm = File('$dbPath-shm');

        createSeedArtifactDatabase(file: backup);
        await marker.writeAsString('2002');
        await wal.writeAsString('wal-preserved');
        await shm.writeAsString('shm-preserved');

        final service = _SeedDatabaseServiceForReplaceTest(dbPath: dbPath);
        final repaired = await service.repairInterruptedSeedSwapIfNeeded();

        expect(repaired, isTrue);
        expect(File(dbPath).existsSync(), isTrue);
        expect(wal.existsSync(), isTrue);
        expect(shm.existsSync(), isTrue);
        expect(await wal.readAsString(), 'wal-preserved');
        expect(await shm.readAsString(), 'shm-preserved');
      },
    );

    test(
      'repairInterruptedSeedSwapIfNeeded skips invalid stage residue when '
      'no valid backup exists',
      () async {
        final dbPath = p.join(tempDir.path, 'dp1_library.sqlite');
        expect(File(dbPath).existsSync(), isFalse);

        final staged = File(
          p.join(tempDir.path, 'dp1_library.sqlite.stage.3003'),
        );
        await staged.writeAsBytes(List<int>.filled(1024, 7));
        await File('$dbPath.swap_in_progress').writeAsString('3003');

        final service = _SeedDatabaseServiceForReplaceTest(dbPath: dbPath);
        final repaired = await service.repairInterruptedSeedSwapIfNeeded();
        expect(repaired, isFalse);
        expect(File(dbPath).existsSync(), isFalse);
      },
    );

    test(
      'repairInterruptedSeedSwapIfNeeded ignores stale swap artifacts when '
      'no replace marker exists',
      () async {
        final dbPath = p.join(tempDir.path, 'dp1_library.sqlite');
        final staged = File(
          p.join(tempDir.path, 'dp1_library.sqlite.stage.6006'),
        );
        final backup = File(
          p.join(tempDir.path, 'dp1_library.sqlite.backup.6006'),
        );
        createSeedArtifactDatabase(file: staged);
        createSeedArtifactDatabase(file: backup);

        final service = _SeedDatabaseServiceForReplaceTest(dbPath: dbPath);
        final repaired = await service.repairInterruptedSeedSwapIfNeeded();

        expect(repaired, isFalse);
        expect(File(dbPath).existsSync(), isFalse);
      },
    );

    test(
      'deleteDatabaseFiles removes staged and backup swap artifacts',
      () async {
        final dbPath = p.join(tempDir.path, 'dp1_library.sqlite');
        final service = _SeedDatabaseServiceForReplaceTest(dbPath: dbPath);
        createSeedArtifactDatabase(file: File(dbPath));

        final staged = File(
          p.join(tempDir.path, 'dp1_library.sqlite.stage.4004'),
        );
        final backup = File(
          p.join(tempDir.path, 'dp1_library.sqlite.backup.4005'),
        );
        final backupWal = File('${backup.path}-wal');
        final backupShm = File('${backup.path}-shm');
        createSeedArtifactDatabase(file: staged, userVersion: 2);
        createSeedArtifactDatabase(file: backup, userVersion: 1);
        await backupWal.writeAsString('wal');
        await backupShm.writeAsString('shm');

        await service.deleteDatabaseFiles();

        expect(File(dbPath).existsSync(), isFalse);
        expect(File('$dbPath-wal').existsSync(), isFalse);
        expect(File('$dbPath-shm').existsSync(), isFalse);
        expect(staged.existsSync(), isFalse);
        expect(backup.existsSync(), isFalse);
        expect(backupWal.existsSync(), isFalse);
        expect(backupShm.existsSync(), isFalse);
      },
    );

    test(
      'repairInterruptedSeedSwapIfNeeded restores backup sidecars when the '
      'canonical db is missing',
      () async {
        final dbPath = p.join(tempDir.path, 'dp1_library.sqlite');
        final backup = File(
          p.join(tempDir.path, 'dp1_library.sqlite.backup.7007'),
        );
        createSeedArtifactDatabase(file: backup);
        final backupWalPath = '${backup.path}-wal';
        final backupShmPath = '${backup.path}-shm';
        await File(backupWalPath).writeAsString('committed-wal');
        await File(backupShmPath).writeAsString('committed-shm');
        await File('$dbPath.swap_in_progress').writeAsString('7007');

        final service = _SeedDatabaseServiceForReplaceTest(dbPath: dbPath);
        final repaired = await service.repairInterruptedSeedSwapIfNeeded();

        expect(repaired, isTrue);
        expect(File(dbPath).existsSync(), isTrue);
        expect(File('$dbPath-wal').existsSync(), isTrue);
        expect(File('$dbPath-shm').existsSync(), isTrue);
      },
    );

    test(
      'repairInterruptedSeedSwapIfNeeded preserves canonical WAL when backup '
      'has SHM but no WAL',
      () async {
        final dbPath = p.join(tempDir.path, 'dp1_library.sqlite');
        final backup = File(
          p.join(tempDir.path, 'dp1_library.sqlite.backup.7101'),
        );
        createSeedArtifactDatabase(file: backup);
        await File('${backup.path}-shm').writeAsString('backup-shm');
        await File('$dbPath-wal').writeAsString('precious-wal');
        await File('$dbPath.swap_in_progress').writeAsString('7101');

        final service = _AsymmetricBackupAfterValidateService(
          dbPath: dbPath,
          removeBackupWal: true,
          removeBackupShm: false,
        );
        final repaired = await service.repairInterruptedSeedSwapIfNeeded();

        expect(repaired, isTrue);
        expect(File(dbPath).existsSync(), isTrue);
        expect(File('$dbPath-wal').existsSync(), isTrue);
        expect(await File('$dbPath-wal').readAsString(), 'precious-wal');
        expect(File('$dbPath-shm').existsSync(), isTrue);
        expect(await File('$dbPath-shm').readAsString(), 'backup-shm');
      },
    );

    test(
      'repairInterruptedSeedSwapIfNeeded preserves canonical SHM when backup '
      'has WAL but no SHM',
      () async {
        final dbPath = p.join(tempDir.path, 'dp1_library.sqlite');
        final backup = File(
          p.join(tempDir.path, 'dp1_library.sqlite.backup.7102'),
        );
        createSeedArtifactDatabase(file: backup);
        await File('${backup.path}-wal').writeAsString('backup-wal');
        await File('$dbPath-shm').writeAsString('precious-shm');
        await File('$dbPath.swap_in_progress').writeAsString('7102');

        final service = _AsymmetricBackupAfterValidateService(
          dbPath: dbPath,
          removeBackupWal: false,
          removeBackupShm: true,
        );
        final repaired = await service.repairInterruptedSeedSwapIfNeeded();

        expect(repaired, isTrue);
        expect(File(dbPath).existsSync(), isTrue);
        expect(File('$dbPath-shm').existsSync(), isTrue);
        expect(await File('$dbPath-shm').readAsString(), 'precious-shm');
        expect(File('$dbPath-wal').existsSync(), isTrue);
        expect(await File('$dbPath-wal').readAsString(), 'backup-wal');
      },
    );

    test(
      'repairInterruptedSeedSwapIfNeeded preserves canonical WAL/SHM when '
      'validator materializes missing backup sidecars',
      () async {
        final dbPath = p.join(tempDir.path, 'dp1_library.sqlite');
        final backup = File(
          p.join(tempDir.path, 'dp1_library.sqlite.backup.7103'),
        );
        createSeedArtifactDatabase(file: backup);
        await File('${backup.path}-shm').writeAsString('backup-shm');
        await File('$dbPath-wal').writeAsString('precious-wal');
        await File('$dbPath-shm').writeAsString('precious-shm');
        await File('$dbPath.swap_in_progress').writeAsString('7103');

        final service = _MaterializeBackupSidecarsDuringValidateService(
          dbPath: dbPath,
          materializeWal: true,
          materializeShm: false,
        );
        final repaired = await service.repairInterruptedSeedSwapIfNeeded();

        expect(repaired, isTrue);
        expect(File(dbPath).existsSync(), isTrue);
        expect(await File('$dbPath-wal').readAsString(), 'precious-wal');
        expect(await File('$dbPath-shm').readAsString(), 'backup-shm');
      },
    );

    test(
      'repairInterruptedSeedSwapIfNeeded prefers staged artifact over backup '
      'for the same nonce',
      () async {
        final dbPath = p.join(tempDir.path, 'dp1_library.sqlite');
        final marker = File('$dbPath.swap_in_progress');
        final staged = File(
          p.join(tempDir.path, 'dp1_library.sqlite.stage.8008'),
        );
        final backup = File(
          p.join(tempDir.path, 'dp1_library.sqlite.backup.8008'),
        );

        createSeedArtifactDatabase(file: staged);
        createSeedArtifactDatabase(file: backup);
        final stageDb = sqlite3.sqlite3.open(staged.path);
        final backupDb = sqlite3.sqlite3.open(backup.path);
        try {
          stageDb.execute("UPDATE playlists SET title = 'Stage wins'");
          backupDb.execute("UPDATE playlists SET title = 'Backup loses'");
        } finally {
          stageDb.dispose();
          backupDb.dispose();
        }
        await marker.writeAsString('8008');

        final service = _SeedDatabaseServiceForReplaceTest(dbPath: dbPath);
        final repaired = await service.repairInterruptedSeedSwapIfNeeded();

        expect(repaired, isTrue);
        final db = sqlite3.sqlite3.open(dbPath);
        try {
          final rows = db.select('SELECT title FROM playlists LIMIT 1');
          expect(rows.first.columnAt(0), 'Stage wins');
        } finally {
          db.dispose();
        }
      },
    );

    test(
      'repairInterruptedSeedSwapIfNeeded keeps promoted staged db when '
      'sidecar cleanup fails',
      () async {
        final dbPath = p.join(tempDir.path, 'dp1_library.sqlite');
        final marker = File('$dbPath.swap_in_progress');
        final staged = File(
          p.join(tempDir.path, 'dp1_library.sqlite.stage.8110'),
        );
        final backup = File(
          p.join(tempDir.path, 'dp1_library.sqlite.backup.8110'),
        );

        createSeedArtifactDatabase(file: staged);
        createSeedArtifactDatabase(file: backup);
        final stageDb = sqlite3.sqlite3.open(staged.path);
        final backupDb = sqlite3.sqlite3.open(backup.path);
        try {
          stageDb.execute(
            "UPDATE playlists SET title = 'Stage survives cleanup'",
          );
          backupDb.execute(
            "UPDATE playlists SET title = 'Backup should not win'",
          );
        } finally {
          stageDb.dispose();
          backupDb.dispose();
        }
        await marker.writeAsString('8110');

        final service = _ThrowingSidecarCleanupAfterStagePromotionService(
          dbPath: dbPath,
        );
        final repaired = await service.repairInterruptedSeedSwapIfNeeded();

        expect(repaired, isTrue);
        final db = sqlite3.sqlite3.open(dbPath);
        try {
          final rows = db.select('SELECT title FROM playlists LIMIT 1');
          expect(rows.first.columnAt(0), 'Stage survives cleanup');
        } finally {
          db.dispose();
        }
      },
    );

    test(
      'repairInterruptedSeedSwapIfNeeded only evaluates artifacts that match '
      'swap marker nonce',
      () async {
        final dbPath = p.join(tempDir.path, 'dp1_library.sqlite');
        final marker = File('$dbPath.swap_in_progress');
        final stagedDifferentNonce = File(
          p.join(tempDir.path, 'dp1_library.sqlite.stage.9002'),
        );
        final backupMarkedNonce = File(
          p.join(tempDir.path, 'dp1_library.sqlite.backup.9001'),
        );

        createSeedArtifactDatabase(file: stagedDifferentNonce);
        createSeedArtifactDatabase(file: backupMarkedNonce);

        final stagedDb = sqlite3.sqlite3.open(stagedDifferentNonce.path);
        final backupDb = sqlite3.sqlite3.open(backupMarkedNonce.path);
        try {
          stagedDb.execute(
            "UPDATE playlists SET title = 'staged-should-not-win'",
          );
          backupDb.execute(
            "UPDATE playlists SET title = 'marker-nonce-backup'",
          );
        } finally {
          stagedDb.dispose();
          backupDb.dispose();
        }
        await marker.writeAsString('9001');

        final service = _SeedDatabaseServiceForReplaceTest(dbPath: dbPath);
        final repaired = await service.repairInterruptedSeedSwapIfNeeded();

        expect(repaired, isTrue);
        final db = sqlite3.sqlite3.open(dbPath);
        try {
          final rows = db.select('SELECT title FROM playlists LIMIT 1');
          expect(rows.first.columnAt(0), 'marker-nonce-backup');
        } finally {
          db.dispose();
        }
      },
    );

    test(
      'repairInterruptedSeedSwapIfNeeded skips repair when marker nonce is '
      'malformed',
      () async {
        final dbPath = p.join(tempDir.path, 'dp1_library.sqlite');
        final marker = File('$dbPath.swap_in_progress');
        final staged = File(
          p.join(tempDir.path, 'dp1_library.sqlite.stage.9101'),
        );
        createSeedArtifactDatabase(file: staged);
        await marker.writeAsString('bad-marker');

        final service = _SeedDatabaseServiceForReplaceTest(dbPath: dbPath);
        final repaired = await service.repairInterruptedSeedSwapIfNeeded();

        expect(repaired, isFalse);
        expect(File(dbPath).existsSync(), isFalse);
      },
    );

    test(
      'repairInterruptedSeedSwapIfNeeded restores backup sidecars when '
      'main restore fails after sidecars were promoted',
      () async {
        SeedDatabaseService.resetMoveFileDebugForTest();
        addTearDown(SeedDatabaseService.resetMoveFileDebugForTest);
        final dbPath = p.join(tempDir.path, 'dp1_library.sqlite');
        final marker = File('$dbPath.swap_in_progress');
        final backup = File(
          p.join(tempDir.path, 'dp1_library.sqlite.backup.7201'),
        );

        createSeedArtifactDatabase(file: backup);
        await File('${backup.path}-wal').writeAsString('backup-wal');
        await File('${backup.path}-shm').writeAsString('backup-shm');
        await marker.writeAsString('7201');

        SeedDatabaseService.debugSimulateRenameFailureOnMoveCallOneBased = 6;
        SeedDatabaseService.debugSimulateDeleteFailureAfterCopyMove = true;

        final service = _SeedDatabaseServiceForReplaceTest(dbPath: dbPath);
        final repaired = await service.repairInterruptedSeedSwapIfNeeded();

        expect(
          repaired,
          isFalse,
          reason:
              'Main restore fails by design, so startup repair should fail.',
        );
        expect(File('$dbPath-wal').existsSync(), isFalse);
        expect(File('$dbPath-shm').existsSync(), isFalse);
        expect(File('${backup.path}-wal').existsSync(), isTrue);
        expect(File('${backup.path}-shm').existsSync(), isTrue);
      },
    );

    test(
      'repairInterruptedSeedSwapIfNeeded overwrites corrupt canonical db '
      'when restoring a backup set',
      () async {
        final dbPath = p.join(tempDir.path, 'dp1_library.sqlite');
        final marker = File('$dbPath.swap_in_progress');
        final backup = File(
          p.join(tempDir.path, 'dp1_library.sqlite.backup.9010'),
        );

        createSeedArtifactDatabase(file: backup);
        await File('${backup.path}-wal').writeAsString('backup-wal');
        await File('${backup.path}-shm').writeAsString('backup-shm');
        await File(dbPath).writeAsBytes(List<int>.filled(512, 7));
        await File('$dbPath-wal').writeAsString('stale-wal');
        await File('$dbPath-shm').writeAsString('stale-shm');
        await marker.writeAsString('9010');

        final service = _SeedDatabaseServiceForReplaceTest(dbPath: dbPath);
        final repaired = await service.repairInterruptedSeedSwapIfNeeded();

        expect(repaired, isTrue);
        final db = sqlite3.sqlite3.open(dbPath);
        try {
          final rows = db.select('PRAGMA user_version');
          expect(rows.first.columnAt(0), 3);
        } finally {
          db.dispose();
        }
      },
    );

    test(
      'rename fallback delete failure after copy undoes partial backup write',
      () async {
        addTearDown(SeedDatabaseService.resetMoveFileDebugForTest);
        final canonical = File(p.join(tempDir.path, 'dp1_library.sqlite'));
        final tempSeed = File(p.join(tempDir.path, 'incoming.sqlite'));
        createSeedArtifactDatabase(file: canonical);
        createSeedArtifactDatabase(file: tempSeed);

        SeedDatabaseService.debugSimulateRenameFailureOnMoveCallOneBased = 2;
        SeedDatabaseService.debugSimulateDeleteFailureAfterCopyMove = true;

        final service = _SeedDatabaseServiceForReplaceTest(
          dbPath: canonical.path,
        );

        await expectLater(
          () => service.replaceDatabaseFromTemporaryFile(tempSeed.path),
          throwsException,
        );

        expect(File(canonical.path).existsSync(), isTrue);
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

    test('hasUsableLocalDatabase returns true for a valid artifact', () async {
      final dbPath = p.join(tempDir.path, 'dp1_library.sqlite');
      createSeedArtifactDatabase(file: File(dbPath));

      final service = _SeedDatabaseServiceForReplaceTest(dbPath: dbPath);
      final hasUsableDatabase = await service.hasUsableLocalDatabase();

      expect(hasUsableDatabase, isTrue);
    });

    test('hasUsableLocalDatabase returns false when file is missing', () async {
      final dbPath = p.join(tempDir.path, 'dp1_library.sqlite');
      final service = _SeedDatabaseServiceForReplaceTest(dbPath: dbPath);

      final hasUsableDatabase = await service.hasUsableLocalDatabase();

      expect(hasUsableDatabase, isFalse);
    });

    test(
      'hasUsableLocalDatabase returns false for invalid database bytes',
      () async {
        final dbPath = p.join(tempDir.path, 'dp1_library.sqlite');
        await File(dbPath).writeAsBytes(List<int>.filled(1024, 11));
        final service = _SeedDatabaseServiceForReplaceTest(dbPath: dbPath);

        final hasUsableDatabase = await service.hasUsableLocalDatabase();

        expect(hasUsableDatabase, isFalse);
      },
    );
  });
}
