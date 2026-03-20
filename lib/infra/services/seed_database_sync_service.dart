import 'dart:io';

import 'package:app/infra/services/seed_database_service.dart';
import 'package:dio/dio.dart';
import 'package:logging/logging.dart';

/// Syncs the local seed database file using remote ETag comparison.
///
/// The app never creates a database; only downloads and replaces. Flow:
/// 1) HEAD remote seed URL and read ETag.
/// 2) Compare against locally persisted ETag in ObjectBox config.
/// 3) If changed (or no local DB), download to temp file.
/// 4) Run pre-replace callback (close DB, delete files).
/// 5) Replace canonical DB file with temp (rename temp to target).
/// 6) Run post-replace callback (rebind providers).
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
  }) async {
    try {
      final hasLocalDatabase = await _seedDatabaseService.hasLocalDatabase();

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
              !hasLocalDatabase || (headEtag.isNotEmpty && headEtag != loaded);

          _log.info(
            'Seed sync pre-check: hasLocal=$hasLocalDatabase, '
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
          'falling back to shouldDownload=forceReplace.',
          e,
          st,
        );
        shouldDownload = forceReplace;
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

      final tempPath = await _seedDatabaseService.downloadToTemporaryFile(
        onProgress: onProgress,
      );
      await beforeReplace();
      await _seedDatabaseService.replaceDatabaseFromTemporaryFile(tempPath);

      if (remoteEtag != null && remoteEtag.isNotEmpty) {
        _saveLocalEtag(remoteEtag);
      }

      await afterReplace();
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
    }
  }
}
