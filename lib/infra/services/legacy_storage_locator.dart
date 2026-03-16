import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Locates legacy local files from the previous app implementation.
class LegacyStorageLocator {
  /// Legacy SQLite database file name from the old app.
  static const legacySqliteFileName = 'playlist_cache.sqlite';

  /// Returns true when the legacy SQLite file exists.
  Future<bool> hasLegacySqliteDatabase() async {
    final path = await legacySqlitePath();
    return File(path).existsSync();
  }

  /// Returns the application documents directory path.
  Future<String> documentsPath() async {
    final docsDir = await getApplicationDocumentsDirectory();
    return docsDir.path;
  }

  /// Returns the absolute path of legacy SQLite in documents directory.
  Future<String> legacySqlitePath() async {
    final docsPath = await documentsPath();
    return p.join(docsPath, legacySqliteFileName);
  }

  /// Returns legacy SQLite path when it exists, else empty list.
  Future<List<String>> findLegacySqlitePaths() async {
    final path = await legacySqlitePath();
    if (!File(path).existsSync()) {
      return const [];
    }
    return [path];
  }

  /// Deletes the legacy SQLite file if it exists.
  /// Prevents legacy migration from re-importing addresses after "Forget I Exist".
  Future<void> deleteLegacySqlite() async {
    final path = await legacySqlitePath();
    final file = File(path);
    if (file.existsSync()) {
      await file.delete();
    }
  }
}
