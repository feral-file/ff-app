import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:app/infra/config/app_config.dart';
import 'package:app/infra/logging/structured_dio_logging_interceptor.dart';
import 'package:app/infra/services/seed_database_artifact_validator.dart';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class _SeedDatabaseS3Location {
  const _SeedDatabaseS3Location({
    required this.endpointUri,
    required this.objectUri,
    required this.region,
    required this.accessKeyId,
    required this.secretAccessKey,
  });

  factory _SeedDatabaseS3Location.fromConfig({
    required String bucketUrl,
    required String objectKey,
    required String region,
    required String accessKeyId,
    required String secretAccessKey,
  }) {
    final endpointUri = Uri.tryParse(bucketUrl);
    if (endpointUri == null ||
        !endpointUri.hasScheme ||
        endpointUri.host.isEmpty) {
      throw const FormatException('S3_BUCKET is not a valid URL.');
    }

    final normalizedObjectKey = objectKey.trim().replaceFirst(
      RegExp('^/+'),
      '',
    );
    if (normalizedObjectKey.isEmpty) {
      throw const FormatException(
        'S3_SEED_DATABASE_OBJECT_KEY is not configured.',
      );
    }

    final bucketBaseSegments = endpointUri.pathSegments
        .where((segment) => segment.isNotEmpty)
        .toList();
    if (bucketBaseSegments.isEmpty) {
      throw const FormatException(
        'S3_BUCKET must include a bucket name in the path.',
      );
    }

    final objectUri = endpointUri.replace(
      pathSegments: <String>[
        ...bucketBaseSegments,
        ...normalizedObjectKey
            .split('/')
            .where((segment) => segment.isNotEmpty),
      ],
    );

    if (accessKeyId.trim().isEmpty) {
      throw const FormatException('S3_ACCESS_KEY_ID is not configured.');
    }
    if (secretAccessKey.trim().isEmpty) {
      throw const FormatException('S3_SECRET_ACCESS_KEY is not configured.');
    }
    final normalizedRegion = region.trim();
    if (normalizedRegion.isEmpty) {
      throw const FormatException('S3_REGION is not configured.');
    }

    return _SeedDatabaseS3Location(
      endpointUri: endpointUri,
      objectUri: objectUri,
      region: normalizedRegion,
      accessKeyId: accessKeyId.trim(),
      secretAccessKey: secretAccessKey.trim(),
    );
  }

  final Uri endpointUri;
  final Uri objectUri;
  final String region;
  final String accessKeyId;
  final String secretAccessKey;
}

/// Service responsible for downloading and placing the seed database.
///
/// The app never creates an empty database. Flow:
/// 1) Download seed from S3-compatible storage to a temporary file.
/// 2) Validate the artifact before any DB teardown begins.
/// 3) Replace the current database file with a staged, recoverable swap so the
///    previous DB can be restored if IO fails mid-replace.
///
/// On first install the local `dp1_library.sqlite` does not exist until the
/// seed is placed. Call `needsSeedDownload` to determine whether the database
/// file is missing before showing the download screen.
class SeedDatabaseService {
  /// Creates a [SeedDatabaseService] using the provided [Dio] instance.
  SeedDatabaseService({
    Dio? dio,
    DateTime Function()? nowUtc,
    Future<Directory> Function()? temporaryDirectoryProvider,
    int maxDownloadAttempts = 3,
    SeedDatabaseArtifactValidator? artifactValidator,
  }) : _dio = (dio ?? Dio())
         // Intentionally no sentry_dio: seed sync failures are expected offline
         // / infra cases; StructuredDioLoggingInterceptor covers observability.
         ..interceptors.add(
           StructuredDioLoggingInterceptor(
             logger: _log,
             component: 'seed_database',
           ),
         ),
       _nowUtc = nowUtc ?? (() => DateTime.now().toUtc()),
       _maxDownloadAttempts = maxDownloadAttempts < 1 ? 1 : maxDownloadAttempts,
       _temporaryDirectoryProvider =
           temporaryDirectoryProvider ?? getTemporaryDirectory,
       _artifactValidator =
           artifactValidator ?? const SeedDatabaseArtifactValidator();

  static final _log = Logger('SeedDatabaseService');

  /// Per-attempt ceiling for time without receiving body bytes (Dio).
  /// Large seeds can take longer wall-clock; stalls are handled separately via
  /// [_stallWithoutProgress].
  static const Duration _receiveTimeoutPerAttempt = Duration(minutes: 10);

  /// If no bytes arrive for this long, cancel the request and retry (or fail).
  static const Duration _stallWithoutProgress = Duration(seconds: 120);

  final Dio _dio;
  final DateTime Function() _nowUtc;
  final Future<Directory> Function() _temporaryDirectoryProvider;
  final int _maxDownloadAttempts;
  final SeedDatabaseArtifactValidator _artifactValidator;

  /// The canonical database file name used by AppDatabase.
  static const _dbFileName = 'dp1_library.sqlite';

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

  /// Returns true only when the canonical database file exists and passes the
  /// same artifact validation used for downloaded seed files.
  ///
  /// Startup uses this to avoid opening the seed gate on a corrupt local file.
  ///
  /// **Performance note (out of scope for seed-swap PRs):** validation opens
  /// SQLite and runs `PRAGMA quick_check` synchronously on the calling isolate.
  /// Large seeds can add noticeable cold-start or resume latency; a follow-up
  /// change could move this work off the UI isolate or defer it with measured
  /// trade-offs.
  Future<bool> hasUsableLocalDatabase() async {
    final path = await databasePath();
    final canonical = File(path);
    if (!canonical.existsSync()) {
      return false;
    }
    try {
      validateSeedArtifact(path);
      return true;
    } on Object catch (e, st) {
      _log.warning(
        'Canonical seed DB exists but failed validation; keeping seed gate '
        'closed until sync restores a valid artifact.',
        e,
        st,
      );
      return false;
    }
  }

