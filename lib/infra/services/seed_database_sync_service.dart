import 'dart:io';

import 'package:app/infra/services/seed_database_service.dart';
import 'package:dio/dio.dart';
import 'package:logging/logging.dart';

/// Syncs the local seed database file using remote ETag comparison.
///
/// Flow:
/// 1) HEAD remote seed URL and read ETag.
/// 2) Compare against locally persisted ETag in ObjectBox config.
/// 3) If changed (or no local DB), download to temp file.
/// 4) Execute caller-provided disconnect/replace/rebind callbacks.
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

  /// Syncs seed DB from remote when ETag differs from local ObjectBox config.
  Future<bool> syncIfNeeded({
    required Future<void> Function() beforeReplace,
    required Future<void> Function() afterReplace,
    void Function(double progress)? onProgress,
    bool failSilently = false,
  }) async {
    try {
      final hasLocalDatabase = await _seedDatabaseService.hasLocalDatabase();
      final localEtag = _loadLocalEtag();

      final remoteEtag = await _seedDatabaseService.headRemoteEtag();
      final shouldReplace =
          !hasLocalDatabase ||
          (remoteEtag.isNotEmpty && remoteEtag != localEtag);

      _log.info(
        'Seed sync pre-check: hasLocal=$hasLocalDatabase, '
        'localEtag=${localEtag.isEmpty ? '<empty>' : localEtag}, '
        'remoteEtag=${remoteEtag.isEmpty ? '<empty>' : remoteEtag}, '
        'shouldReplace=$shouldReplace',
      );
      if (!shouldReplace) {
        _log.fine('Seed database ETag unchanged; skipping download.');
        return false;
      }

      _log.info('Seed DB refresh needed; downloading latest seed snapshot.');

      final tempPath = await _seedDatabaseService.downloadToTemporaryFile(
        onProgress: onProgress,
      );
      await beforeReplace();
      await _seedDatabaseService.replaceDatabaseFromTemporaryFile(tempPath);
      if (remoteEtag.isNotEmpty) {
        _saveLocalEtag(remoteEtag);
      }
      await afterReplace();
      _log.info(
        hasLocalDatabase
            ? 'Seed database updated from remote ETag change.'
            : 'Seed database installed.',
      );
      return true;
    } on FormatException catch (e, st) {
      if (!failSilently) rethrow;
      _log.warning(
        'Seed database sync skipped due to invalid seed configuration (S3_*).',
        e,
        st,
      );
      return false;
    } on DioException catch (e, st) {
      if (!failSilently) rethrow;
      _log.warning('Seed database sync skipped (network failure).', e, st);
      return false;
    } on SocketException catch (e, st) {
      if (!failSilently) rethrow;
      _log.warning('Seed database sync skipped (offline).', e, st);
      return false;
    } on Exception catch (e, st) {
      if (!failSilently) rethrow;
      _log.warning('Seed database sync skipped.', e, st);
      return false;
    }
  }

  /// Always downloads and replaces the local seed DB, ignoring ETag checks.
  Future<void> forceReplace({
    required Future<void> Function() beforeReplace,
    required Future<void> Function() afterReplace,
    void Function(double progress)? onProgress,
  }) async {
    final tempPath = await _seedDatabaseService.downloadToTemporaryFile(
      onProgress: onProgress,
    );
    await beforeReplace();
    await _seedDatabaseService.replaceDatabaseFromTemporaryFile(tempPath);
    try {
      final remoteEtag = await _seedDatabaseService.headRemoteEtag();
      if (remoteEtag.isNotEmpty) {
        _saveLocalEtag(remoteEtag);
      }
    } on Exception catch (e, st) {
      _log.warning(
        'Failed to persist seed ETag after forced replacement.',
        e,
        st,
      );
    }
    await afterReplace();
  }
}
