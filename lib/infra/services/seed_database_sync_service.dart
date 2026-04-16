import 'dart:io';

import 'package:app/infra/services/seed_database_artifact_validator.dart';
import 'package:app/infra/services/seed_database_service.dart';
import 'package:dio/dio.dart';
import 'package:logging/logging.dart';
import 'package:synchronized/synchronized.dart';

/// Syncs the local seed database file using remote ETag comparison.
///
/// The app never creates a database; only downloads and replaces. Flow:
/// 1) HEAD remote seed URL and read ETag.
/// 2) Compare against locally persisted ETag in ObjectBox config.
/// 3) If changed (or no local DB), download to temp file.
/// 4) Validate the temp artifact before any DB teardown begins.
/// 5) `beforeReplace` — callback only; caller prepares (e.g. close DB). Does
///    not perform replace. Must not delete files;
///    `replaceDatabaseFromTemporaryFile` owns the recoverable swap.
/// 6) `replaceDatabaseFromTemporaryFile` — the actual replace (stage, backup,
///    promote, restore-on-failure).
/// 7) `afterReplace` — callback only; caller rebinds (e.g. invalidate
///    providers).
class SeedDatabaseSyncService {
  /// Creates a seed database sync orchestrator.
  SeedDatabaseSyncService({
    required SeedDatabaseService seedDatabaseService,
    required String Function() loadLocalEtag,
    required void Function(String etag) saveLocalEtag,
    Logger? logger,
  }) : _seedDatabaseService = seedDatabaseService,
       _loadLocalEtag = loadLocalEtag,
       _saveLocalEtag = saveLocalEtag,
       _log = logger ?? Logger('SeedDatabaseSyncService');

  final SeedDatabaseService _seedDatabaseService;
  final String Function() _loadLocalEtag;
  final void Function(String etag) _saveLocalEtag;
  final Logger _log;

  /// Serializes the replace phase so concurrent syncs do not race on
  /// beforeReplace → replace → afterReplace.
  final _replaceLock = Lock();

  /// Runs [action] while holding the replace lock. Cleanup flows that delete
  /// seed artifacts must go through the same lock so they cannot remove the
  /// only recoverable swap files while a replace is mid-flight.
  Future<T> runWithReplaceLock<T>(Future<T> Function() action) {
    return _replaceLock.synchronized(action);
  }