  /// If the process died mid-replace, the canonical DB may be missing while
  /// staged or backup artifacts remain. Restores a usable DB before startup
  /// consumers run (bootstrap opens the seed gate when the file exists).
  ///
  /// Prefers promoting the latest staged artifact (post-validation seed) over
  /// restoring from backup (previous live DB) when both exist.
  Future<bool> repairInterruptedSeedSwapIfNeeded() async {
    final dbPath = await databasePath();
    final resetMarker = File(_resetInProgressMarkerPath(dbPath));
    final swapMarker = File(_swapInProgressMarkerPath(dbPath));
    if (resetMarker.existsSync()) {
      final usable = await hasUsableLocalDatabase();
      final hasSwap = swapMarker.existsSync();
      if (!hasSwap) {
        // Interrupted forget before file deletion: keep marker + DB until the
        // user completes teardown (do not treat "usable" as stale).
        // Marker with no DB/swap: wipe likely finished but [finally] never ran;
        // clear so a fresh bootstrap is not blocked forever.
        if (!usable) {
          _log.warning(
            'Reset cleanup marker with no usable DB and no swap residue; '
            'clearing stale marker.',
          );
          await clearResetCleanupInProgress();
        }
        return false;
      }
      // Swap residue exists: replace lock should serialize reset vs replace;
      // drop the reset marker so interrupted-swap repair can run.
      _log.warning(
        'Reset marker with interrupted swap residue; clearing reset marker so '
        'startup repair can finish the swap.',
      );
      await clearResetCleanupInProgress();
    }
    if (!swapMarker.existsSync()) {
      return false;
    }
    final rawMarkerNonce = swapMarker.readAsStringSync().trim();
    final markerNonce = int.tryParse(rawMarkerNonce);
    if (markerNonce == null) {
      _log.warning(
        'Seed swap marker contains non-numeric nonce "$rawMarkerNonce"; '
        'skip startup repair to avoid restoring an unrelated artifact set.',
      );
      return false;
    }
    final canonical = File(dbPath);
    if (canonical.existsSync()) {
      try {
        validateSeedArtifact(canonical.path);
        await _cleanupTemp(swapMarker.path);
        await _deleteOrphanSeedSwapArtifactFiles(Directory(p.dirname(dbPath)));
        return false;
      } on Object catch (e, st) {
        _log.warning(
          'Canonical seed DB exists but failed validation during startup '
          'repair; attempting recovery from staged/backup artifacts.',
          e,
          st,
        );
      }
    }

    final dbDir = Directory(p.dirname(dbPath));
    if (!dbDir.existsSync()) {
      return false;
    }

    final stageRe = RegExp(
      '^${RegExp.escape(_dbFileName)}\\.stage\\.(\\d+)\$',
    );
    final backupRe = RegExp(
      '^${RegExp.escape(_dbFileName)}\\.backup\\.(\\d+)\$',
    );

    final candidates = <({File file, int nonce, bool isStage})>[];

    for (final entity in dbDir.listSync()) {
      if (entity is! File) continue;
      final name = p.basename(entity.path);
      final stageMatch = stageRe.firstMatch(name);
      if (stageMatch != null) {
        final n = int.tryParse(stageMatch.group(1)!) ?? -1;
        candidates.add((file: entity, nonce: n, isStage: true));
      }
      final backupMatch = backupRe.firstMatch(name);
      if (backupMatch != null) {
        final n = int.tryParse(backupMatch.group(1)!) ?? -1;
        candidates.add((file: entity, nonce: n, isStage: false));
      }
    }

    // Do not delete canonical WAL/SHM here. If the process died after moving
    // the main database aside but before sidecars were backed up, those files
    // may still contain the newest committed pages for the pre-replace DB.
    // Restoring the main file first preserves SQLite's ability to recover that
    // state on the next open.
    candidates.sort((a, b) {
      final nonceCmp = b.nonce.compareTo(a.nonce);
      if (nonceCmp != 0) return nonceCmp;
      if (a.isStage != b.isStage) {
        return a.isStage ? -1 : 1;
      }
      return a.file.path.compareTo(b.file.path);
    });
    final candidatesToTry = candidates
        .where((c) => c.nonce == markerNonce)
        .toList();
    if (candidatesToTry.isEmpty) {
      _log.warning(
        'Seed swap marker nonce=$markerNonce has no matching staged/backup '
        'artifacts; skip startup repair to avoid restoring an unrelated swap.',
      );
      return false;
    }

    for (final candidate in candidatesToTry) {
      final candidatePath = candidate.file.path;
      // Snapshot backup sidecar presence before validation. Validation opens
      // SQLite and may materialize sidecars; restore decisions must reflect
      // the real interrupted-swap artifact layout, not validator side effects.
      final backupWalExistsBeforeValidation =
          !candidate.isStage && File('$candidatePath-wal').existsSync();
      final backupShmExistsBeforeValidation =
          !candidate.isStage && File('$candidatePath-shm').existsSync();
      try {
        validateSeedArtifact(candidatePath);
        if (candidate.isStage) {
          final rollbackDbPath = '$dbPath.rollback.${candidate.nonce}';
          var rollbackMovedIntoPlace = false;
          if (File(dbPath).existsSync()) {
            await _moveFile(sourcePath: dbPath, targetPath: rollbackDbPath);
            rollbackMovedIntoPlace = true;
          }
          try {
            await promoteStagedArtifact(
              stagingPath: candidatePath,
              canonicalPath: dbPath,
            );
          } on Object {
            if (File(rollbackDbPath).existsSync()) {
              await _moveFile(sourcePath: rollbackDbPath, targetPath: dbPath);
              rollbackMovedIntoPlace = false;
            }
            rethrow;
          }
          if (rollbackMovedIntoPlace) {
            await _cleanupTemp(rollbackDbPath);
          }
          try {
            await cleanupCanonicalSidecarsAfterStagedPromotion(dbPath);
          } on Object catch (e, st) {
            _log.warning(
              'Best-effort sidecar cleanup failed after staged promotion.',
              e,
              st,
            );
          }
          _log.warning(
            'Repaired interrupted seed swap: promoted staged artifact '
            '(nonce=${candidate.nonce}).',
          );
        } else {
          final ok = await _restoreFromBackupSet(
            dbPath: dbPath,
            backupMainPath: candidatePath,
            backupWalExists: backupWalExistsBeforeValidation,
            backupShmExists: backupShmExistsBeforeValidation,
          );
          if (ok) {
            await _cleanupTemp(swapMarker.path);
            await _deleteOrphanSeedSwapArtifactFiles(dbDir);
            return true;
          }
          continue;
        }
        await _cleanupTemp(swapMarker.path);
        await _deleteOrphanSeedSwapArtifactFiles(dbDir);
        return true;
      } on Object catch (e, st) {
        _log.severe(
          'Failed to restore seed artifact during startup repair',
          e,
          st,
        );
        continue;
      }
    }

    return false;
  }

