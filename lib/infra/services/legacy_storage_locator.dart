import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

/// Locates legacy local files from the previous app implementation.
class LegacyStorageLocator {
  static const legacyDbMainnetFileName = 'app_database_mainnet.db';
  static const legacyDbTestnetFileName = 'app_database_testnet.db';
  static const currentSeedDbFileName = 'playlist_cache.sqlite';

  /// Returns true when any legacy SQLite file exists.
  Future<bool> hasLegacySqliteDatabase() async {
    final paths = await findLegacySqlitePaths();
    return paths.isNotEmpty;
  }

  /// Finds candidate legacy SQLite files that may contain personal playlists.
  Future<List<String>> findLegacySqlitePaths() async {
    final candidates = <String>{};

    final databasesDir = await getDatabasesPath();
    final mainnetPath = p.join(databasesDir, legacyDbMainnetFileName);
    final testnetPath = p.join(databasesDir, legacyDbTestnetFileName);
    if (File(mainnetPath).existsSync()) {
      candidates.add(mainnetPath);
    }
    if (File(testnetPath).existsSync()) {
      candidates.add(testnetPath);
    }

    candidates.addAll(
      _collectSqliteLikeFiles(
        Directory(databasesDir),
      ),
    );

    final docsDir = await getApplicationDocumentsDirectory();
    candidates.addAll(
      _collectSqliteLikeFiles(
        docsDir,
      ),
    );

    final sorted = candidates.toList()
      ..sort((a, b) => _candidatePriority(a).compareTo(_candidatePriority(b)));
    return sorted;
  }

  /// Returns candidate directories that may contain legacy Hive boxes.
  Future<List<String>> findLegacyHiveDirectories() async {
    final docsDir = await getApplicationDocumentsDirectory();
    final dbDir = await getDatabasesPath();
    return <String>{docsDir.path, dbDir}.toList(growable: false);
  }

  Iterable<String> _collectSqliteLikeFiles(Directory dir) sync* {
    if (!dir.existsSync()) {
      return;
    }
    for (final entity in dir.listSync(followLinks: false)) {
      if (entity is! File) {
        continue;
      }
      final lowerName = p.basename(entity.path).toLowerCase();
      final isSqlite =
          lowerName.endsWith('.db') ||
          lowerName.endsWith('.sqlite') ||
          lowerName.endsWith('.sqlite3');
      if (!isSqlite) {
        continue;
      }
      if (lowerName == currentSeedDbFileName) {
        continue;
      }
      yield entity.path;
    }
  }

  int _candidatePriority(String path) {
    final name = p.basename(path).toLowerCase();
    if (name == legacyDbMainnetFileName) {
      return 0;
    }
    if (name == legacyDbTestnetFileName) {
      return 1;
    }
    if (name.contains('app_database')) {
      return 2;
    }
    return 3;
  }
}
