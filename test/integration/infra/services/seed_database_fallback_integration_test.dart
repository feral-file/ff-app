import 'dart:io';

import 'package:app/infra/database/seed_database_gate.dart';
import 'package:app/infra/services/seed_database_service.dart';
import 'package:app/infra/services/seed_database_sync_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import '../../helpers/integration_test_harness.dart';

/// SeedDatabaseService that uses a temp path and throws on replace.
/// Verifies fallback invariant: when replace fails after beforeReplace,
/// the old DB file remains on disk (project_spec, app_flows).
class _ThrowingReplaceSeedDatabaseService extends SeedDatabaseService {
  _ThrowingReplaceSeedDatabaseService({
    required this.dbPath,
    required Future<Directory> Function() tempDirProvider,
  })  : _tempDirProvider = tempDirProvider,
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
      'seed_${DateTime.now().microsecondsSinceEpoch}.tmp',
    );
    await File(tempPath).writeAsString('temp');
    return tempPath;
  }

  @override
  Future<void> replaceDatabaseFromTemporaryFile(String tempPath) async {
    throw Exception('Simulated replace failure');
  }
}

void main() {
  group('Seed database fallback invariant', () {
    test(
      'when replace fails after beforeReplace, old DB file remains readable',
      () async {
        final provisionedEnvFile = await provisionIntegrationEnvFile();
        addTearDown(() async {
          final parent = provisionedEnvFile.parent;
          if (parent.existsSync()) {
            await parent.delete(recursive: true);
          }
        });

        final tempDir = await Directory.systemTemp.createTemp('ff_seed_fallback_');
        addTearDown(() async {
          if (tempDir.existsSync()) {
            await tempDir.delete(recursive: true);
          }
        });

        final dbPath = p.join(tempDir.path, 'dp1_library.sqlite');
        const marker = 'old-db-content';
        await File(dbPath).writeAsString(marker);

        final seedService = _ThrowingReplaceSeedDatabaseService(
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
        expect(await dbFile.readAsString(), marker);
      },
    );
  });
}