  /// Syncs seed DB from remote.
  ///
  /// When `forceReplace` is false (default), performs ETag-based conditional
  /// sync: downloads only when ETag differs or no local DB exists.
  ///
  /// When `forceReplace` is true, skips ETag check and always downloads.
  ///
  /// `onDownloadStarted` is invoked whenever a download will occur. Receives
  /// `hasLocalDatabase`, `localEtag`, and `remoteEtag` so the caller can
  /// decide whether to emit syncing status (e.g. only when hasLocalDatabase is
  /// false). Remote ETag is always fetched via HEAD before download.
  ///
  /// `isSessionActive` when provided is checked before the replace phase
  /// starts. Once `beforeReplace` begins, the sync must finish replace +
  /// rebind so the app is not left with a closed DB and no reconnect path.
  ///
  /// `beforeReplace` and `afterReplace` are callbacks only; they do not own
  /// the file swap logic. `beforeReplace` should prepare (e.g. close DB) only
  /// after the temp artifact has already validated. `afterReplace` should
  /// rebind (e.g. invalidate providers).
  Future<bool> sync({
    required Future<void> Function() beforeReplace,
    required Future<void> Function() afterReplace,
    bool forceReplace = false,
    void Function({
      required bool hasLocalDatabase,
      String? localEtag,
      String? remoteEtag,
    })?
    onDownloadStarted,
    void Function(double progress)? onProgress,
    bool failSilently = false,
    bool Function()? isSessionActive,
  }) async {
    String? tempPath;
    try {
      final hasLocalDatabase = await _seedDatabaseService.hasLocalDatabase();
      final hasUsableLocalDatabase =
          hasLocalDatabase &&
          await _seedDatabaseService.hasUsableLocalDatabase();

      bool shouldDownload;
      String? localEtag;
      String? remoteEtag;

      try {
        if (forceReplace) {
          shouldDownload = true;
          final loaded = _loadLocalEtag();
          final headEtag = await _seedDatabaseService.headRemoteEtag();
          localEtag = loaded.isEmpty ? null : loaded;
          remoteEtag = headEtag.isEmpty ? null : headEtag;
        } else {
          final loaded = _loadLocalEtag();
          final headEtag = await _seedDatabaseService.headRemoteEtag();
          shouldDownload =
              !hasUsableLocalDatabase ||
              (headEtag.isNotEmpty && headEtag != loaded);

          _log.info(
            'Seed sync pre-check: hasLocal=$hasLocalDatabase, '
            'hasUsableLocal=$hasUsableLocalDatabase, '
            'localEtag=${loaded.isEmpty ? '<empty>' : loaded}, '
            'remoteEtag=${headEtag.isEmpty ? '<empty>' : headEtag}, '
            'shouldReplace=$shouldDownload',
          );
          if (!shouldDownload) {
            _log.fine('Seed database ETag unchanged; skipping download.');
            return false;
          }

          localEtag = loaded.isEmpty ? null : loaded;
          remoteEtag = headEtag.isEmpty ? null : headEtag;
        }
      } on Exception catch (e, st) {
        _log.warning(
          'Seed sync ETag check failed; '
          'falling back to shouldDownload= '
          '(forceReplace || no usable local DB).',
          e,
          st,
        );
        shouldDownload = forceReplace || !hasUsableLocalDatabase;
        localEtag = null;
        remoteEtag = null;
      }

      if (!shouldDownload) {
        return false;
      }

      _log.info(
        forceReplace
            ? 'Seed DB force-replace; downloading latest seed snapshot.'
            : 'Seed DB refresh needed; downloading latest seed snapshot.',
      );
      onDownloadStarted?.call(
        hasLocalDatabase: hasLocalDatabase,
        localEtag: localEtag,
        remoteEtag: remoteEtag,
      );

      tempPath = await _seedDatabaseService.downloadToTemporaryFile(
        onProgress: onProgress,
      );
      final metadata = _seedDatabaseService.validateSeedArtifact(tempPath);
      _log.info(
        'Seed database artifact preflight passed '
        '(bytes=${metadata.fileSize}, userVersion=${metadata.userVersion})',
      );

      // After beforeReplace, must finish replace+afterReplace (reconnect path).
      // Early return would leave DB closed; if newer session fails, nothing
      // restores readiness. Only check isSessionActive before beforeReplace.
      final result = await runWithReplaceLock(() async {
        if (isSessionActive != null && !isSessionActive()) return false;
        await beforeReplace();

        await _seedDatabaseService.replaceDatabaseFromTemporaryFile(
          tempPath!,
          prevalidatedArtifact: metadata,
        );

        if (remoteEtag != null && remoteEtag.isNotEmpty) {
          _saveLocalEtag(remoteEtag);
        }

        await afterReplace();
        return true;
      });
      if (!result) {
        try {
          await File(tempPath).delete();
        } on Object catch (_) {
          // Ignore; temp dir may be cleaned by OS
        }
        return false;
      }
      _log.info(
        forceReplace
            ? 'Seed database force-replaced.'
            : hasLocalDatabase
            ? 'Seed database updated from remote ETag change.'
            : 'Seed database installed.',
      );
      return true;
    } on FormatException catch (e) {
      if (!failSilently) rethrow;
      // Message-only: avoid LoggingIntegration → Sentry for config issues.
      _log.warning(
        'Seed database sync skipped due to invalid seed configuration '
        '(S3_*): $e',
      );
      return false;
    } on DioException catch (e) {
      if (!failSilently) rethrow;
      _log.warning(
        'Seed database sync skipped (network failure): ${e.message}',
      );
      return false;
    } on SeedArtifactValidationException catch (e) {
      if (!failSilently) rethrow;
      _log.warning(
        'Seed database sync skipped (artifact validation failed: '
        '${e.reasonCode}): $e',
      );
      return false;
    } on SocketException catch (e) {
      if (!failSilently) rethrow;
      _log.warning('Seed database sync skipped (offline): $e');
      return false;
    } on SeedDownloadException catch (e) {
      if (!failSilently) rethrow;
      _log.warning('Seed database sync skipped (download failed): $e');
      return false;
    } on Exception catch (e) {
      if (!failSilently) rethrow;
      _log.warning('Seed database sync skipped: $e');
      return false;
    } finally {
      if (tempPath != null) {
        await _seedDatabaseService.cleanupTemporarySeedArtifact(tempPath);
      }
    }
  }
}
