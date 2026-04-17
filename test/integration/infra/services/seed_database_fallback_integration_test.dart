import 'dart:io';

import 'package:app/infra/database/seed_database_gate.dart';
import 'package:app/infra/services/seed_database_service.dart';
import 'package:app/infra/services/seed_database_sync_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart' as sqlite3;

import '../../../helpers/seed_database_test_helper.dart';
import '../../helpers/integration_test_harness.dart';

/// SeedDatabaseService that downloads a valid temp seed but fails during
/// promotion after the old DB has already been moved to backup.
/// Verifies the real fallback invariant: restore the previous DB when staged
/// replace cannot complete.
class _FailingPromoteSeedDatabaseService extends SeedDatabaseService {
  _FailingPromoteSeedDatabaseService({
    required this.dbPath,
    required Future<Directory> Function() tempDirProvider,
  }) : _tempDirProvider = tempDirProvider,
       super(temporaryDirectoryProvider: tempDirProvider);

  final String dbPath;
  final Future<Directory> Function() _tempDirProvider;

  @override
  Future<String> databasePath() async => dbPath;

  @override
  Future<bool> hasLocalDatabase() async => File(dbPath).existsSync();

  @override
  Future<String> headRemoteEtag() async => 'remote-etag';

  @override
  Future<String> downloadToTemporaryFile({
    void Function(double progress)? onProgress,
    int? maxBytes,
  }) async {
    onProgress?.call(1);
    final dir = await _tempDirProvider();
    final tempPath = p.join(
      dir.path,
      'seed_${DateTime.now().microsecondsSinceEpoch}.sqlite',
    );
    createSeedArtifactDatabase(file: File(tempPath));
    return tempPath;
  }

  @override
  Future<void> promoteStagedArtifact({
    required String stagingPath,
    required String canonicalPath,
  }) async {
    throw Exception('Simulated promote failure');
  }
}

void main() {
  group('Seed database fallback invariant', () {
    test(
      'when staged replace fails after backup, old sqlite db remains readable',
      () async {
        final provisionedEnvFile = await provisionIntegrationEnvFile();
        addTearDown(() async {
          final parent = provisionedEnvFile.parent;
          if (parent.existsSync()) {
            await parent.delete(recursive: true);
          }
        });

        final tempDir = await Directory.systemTemp.createTemp(
          'ff_seed_fallback_',
        );
        addTearDown(() async {
          if (tempDir.existsSync()) {
            await tempDir.delete(recursive: true);
          }
        });

        final dbPath = p.join(tempDir.path, 'dp1_library.sqlite');
        createSeedArtifactDatabase(file: File(dbPath));

        final seedService = _FailingPromoteSeedDatabaseService(
          dbPath: dbPath,
          tempDirProvider: () async => tempDir,
        );

        var localEtag = 'local-etag';
        final syncService = SeedDatabaseSyncService(
          seedDatabaseService: seedService,
          loadLocalEtag: () => localEtag,
          saveLocalEtag: (etag) => localEtag = etag,
        );

        SeedDatabaseGate.complete();

        final changed = await syncService.sync(
          beforeReplace: () async {
            // Simulates onNotReady: close only, no delete.
            // In production, DatabaseService.close() is called here.
          },
          afterReplace: () async {},
          failSilently: true,
        );

        expect(changed, isFalse);

        final dbFile = File(dbPath);
        expect(dbFile.existsSync(), isTrue);
        final probeDb = sqlite3.sqlite3.open(dbFile.path);
        try {
          final rows = probeDb.select('PRAGMA user_version');
          expect(rows.first.columnAt(0), 3);
        } finally {
          probeDb.dispose();
        }
      },
    );
  });
}