  Future<bool> _restoreFromBackupSet({
    required String dbPath,
    required String backupMainPath,
    required bool backupWalExists,
    required bool backupShmExists,
  }) async {
    try {
      final nonce = DateTime.now().microsecondsSinceEpoch;
      final restoreMainPath = '$dbPath.restore.$nonce';
      final restoreWalPath = '$dbPath-wal.restore.$nonce';
      final restoreShmPath = '$dbPath-shm.restore.$nonce';
      final rollbackWalPath = '$dbPath-wal.rollback.$nonce';
      final rollbackShmPath = '$dbPath-shm.rollback.$nonce';
      final backupWalPath = '$backupMainPath-wal';
      final backupShmPath = '$backupMainPath-shm';
      try {
        if (File(backupMainPath).existsSync()) {
          await _moveFile(
            sourcePath: backupMainPath,
            targetPath: restoreMainPath,
          );
        }
        if (backupWalExists) {
          await _moveFile(
            sourcePath: backupWalPath,
            targetPath: restoreWalPath,
          );
        }
        if (backupShmExists) {
          await _moveFile(
            sourcePath: backupShmPath,
            targetPath: restoreShmPath,
          );
        }
      } on Object {
        if (File(restoreMainPath).existsSync()) {
          await _moveFile(
            sourcePath: restoreMainPath,
            targetPath: backupMainPath,
          );
        }
        if (File(restoreWalPath).existsSync()) {
          await _moveFile(
            sourcePath: restoreWalPath,
            targetPath: backupWalPath,
          );
        }
        if (File(restoreShmPath).existsSync()) {
          await _moveFile(
            sourcePath: restoreShmPath,
            targetPath: backupShmPath,
          );
        }
        rethrow;
      }

      final canonicalWalPath = '$dbPath-wal';
      final canonicalShmPath = '$dbPath-shm';
      if (backupWalExists || backupShmExists) {
        final canonicalWalExists = File(canonicalWalPath).existsSync();
        final canonicalShmExists = File(canonicalShmPath).existsSync();
        var canonicalWalMovedToRollback = false;
        var canonicalShmMovedToRollback = false;
        var restoredWalMovedToCanonical = false;
        var restoredShmMovedToCanonical = false;

        // Only move a canonical sidecar into rollback when we have the matching
        // backup sidecar to restore. If the crash left an asymmetric backup
        // (e.g. only `-shm` in backup), moving the surviving canonical `-wal`
        // would discard committed pages that still pair with the backup main.
        try {
          if (backupWalExists && canonicalWalExists) {
            await _moveFile(
              sourcePath: canonicalWalPath,
              targetPath: rollbackWalPath,
            );
            canonicalWalMovedToRollback = true;
          }
          if (backupShmExists && canonicalShmExists) {
            await _moveFile(
              sourcePath: canonicalShmPath,
              targetPath: rollbackShmPath,
            );
            canonicalShmMovedToRollback = true;
          }
          if (backupWalExists && File(restoreWalPath).existsSync()) {
            await _moveFile(
              sourcePath: restoreWalPath,
              targetPath: canonicalWalPath,
            );
            restoredWalMovedToCanonical = true;
          }
          if (backupShmExists && File(restoreShmPath).existsSync()) {
            await _moveFile(
              sourcePath: restoreShmPath,
              targetPath: canonicalShmPath,
            );
            restoredShmMovedToCanonical = true;
          }
          if (File(restoreMainPath).existsSync()) {
            await _replaceFileOverwritingTarget(
              sourcePath: restoreMainPath,
              targetPath: dbPath,
            );
          }
        } on Object {
          // If sidecars were already moved to canonical before the main replace
          // failed, move them back into restore slots so catch cleanup can put
          // the backup set back together deterministically.
          if (restoredWalMovedToCanonical &&
              File(canonicalWalPath).existsSync()) {
            await _moveFile(
              sourcePath: canonicalWalPath,
              targetPath: restoreWalPath,
            );
          }
          if (restoredShmMovedToCanonical &&
              File(canonicalShmPath).existsSync()) {
            await _moveFile(
              sourcePath: canonicalShmPath,
              targetPath: restoreShmPath,
            );
          }
          if (canonicalWalMovedToRollback &&
              File(rollbackWalPath).existsSync()) {
            await _replaceFileOverwritingTarget(
              sourcePath: rollbackWalPath,
              targetPath: canonicalWalPath,
            );
          }
          if (canonicalShmMovedToRollback &&
              File(rollbackShmPath).existsSync()) {
            await _replaceFileOverwritingTarget(
              sourcePath: rollbackShmPath,
              targetPath: canonicalShmPath,
            );
          }
          if (File(restoreMainPath).existsSync()) {
            await _moveFile(
              sourcePath: restoreMainPath,
              targetPath: backupMainPath,
            );
          }
          if (File(restoreWalPath).existsSync()) {
            await _moveFile(
              sourcePath: restoreWalPath,
              targetPath: backupWalPath,
            );
          }
          if (File(restoreShmPath).existsSync()) {
            await _moveFile(
              sourcePath: restoreShmPath,
              targetPath: backupShmPath,
            );
          }
          rethrow;
        } finally {
          await _cleanupTemp(rollbackWalPath);
          await _cleanupTemp(rollbackShmPath);
        }
      } else if (File(restoreMainPath).existsSync()) {
        await _replaceFileOverwritingTarget(
          sourcePath: restoreMainPath,
          targetPath: dbPath,
        );
      }
      _log.warning(
        'Repaired interrupted seed swap: restored canonical DB from backup '
        '(${p.basename(backupMainPath)}).',
      );
      return true;
    } on Object catch (e, st) {
      _log.severe(
        'Failed to restore seed DB from backup during startup repair',
        e,
        st,
      );
      return false;
    }
  }

