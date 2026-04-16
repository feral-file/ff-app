import 'dart:io';

import 'package:app/app/bootstrap/app_bootstrap.dart';
import 'package:app/infra/database/seed_database_gate.dart';
import 'package:app/infra/services/seed_database_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import '../../../helpers/seed_database_test_helper.dart';

class _GateSeedDatabaseServiceFake extends SeedDatabaseService {
  _GateSeedDatabaseServiceFake({required this.hasUsableDatabase});

  final bool hasUsableDatabase;

  @override
  Future<bool> hasUsableLocalDatabase() async => hasUsableDatabase;
}

class _BootstrapPathSeedDatabaseService extends SeedDatabaseService {
  _BootstrapPathSeedDatabaseService(this._dbPath);

  final String _dbPath;

  @override
  Future<String> databasePath() async => _dbPath;
}

void main() {
  setUp(SeedDatabaseGate.resetForTesting);

  test(
    'completeSeedDatabaseGateIfUsable opens the gate when database is valid',
    () async {
      final service = _GateSeedDatabaseServiceFake(hasUsableDatabase: true);

      await completeSeedDatabaseGateIfUsable(service);

      expect(SeedDatabaseGate.isCompleted, isTrue);
    },
  );

  test(
    'completeSeedDatabaseGateIfUsable keeps gate closed when database is '
    'invalid',
    () async {
      final service = _GateSeedDatabaseServiceFake(hasUsableDatabase: false);

      await completeSeedDatabaseGateIfUsable(service);

      expect(SeedDatabaseGate.isCompleted, isFalse);
    },
  );

  test(
    'runSeedRepairAndCompleteGateIfUsable repairs interrupted swap then opens '
    'the seed gate (same ordering as bootstrapAppDependencies)',
    () async {
      final tempDir =
          await Directory.systemTemp.createTemp('ff_app_bootstrap_seed_');
      addTearDown(() async {
        if (tempDir.existsSync()) {
          await tempDir.delete(recursive: true);
        }
      });

      final dbPath = p.join(tempDir.path, 'dp1_library.sqlite');
      final backup = File(
        p.join(tempDir.path, 'dp1_library.sqlite.backup.9900'),
      );
      createSeedArtifactDatabase(file: backup);
      await File('${backup.path}-wal').writeAsString('w');
      await File('${backup.path}-shm').writeAsString('s');
      await File('$dbPath.swap_in_progress').writeAsString('9900');

      expect(SeedDatabaseGate.isCompleted, isFalse);
      expect(File(dbPath).existsSync(), isFalse);

      final service = _BootstrapPathSeedDatabaseService(dbPath);
      await runSeedRepairAndCompleteGateIfUsable(service);

      expect(SeedDatabaseGate.isCompleted, isTrue);
      expect(File(dbPath).existsSync(), isTrue);
    },
  );
}
