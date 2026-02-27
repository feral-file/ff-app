import 'dart:io';

import 'package:dio/dio.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// URL of the pre-built seed SQLite database hosted on Cloudflare R2.
const seedDatabaseUrl =
    'https://pub-abf6497cfff5446aac525deca175e505.r2.dev/ff_feed_indexer_seed.sqlite';

/// Service responsible for downloading and placing the seed database.
///
/// On first install the local `playlist_cache.sqlite` does not exist.
/// Calling `downloadAndPlace` fetches the seed from the CDN and writes it
/// to the correct path, so Drift opens it on the next DB operation instead
/// of creating an empty database.
///
/// Call `needsSeedDownload` to determine whether the database file is missing
/// before showing the download screen.
class SeedDatabaseService {
  /// Creates a [SeedDatabaseService] using the provided [Dio] instance.
  SeedDatabaseService({Dio? dio}) : _dio = dio ?? Dio();

  static final _log = Logger('SeedDatabaseService');

  final Dio _dio;

  /// The canonical database file name used by AppDatabase.
  static const _dbFileName = 'playlist_cache.sqlite';

  /// Returns the absolute path where the database should live.
  Future<String> databasePath() async {
    final dir = await getApplicationDocumentsDirectory();
    return p.join(dir.path, _dbFileName);
  }

  /// Whether the database file is absent and the seed should be downloaded.
  Future<bool> needsSeedDownload() async {
    final path = await databasePath();
    return !File(path).existsSync();
  }

  /// Returns true when the SQLite seed database file already exists.
  Future<bool> hasLocalDatabase() async {
    final path = await databasePath();
    return File(path).existsSync();
  }

  /// Best-effort HEAD request for the latest remote seed database ETag.
  ///
  /// Returns empty string when ETag is unavailable.
  Future<String> headRemoteEtag() async {
    final response = await _dio.headUri<dynamic>(Uri.parse(seedDatabaseUrl));
    if (response.statusCode == null ||
        response.statusCode! < 200 ||
        response.statusCode! >= 300) {
      throw SeedDownloadException(
        'Failed to HEAD seed database: HTTP ${response.statusCode}',
      );
    }
    return _sanitizeEtag(response.headers.value('etag') ?? '');
  }

  /// Downloads the seed database from [seedDatabaseUrl] and places it at the
  /// canonical database path.
  ///
  /// [onProgress] receives a value in [0.0, 1.0] as bytes arrive.
  /// Throws on network or IO failure; the caller should handle errors and allow
  /// the user to retry or skip (the app will start with an empty database).
  Future<void> downloadAndPlace({
    void Function(double progress)? onProgress,
  }) async {
    final tempPath = await downloadToTemporaryFile(onProgress: onProgress);
    await replaceDatabaseFromTemporaryFile(tempPath);
  }

  /// Downloads the remote seed DB to a temporary-file path and returns it.
  Future<String> downloadToTemporaryFile({
    void Function(double progress)? onProgress,
  }) async {
    final tempDir = await getTemporaryDirectory();
    final tempPath = p.join(
      tempDir.path,
      'playlist_cache_${DateTime.now().microsecondsSinceEpoch}.sqlite.tmp',
    );

    _log.info('Downloading seed database from $seedDatabaseUrl');

    try {
      await _dio.download(
        seedDatabaseUrl,
        tempPath,
        onReceiveProgress: (received, total) {
          if (total > 0 && onProgress != null) {
            onProgress((received / total).clamp(0.0, 1.0));
          }
        },
        options: Options(
          // 10-minute timeout for a ~300 MB file on slow connections.
          receiveTimeout: const Duration(minutes: 10),
          sendTimeout: const Duration(seconds: 30),
        ),
      );

      final tempFile = File(tempPath);
      if (!tempFile.existsSync()) {
        throw const SeedDownloadException('Downloaded file not found');
      }
      return tempPath;
    } on DioException catch (e, st) {
      _log.severe('Seed download failed (Dio)', e, st);
      await _cleanupTemp(tempPath);
      throw SeedDownloadException('Download failed: ${e.message}', cause: e);
    } on Object catch (e, st) {
      _log.severe('Seed download failed', e, st);
      await _cleanupTemp(tempPath);
      rethrow;
    }
  }

  /// Replaces the live SQLite database file with a downloaded temp seed file.
  Future<void> replaceDatabaseFromTemporaryFile(String tempPath) async {
    final dbPath = await databasePath();
    final tempFile = File(tempPath);
    if (!tempFile.existsSync()) {
      throw SeedDownloadException('Temporary seed file not found: $tempPath');
    }
    try {
      final dbFile = File(dbPath);
      if (dbFile.existsSync()) {
        await dbFile.delete();
      }
      final walFile = File('$dbPath-wal');
      if (walFile.existsSync()) {
        await walFile.delete();
      }
      final shmFile = File('$dbPath-shm');
      if (shmFile.existsSync()) {
        await shmFile.delete();
      }

      await tempFile.rename(dbPath);
      _log.info('Seed database placed at $dbPath');
    } on Object catch (e, st) {
      _log.severe('Failed to replace seed database file', e, st);
      await _cleanupTemp(tempPath);
      rethrow;
    }
  }

  /// Deletes the SQLite main database file and sidecar WAL/SHM files.
  Future<void> deleteDatabaseFiles() async {
    final dbPath = await databasePath();
    final paths = <String>[dbPath, '$dbPath-wal', '$dbPath-shm'];
    for (final path in paths) {
      final file = File(path);
      if (file.existsSync()) {
        await file.delete();
      }
    }
  }

  Future<void> _cleanupTemp(String tempPath) async {
    final f = File(tempPath);
    if (f.existsSync()) {
      try {
        await f.delete();
      } on Object catch (_) {}
    }
  }

  String _sanitizeEtag(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return '';
    return trimmed.replaceAll('"', '');
  }
}

/// Thrown when [SeedDatabaseService.downloadAndPlace] fails.
class SeedDownloadException implements Exception {
  /// Creates a [SeedDownloadException].
  const SeedDownloadException(this.message, {this.cause});

  /// Human-readable description.
  final String message;

  /// Underlying exception, if any.
  final Object? cause;

  @override
  String toString() => 'SeedDownloadException: $message';
}