  Future<void> _deleteOrphanSeedSwapArtifactFiles(Directory dbDir) async {
    for (final entity in dbDir.listSync()) {
      if (entity is! File) continue;
      final name = p.basename(entity.path);
      if (name.startsWith('$_dbFileName.stage.') ||
          name.startsWith('$_dbFileName.backup.')) {
        await _cleanupTemp(entity.path);
        final wal = File('${entity.path}-wal');
        final shm = File('${entity.path}-shm');
        if (wal.existsSync()) await _cleanupTemp(wal.path);
        if (shm.existsSync()) await _cleanupTemp(shm.path);
      }
    }
  }

  Future<void> _deleteSeedSwapArtifactsInDirectory(Directory dbDir) async {
    for (final entity in dbDir.listSync()) {
      if (entity is! File) continue;
      final name = p.basename(entity.path);
      if (name.startsWith('$_dbFileName.stage.') ||
          name.startsWith('$_dbFileName.backup.')) {
        await _cleanupTemp(entity.path);
      }
    }
  }

  /// Best-effort HEAD request for the latest remote seed database ETag.
  ///
  /// Returns empty string when ETag is unavailable.
  Future<String> headRemoteEtag() async {
    final location = _loadS3Location();
    final response = await _dio.headUri<dynamic>(
      location.objectUri,
      options: Options(
        headers: _buildSignedHeaders(
          method: 'HEAD',
          uri: location.objectUri,
          accessKeyId: location.accessKeyId,
          secretAccessKey: location.secretAccessKey,
          region: location.region,
          nowUtc: _nowUtc(),
        ),
      ),
    );
    if (response.statusCode == null ||
        response.statusCode! < 200 ||
        response.statusCode! >= 300) {
      throw SeedDownloadException(
        'Failed to HEAD seed database object: HTTP ${response.statusCode}',
      );
    }
    return _sanitizeEtag(response.headers.value('etag') ?? '');
  }

  /// Downloads the seed database artifact and places it at the canonical
  /// database path.
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

  /// Validates a downloaded seed artifact before the app closes the current DB.
  SeedDatabaseArtifactMetadata validateSeedArtifact(String path) {
    return _artifactValidator.validate(path);
  }

