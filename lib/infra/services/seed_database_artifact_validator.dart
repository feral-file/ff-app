import 'dart:io';

import 'package:app/infra/database/app_database.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite3;

/// Validation metadata captured from a seed SQLite artifact.
class SeedDatabaseArtifactMetadata {
  const SeedDatabaseArtifactMetadata({
    required this.fileSize,
    required this.userVersion,
  });

  final int fileSize;
  final int userVersion;
}

/// Thrown when a downloaded seed SQLite artifact is not safe to install.
class SeedArtifactValidationException implements Exception {
  const SeedArtifactValidationException({
    required this.reasonCode,
    required this.message,
    this.path,
    this.fileSize,
    this.cause,
  });

  final String reasonCode;
  final String message;
  final String? path;
  final int? fileSize;
  final Object? cause;

  @override
  String toString() => 'SeedArtifactValidationException($reasonCode): $message';
}

/// Validates that a downloaded seed artifact is a readable SQLite file whose
/// schema matches the current app reset gate.
class SeedDatabaseArtifactValidator {
  const SeedDatabaseArtifactValidator({
    this.minimumFileSizeBytes = 512,
  });

  static const _sqliteMagic = 'SQLite format 3\u0000';
  final int minimumFileSizeBytes;

  /// Validates the SQLite artifact at [path] and returns metadata for logging.
  SeedDatabaseArtifactMetadata validate(String path) {
    final file = File(path);
    if (!file.existsSync()) {
      throw SeedArtifactValidationException(
        reasonCode: 'missing',
        message: 'Seed artifact not found at $path',
        path: path,
      );
    }

    final fileSize = file.lengthSync();
    if (fileSize < minimumFileSizeBytes) {
      throw SeedArtifactValidationException(
        reasonCode: 'too_small',
        message:
            'Seed artifact is too small for a SQLite database: $fileSize bytes',
        path: path,
        fileSize: fileSize,
      );
    }

    RandomAccessFile? raf;
    try {
      raf = file.openSync();
      final header = raf.readSync(_sqliteMagic.length);
      final magic = String.fromCharCodes(header);
      if (magic != _sqliteMagic) {
        throw SeedArtifactValidationException(
          reasonCode: 'magic_mismatch',
          message: 'Seed artifact header is not SQLite format 3',
          path: path,
          fileSize: fileSize,
        );
      }
    } on SeedArtifactValidationException {
      rethrow;
    } on Object catch (e) {
      throw SeedArtifactValidationException(
        reasonCode: 'header_read_failed',
        message: 'Failed to read seed artifact header',
        path: path,
        fileSize: fileSize,
        cause: e,
      );
    } finally {
      raf?.closeSync();
    }

    sqlite3.Database? db;
    try {
      db = sqlite3.sqlite3.open(path, mode: sqlite3.OpenMode.readOnly);
      final versionRows = db.select('PRAGMA user_version');
      final userVersion = versionRows.isEmpty
          ? 0
          : (versionRows.first.columnAt(0) as int);
      if (!shouldSkipDatabaseResetForSchemaConflict(userVersion, db)) {
        throw SeedArtifactValidationException(
          reasonCode: 'schema_conflict',
          message:
              'Seed artifact schema is incompatible with the current app gate',
          path: path,
          fileSize: fileSize,
        );
      }

      final quickCheckRows = db.select('PRAGMA quick_check');
      final isQuickCheckOk =
          quickCheckRows.isNotEmpty &&
          quickCheckRows.every(
            (row) => row.columnAt(0).toString().toLowerCase() == 'ok',
          );
      if (!isQuickCheckOk) {
        throw SeedArtifactValidationException(
          reasonCode: 'quick_check_failed',
          message: 'Seed artifact quick_check did not return ok',
          path: path,
          fileSize: fileSize,
        );
      }

      return SeedDatabaseArtifactMetadata(
        fileSize: fileSize,
        userVersion: userVersion,
      );
    } on SeedArtifactValidationException {
      rethrow;
    } on Object catch (e) {
      throw SeedArtifactValidationException(
        reasonCode: 'sqlite_open_failed',
        message: 'Failed to open seed artifact as a readable SQLite database',
        path: path,
        fileSize: fileSize,
        cause: e,
      );
    } finally {
      db?.dispose();
    }
  }
}