  /// Downloads the remote seed DB to a temporary-file path and returns it.
  Future<String> downloadToTemporaryFile({
    void Function(double progress)? onProgress,
    int? maxBytes,
  }) async {
    final location = _loadS3Location();
    final tempDir = await _temporaryDirectoryProvider();
    final tempPath = p.join(
      tempDir.path,
      'playlist_cache_${DateTime.now().microsecondsSinceEpoch}.sqlite.tmp',
    );

    _log.info(
      'Downloading seed database artifact from ${location.objectUri}',
    );

    try {
      final headers = _buildSignedHeaders(
        method: 'GET',
        uri: location.objectUri,
        accessKeyId: location.accessKeyId,
        secretAccessKey: location.secretAccessKey,
        region: location.region,
        nowUtc: _nowUtc(),
      );
      if (maxBytes != null && maxBytes > 0) {
        headers[HttpHeaders.rangeHeader] = 'bytes=0-${maxBytes - 1}';
      }

      await _downloadWithRetryAndResume(
        uri: location.objectUri,
        tempPath: tempPath,
        headers: headers,
        onProgress: onProgress,
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

  Future<void> _downloadWithRetryAndResume({
    required Uri uri,
    required String tempPath,
    required Map<String, String> headers,
    void Function(double progress)? onProgress,
  }) async {
    DioException? lastDioException;

    for (var attempt = 1; attempt <= _maxDownloadAttempts; attempt++) {
      final targetFile = File(tempPath);
      final resumeFrom = targetFile.existsSync() ? targetFile.lengthSync() : 0;

      final requestHeaders = Map<String, String>.from(headers);
      if (resumeFrom > 0) {
        requestHeaders[HttpHeaders.rangeHeader] = 'bytes=$resumeFrom-';
      }

      final cancelToken = CancelToken();
      Timer? stallTimer;

      void disarmStallTimer() {
        stallTimer?.cancel();
        stallTimer = null;
      }

      void armStallTimer() {
        disarmStallTimer();
        stallTimer = Timer(_stallWithoutProgress, () {
          if (!cancelToken.isCancelled) {
            cancelToken.cancel(
              'seed_download_stall: no progress for '
              '${_stallWithoutProgress.inSeconds}s',
            );
          }
        });
      }

      try {
        armStallTimer();
        await _dio.download(
          uri.toString(),
          tempPath,
          cancelToken: cancelToken,
          onReceiveProgress: (received, total) {
            armStallTimer();
            if (onProgress == null || total <= 0) {
              return;
            }
            final downloaded = resumeFrom + received;
            final expectedTotal = resumeFrom + total;
            onProgress((downloaded / expectedTotal).clamp(0.0, 1.0));
          },
          options: Options(
            headers: requestHeaders,
            receiveTimeout: _receiveTimeoutPerAttempt,
            sendTimeout: const Duration(seconds: 30),
          ),
          fileAccessMode: resumeFrom > 0
              ? FileAccessMode.append
              : FileAccessMode.write,
        );
        return;
      } on DioException catch (e) {
        lastDioException = e;

        if (attempt >= _maxDownloadAttempts || !isRetryableDownloadError(e)) {
          rethrow;
        }

        final delayMs = 500 * (1 << (attempt - 1));
        // Do not attach the exception: LoggingIntegration sends warnings with
        // errors to Sentry.
        _log.warning(
          'Seed download attempt $attempt/$_maxDownloadAttempts failed; '
          'retrying in ${delayMs}ms (${e.type}: ${e.message})',
        );
        await Future<void>.delayed(Duration(milliseconds: delayMs));
      } finally {
        disarmStallTimer();
      }
    }

    if (lastDioException != null) {
      throw lastDioException;
    }
  }

  /// Returns whether the failure is safe to retry for large file downloads.
  @visibleForTesting
  static bool isRetryableDownloadError(DioException exception) {
    if (exception.type == DioExceptionType.connectionTimeout ||
        exception.type == DioExceptionType.sendTimeout ||
        exception.type == DioExceptionType.receiveTimeout ||
        exception.type == DioExceptionType.connectionError ||
        exception.type == DioExceptionType.unknown) {
      return true;
    }

    if (exception.type == DioExceptionType.badResponse) {
      final statusCode = exception.response?.statusCode ?? 0;
      return statusCode == 408 ||
          statusCode == 425 ||
          statusCode == 429 ||
          statusCode >= 500;
    }

    // Stall watchdog: cancelToken.cancel(...) — treat like a transient drop.
    if (exception.type == DioExceptionType.cancel) {
      final msg = exception.message ?? '';
      return msg.contains('seed_download_stall');
    }

    return false;
  }

  /// Replaces the live SQLite database file with a validated temp seed file.
  ///
  /// The replace remains recoverable until the staged artifact has been
  /// promoted to the canonical path. If promotion fails after the old DB is
  /// moved aside, this method restores the previous main DB and sidecars.
  Future<void> replaceDatabaseFromTemporaryFile(
    String tempPath, {
    SeedDatabaseArtifactMetadata? prevalidatedArtifact,
  }) async {
    // Fresh sequence for each replace so debug hooks (tests) match call order.
    SeedDatabaseService.moveFileInvocationCountForTest = 0;
    final dbPath = await databasePath();
    final tempFile = File(tempPath);
    if (!tempFile.existsSync()) {
      throw SeedDownloadException('Temporary seed file not found: $tempPath');
    }

    final dbDir = p.dirname(dbPath);
    final nonce = DateTime.now().microsecondsSinceEpoch;
    final stagingPath = p.join(dbDir, 'dp1_library.sqlite.stage.$nonce');
    final backupPath = p.join(dbDir, 'dp1_library.sqlite.backup.$nonce');
    final walPath = '$dbPath-wal';
    final shmPath = '$dbPath-shm';
    final backupWalPath = '$backupPath-wal';
    final backupShmPath = '$backupPath-shm';
    final swapMarkerPath = _swapInProgressMarkerPath(dbPath);
    var promotedCanonical = false;
    // Only clear canonical paths and restore from backup after the live DB file
    // was successfully moved aside; otherwise a failure during staging would
    // delete the still-readable database (issue #337 recoverable-swap gap).
    var mainDatabaseBackedUp = false;
    // Track WAL/SHM moves separately: rollback must not delete canonical -wal/-shm
    // unless those files were actually staged to backup. If main moved but a
    // sidecar move failed, the canonical sidecar can still hold committed data.
    var walBackedUp = false;
    var shmBackedUp = false;

    try {
      await File(swapMarkerPath).writeAsString('$nonce');
      final metadata = prevalidatedArtifact ?? validateSeedArtifact(tempPath);
      await materializeValidatedArtifactInDatabaseDirectory(
        sourcePath: tempPath,
        stagingPath: stagingPath,
      );
      _log.info(
        'Seed database artifact validated; staging replace '
        '(bytes=${metadata.fileSize}, userVersion=${metadata.userVersion})',
      );

      await moveExistingDatabaseToBackup(
        canonicalPath: dbPath,
        backupPath: backupPath,
      );
      // True only when a live main DB file existed and was moved aside (backup
      // file exists). First install has no canonical file — do not treat as
      // backed up so catch does not run destructive restore without a backup.
      mainDatabaseBackedUp = File(backupPath).existsSync();
      await moveExistingDatabaseToBackup(
        canonicalPath: walPath,
        backupPath: backupWalPath,
      );
      walBackedUp = File(backupWalPath).existsSync();
      await moveExistingDatabaseToBackup(
        canonicalPath: shmPath,
        backupPath: backupShmPath,
      );
      shmBackedUp = File(backupShmPath).existsSync();

      await promoteStagedArtifact(
        stagingPath: stagingPath,
        canonicalPath: dbPath,
      );
      promotedCanonical = true;

      await _cleanupSwapArtifactsBestEffort(
        stagingPath: stagingPath,
        backupPath: backupPath,
        backupWalPath: backupWalPath,
        backupShmPath: backupShmPath,
      );
      await _cleanupTemp(swapMarkerPath);
      _log.info('Seed database placed at $dbPath');
    } on Object catch (e, st) {
      _log.severe('Failed to replace seed database file', e, st);
      if (!promotedCanonical) {
        // Restore each path that was successfully moved to backup, even when
        // the main file was already absent (orphan WAL/SHM on canonical path).
        if (mainDatabaseBackedUp) {
          await _deleteFileIfExists(dbPath);
          await _restoreBackupIfNeeded(
            backupPath: backupPath,
            canonicalPath: dbPath,
          );
        }
        if (walBackedUp) {
          await _deleteFileIfExists(walPath);
          await _restoreBackupIfNeeded(
            backupPath: backupWalPath,
            canonicalPath: walPath,
          );
        }
        if (shmBackedUp) {
          await _deleteFileIfExists(shmPath);
          await _restoreBackupIfNeeded(
            backupPath: backupShmPath,
            canonicalPath: shmPath,
          );
        }
      }
      final stagedArtifactExists = File(stagingPath).existsSync();
      // Failed staged artifacts are never reused by later sync attempts; clean
      // them up even on first install so repeated failures do not accumulate
      // orphaned SQLite files in the documents directory.
      if (mainDatabaseBackedUp || promotedCanonical || stagedArtifactExists) {
        await _cleanupTemp(stagingPath);
      }
      await _cleanupTemp(swapMarkerPath);
      await _cleanupTemp(tempPath);
      rethrow;
    }
  }

  /// Deletes the SQLite main database file and sidecar WAL/SHM files.
  Future<void> deleteDatabaseFiles() async {
    final dbPath = await databasePath();
    final paths = <String>[
      dbPath,
      '$dbPath-wal',
      '$dbPath-shm',
    ];
    for (final path in paths) {
      final file = File(path);
      if (file.existsSync()) {
        await file.delete();
      }
    }
    final dbDir = Directory(p.dirname(dbPath));
    if (dbDir.existsSync()) {
      await _cleanupTemp(_swapInProgressMarkerPath(dbPath));
      await _deleteOrphanSeedSwapArtifactFiles(dbDir);
      await _deleteSeedSwapArtifactsInDirectory(dbDir);
    }
  }

  /// Marks that a reset/forget teardown is in progress so startup repair does
  /// not resurrect a DB that the app is intentionally deleting.
  Future<void> markResetCleanupInProgress() async {
    final dbPath = await databasePath();
    await File(_resetInProgressMarkerPath(dbPath)).writeAsString('1');
  }

  /// Clears the reset/forget teardown marker after cleanup completes.
  Future<void> clearResetCleanupInProgress() async {
    final dbPath = await databasePath();
    await _cleanupTemp(_resetInProgressMarkerPath(dbPath));
  }

  /// Returns true while an intentional reset/forget teardown is in progress.
  ///
  /// Startup repair must not reopen the seed gate in this state, even if the
  /// canonical database file is still present and validates.
  Future<bool> isResetCleanupInProgress() async {
    final dbPath = await databasePath();
    return File(_resetInProgressMarkerPath(dbPath)).existsSync();
  }

  Future<void> _cleanupTemp(String tempPath) async {
    final f = File(tempPath);
    if (f.existsSync()) {
      try {
        await f.delete();
      } on Object catch (_) {}
    }
  }

  /// Best-effort cleanup for downloaded seed artifacts that never reached the
  /// staged swap path. Missing files are expected after successful staging.
  Future<void> cleanupTemporarySeedArtifact(String tempPath) async {
    await _cleanupTemp(tempPath);
  }

  @visibleForTesting
  /// Moves the validated temp artifact into the DB directory before promote.
  Future<void> materializeValidatedArtifactInDatabaseDirectory({
    required String sourcePath,
    required String stagingPath,
  }) async {
    await _moveFile(sourcePath: sourcePath, targetPath: stagingPath);
  }

  @visibleForTesting
  /// Moves the current canonical DB file or sidecar to a backup location.
  Future<void> moveExistingDatabaseToBackup({
    required String canonicalPath,
    required String backupPath,
  }) async {
    final file = File(canonicalPath);
    if (!file.existsSync()) return;
    await _moveFile(sourcePath: canonicalPath, targetPath: backupPath);
  }

  @visibleForTesting
  /// Promotes the staged artifact into the canonical DB path.
  Future<void> promoteStagedArtifact({
    required String stagingPath,
    required String canonicalPath,
  }) async {
    await _replaceFileOverwritingTarget(
      sourcePath: stagingPath,
      targetPath: canonicalPath,
    );
  }

  Future<void> _restoreBackupIfNeeded({
    required String backupPath,
    required String canonicalPath,
  }) async {
    final backupFile = File(backupPath);
    if (!backupFile.existsSync()) return;
    await _replaceFileOverwritingTarget(
      sourcePath: backupPath,
      targetPath: canonicalPath,
    );
  }

  /// Replaces [targetPath] with [sourcePath] without depending on rename
  /// overwrite semantics. If the source move fails, the original target is
  /// restored from a rollback file so a failed repair cannot strand startup.
  Future<void> _replaceFileOverwritingTarget({
    required String sourcePath,
    required String targetPath,
  }) async {
    final target = File(targetPath);
    if (!target.existsSync()) {
      await _moveFile(sourcePath: sourcePath, targetPath: targetPath);
      return;
    }

    final rollbackPath =
        '$targetPath.rollback.${DateTime.now().microsecondsSinceEpoch}';
    await _moveFile(sourcePath: targetPath, targetPath: rollbackPath);
    try {
      await _moveFile(sourcePath: sourcePath, targetPath: targetPath);
    } on Object {
      if (File(rollbackPath).existsSync()) {
        await _moveFile(sourcePath: rollbackPath, targetPath: targetPath);
      }
      rethrow;
    } finally {
      await _cleanupTemp(rollbackPath);
    }
  }

  Future<void> _deleteFileIfExists(String path) async {
    final file = File(path);
    if (!file.existsSync()) return;
    await file.delete();
  }

  /// Cleans canonical sidecars after staged promotion during startup repair.
  ///
  /// This path is best-effort: once the staged main DB is promoted, failing to
  /// delete stale sidecars must not fall through to a backup candidate and
  /// overwrite the newly promoted canonical artifact.
  @visibleForTesting
  Future<void> cleanupCanonicalSidecarsAfterStagedPromotion(
    String dbPath,
  ) async {
    for (final path in ['$dbPath-wal', '$dbPath-shm']) {
      try {
        await _deleteFileIfExists(path);
      } on Object catch (e, st) {
        _log.warning(
          'Best-effort sidecar cleanup failed after staged promotion: $path',
          e,
          st,
        );
      }
    }
  }

  Future<void> _cleanupSwapArtifactsBestEffort({
    required String stagingPath,
    required String backupPath,
    required String backupWalPath,
    required String backupShmPath,
  }) async {
    for (final path in [
      stagingPath,
      backupPath,
      backupWalPath,
      backupShmPath,
    ]) {
      try {
        await _cleanupTemp(path);
      } on Object catch (e, st) {
        _log.warning('Best-effort seed swap cleanup failed for $path', e, st);
      }
    }
  }

  String _swapInProgressMarkerPath(String dbPath) => '$dbPath.swap_in_progress';

  String _resetInProgressMarkerPath(String dbPath) =>
      '$dbPath.reset_in_progress';

  /// Test-only: resets [moveFileInvocationCountForTest] and
  /// [debugSimulateRenameFailureOnMoveCallOneBased].
  @visibleForTesting
  static void resetMoveFileDebugForTest() {
    moveFileInvocationCountForTest = 0;
    debugSimulateRenameFailureOnMoveCallOneBased = null;
    debugSimulateDeleteFailureAfterCopyMove = false;
  }

  /// When true, the copy/delete fallback path throws after a successful copy
  /// and before deleting the source file, exercising undo of the partial
  /// target write.
  @visibleForTesting
  static bool debugSimulateDeleteFailureAfterCopyMove = false;

  /// 1-based index into [moveFileInvocationCountForTest] for the current
  /// replace: when set, that move call throws before rename so the
  /// copy/delete fallback runs (regression: backup exists after fallback).
  @visibleForTesting
  static int? debugSimulateRenameFailureOnMoveCallOneBased;

  /// Current [replaceDatabaseFromTemporaryFile] move step (1-based), for tests.
  @visibleForTesting
  static int moveFileInvocationCountForTest = 0;

  Future<void> _moveFile({
    required String sourcePath,
    required String targetPath,
  }) async {
    final source = File(sourcePath);
    if (!source.existsSync()) {
      throw SeedDownloadException('File not found while moving: $sourcePath');
    }

    try {
      SeedDatabaseService.moveFileInvocationCountForTest++;
      if (debugSimulateRenameFailureOnMoveCallOneBased != null &&
          SeedDatabaseService.moveFileInvocationCountForTest ==
              debugSimulateRenameFailureOnMoveCallOneBased) {
        throw FileSystemException(
          'simulated rename failure for test',
          sourcePath,
        );
      }
      await source.rename(targetPath);
      return;
    } on FileSystemException {
      await source.copy(targetPath);
      try {
        if (debugSimulateDeleteFailureAfterCopyMove) {
          throw FileSystemException(
            'simulated delete failure after copy',
            sourcePath,
          );
        }
        await source.delete();
      } on Object {
        // Undo partial fallback: if the source could not be removed, remove the
        // copy so we do not strand duplicate paths and confuse rollback flags.
        try {
          await File(targetPath).delete();
        } on Object catch (_) {}
        rethrow;
      }
    }
  }

  String _sanitizeEtag(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return '';
    return trimmed.replaceAll('"', '');
  }

  _SeedDatabaseS3Location _loadS3Location() {
    return _SeedDatabaseS3Location.fromConfig(
      bucketUrl: AppConfig.s3BucketUrl,
      objectKey: AppConfig.s3SeedDatabaseObjectKey,
      region: AppConfig.s3Region,
      accessKeyId: AppConfig.s3AccessKeyId,
      secretAccessKey: AppConfig.s3SecretAccessKey,
    );
  }

  /// Parses and resolves the full object URI for S3-compatible seed artifacts.
  @visibleForTesting
  static Uri parseObjectUriForTesting({
    required String bucketUrl,
    required String objectKey,
    String region = 'auto',
    String accessKeyId = 'test-access-key',
    String secretAccessKey = 'test-secret-key',
  }) {
    return _SeedDatabaseS3Location.fromConfig(
      bucketUrl: bucketUrl,
      objectKey: objectKey,
      region: region,
      accessKeyId: accessKeyId,
      secretAccessKey: secretAccessKey,
    ).objectUri;
  }

  /// Builds AWS SigV4 headers for `HEAD`/`GET` S3-compatible requests.
  @visibleForTesting
  static Map<String, String> buildSignedHeadersForTesting({
    required String method,
    required Uri uri,
    required String accessKeyId,
    required String secretAccessKey,
    required String region,
    required DateTime nowUtc,
  }) {
    return _buildSignedHeaders(
      method: method,
      uri: uri,
      accessKeyId: accessKeyId,
      secretAccessKey: secretAccessKey,
      region: region,
      nowUtc: nowUtc,
    );
  }

  static Map<String, String> _buildSignedHeaders({
    required String method,
    required Uri uri,
    required String accessKeyId,
    required String secretAccessKey,
    required String region,
    required DateTime nowUtc,
  }) {
    final amzDate = _formatAmzDate(nowUtc);
    final shortDate = amzDate.substring(0, 8);
    const service = 's3';
    const algorithm = 'AWS4-HMAC-SHA256';
    const payloadHash = 'UNSIGNED-PAYLOAD';

    final canonicalUri = uri.path.isEmpty ? '/' : uri.path;
    final canonicalQuery = _canonicalQueryString(uri);
    final host = _hostHeaderValue(uri);
    final canonicalHeaders = StringBuffer()
      ..writeln('host:$host')
      ..writeln('x-amz-content-sha256:$payloadHash')
      ..writeln('x-amz-date:$amzDate');
    const signedHeaders = 'host;x-amz-content-sha256;x-amz-date';

    final canonicalRequest =
        '${method.toUpperCase()}\n'
        '$canonicalUri\n'
        '$canonicalQuery\n'
        '$canonicalHeaders\n'
        '$signedHeaders\n'
        '$payloadHash';

    final credentialScope = '$shortDate/$region/$service/aws4_request';
    final canonicalRequestHash = _sha256Hex(canonicalRequest);
    final stringToSign =
        '$algorithm\n$amzDate\n$credentialScope\n$canonicalRequestHash';
    final signingKey = _getSignatureKey(
      secretAccessKey: secretAccessKey,
      shortDate: shortDate,
      region: region,
      service: service,
    );
    final signature = _hmacSha256Hex(signingKey, stringToSign);

    final authorization =
        '$algorithm Credential=$accessKeyId/$credentialScope, '
        'SignedHeaders=$signedHeaders, Signature=$signature';

    return <String, String>{
      HttpHeaders.hostHeader: host,
      'x-amz-date': amzDate,
      'x-amz-content-sha256': payloadHash,
      HttpHeaders.authorizationHeader: authorization,
    };
  }

  static String _formatAmzDate(DateTime utc) {
    final year = utc.year.toString().padLeft(4, '0');
    final month = utc.month.toString().padLeft(2, '0');
    final day = utc.day.toString().padLeft(2, '0');
    final hour = utc.hour.toString().padLeft(2, '0');
    final minute = utc.minute.toString().padLeft(2, '0');
    final second = utc.second.toString().padLeft(2, '0');
    return '$year$month$day'
        'T$hour$minute$second'
        'Z';
  }

  static List<int> _getSignatureKey({
    required String secretAccessKey,
    required String shortDate,
    required String region,
    required String service,
  }) {
    final kDate = _hmacSha256(utf8.encode('AWS4$secretAccessKey'), shortDate);
    final kRegion = _hmacSha256(kDate, region);
    final kService = _hmacSha256(kRegion, service);
    return _hmacSha256(kService, 'aws4_request');
  }

  static List<int> _hmacSha256(List<int> key, String data) {
    return Hmac(sha256, key).convert(utf8.encode(data)).bytes;
  }

  static String _hmacSha256Hex(List<int> key, String data) {
    return Hmac(sha256, key).convert(utf8.encode(data)).toString();
  }

  static String _sha256Hex(String data) {
    return sha256.convert(utf8.encode(data)).toString();
  }

  static String _canonicalQueryString(Uri uri) {
    if (uri.queryParametersAll.isEmpty) return '';
    final entries = <MapEntry<String, String>>[];
    for (final entry in uri.queryParametersAll.entries) {
      final key = Uri.encodeQueryComponent(entry.key);
      final values = entry.value;
      if (values.isEmpty) {
        entries.add(MapEntry(key, ''));
        continue;
      }
      for (final value in values) {
        entries.add(MapEntry(key, Uri.encodeQueryComponent(value)));
      }
    }
    entries.sort((a, b) {
      final byKey = a.key.compareTo(b.key);
      if (byKey != 0) return byKey;
      return a.value.compareTo(b.value);
    });
    return entries.map((entry) => '${entry.key}=${entry.value}').join('&');
  }

  static String _hostHeaderValue(Uri uri) {
    if (uri.hasPort && uri.port != (uri.scheme == 'https' ? 443 : 80)) {
      return '${uri.host}:${uri.port}';
    }
    return uri.host;
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
