import 'dart:async';

import 'package:logging/logging.dart';

/// Clears local app data and stops background work for a fresh onboarding run.
class LocalDataCleanupService {
  /// Creates a [LocalDataCleanupService].
  LocalDataCleanupService({
    required Future<void> Function() closeAndDeleteDatabase,
    required Future<void> Function() clearObjectBoxData,
    required Future<void> Function() clearCachedImages,
    required Future<void> Function() recreateDatabaseFromSeed,
    required Future<void> Function() runBootstrap,
    required void Function() pauseFeedWork,
    required void Function() pauseTokenPolling,
    Future<void> Function()? clearLegacySqlite,
    Future<void> Function()? clearLegacyHive,
    void Function(Future<void> Function() retry)? onResetFailed,
    void Function()? prepareForReset,
    this.invalidateListProvidersBeforeDbClose,
    this.invalidateReconnectInfraProviders,
    this.invalidateProvidersForRebind,
    this.enablePostDrainSweep = true,
    this.postDrainSettleDuration = const Duration(milliseconds: 200),
    Logger? logger,
  }) : _closeAndDeleteDatabase = closeAndDeleteDatabase,
       _clearObjectBoxData = clearObjectBoxData,
       _clearCachedImages = clearCachedImages,
       _recreateDatabaseFromSeed = recreateDatabaseFromSeed,
       _runBootstrap = runBootstrap,
       _pauseFeedWork = pauseFeedWork,
       _pauseTokenPolling = pauseTokenPolling,
       _clearLegacySqlite = clearLegacySqlite,
       _clearLegacyHive = clearLegacyHive,
       _onResetFailed = onResetFailed,
       _prepareForReset = prepareForReset,
       _log = logger ?? Logger('LocalDataCleanupService');

  final void Function(Future<void> Function() retry)? _onResetFailed;
  final void Function()? _prepareForReset;

  /// Invalidates providers that read/watch the database so they stop subscriptions.
  final void Function()? invalidateListProvidersBeforeDbClose;

  /// Invalidates providers that hold the database connection so they reconnect.
  final void Function()? invalidateReconnectInfraProviders;

  /// Invalidates data providers so they refresh from the database.
  final void Function()? invalidateProvidersForRebind;

  /// Invokes reconnect invalidation when wired (after seed replace).
  void performReconnectInfraInvalidation() {
    invalidateReconnectInfraProviders?.call();
  }

  final Future<void> Function() _closeAndDeleteDatabase;
  final Future<void> Function() _clearObjectBoxData;
  final Future<void> Function() _clearCachedImages;
  final Future<void> Function() _recreateDatabaseFromSeed;
  final Future<void> Function() _runBootstrap;
  final void Function() _pauseFeedWork;
  final void Function() _pauseTokenPolling;
  final Future<void> Function()? _clearLegacySqlite;
  final Future<void> Function()? _clearLegacyHive;

  /// Whether to run a second close/delete pass after a short settle delay.
  final bool enablePostDrainSweep;

  /// Delay before optional post-drain close/delete sweep.
  final Duration postDrainSettleDuration;
  final Logger _log;

  /// Light clear: pause polling and clear image caches. Does **not** delete
  /// SQLite files — full clear performs close-and-delete.
  Future<void> _lightClear() async {
    _pauseFeedWork();
    _pauseTokenPolling();
    await _clearCachedImages();
  }

  /// Full clear: light clear, then close+delete database (Forget I Exist only),
  /// then remaining ObjectBox + legacy + optional post-drain delete.
  Future<void> _fullClear() async {
    await _lightClear();
    await _closeAndDeleteDatabase();
    await _clearObjectBoxData();
    final clearLegacySqlite = _clearLegacySqlite;
    if (clearLegacySqlite != null) await clearLegacySqlite();
    final clearLegacyHive = _clearLegacyHive;
    if (clearLegacyHive != null) await clearLegacyHive();
    if (enablePostDrainSweep) {
      await Future<void>.delayed(postDrainSettleDuration);
      await _closeAndDeleteDatabase();
    }
  }

  /// Full reset (Forget I Exist): clears all local data, then replaces DB from
  /// seed and bootstraps in background.
  ///
  /// Returns as soon as full clear completes. Caller may navigate to
  /// onboarding immediately. Seed download and bootstrap run fire-and-forget
  /// so UI is not blocked. When the seed DB becomes ready again, listeners
  /// resume tracked-address sync.
  Future<void> forgetIExist() async {
    _log.info('forgetIExist: start');
    _prepareForReset?.call();
    await _fullClear();
    _log.info('forgetIExist: local data cleared; replacing seed in background');
    unawaited(
      Future(() async {
        Future<void> fullRetry() async {
          await _recreateDatabaseFromSeed();
          await _runBootstrap();
        }

        try {
          await fullRetry();
          _log.info('forgetIExist: background seed+bootstrap done');
        } on Object catch (e, st) {
          _log.warning('forgetIExist: background seed replace failed', e, st);
          _onResetFailed?.call(fullRetry);
        }
      }),
    );
  }

  /// Rebuilds metadata by replacing the local seed database from remote and
  /// bootstrapping. Favorite playlists are captured during the seed sync
  /// replace phase (while the DB file still exists). The on-disk file is only
  /// deleted and replaced after the new seed has been downloaded.
  ///
  /// Does **not** delete DB files up front: if sync fails, the previous DB
  /// remains on disk. Runs light clear only (no close-and-delete).
  ///
  /// Returns after light clear completes and replace+bootstrap are scheduled
  /// in the background. When the seed DB becomes ready again, listeners resume
  /// tracked-address sync.
  Future<void> rebuildMetadata() async {
    _log.info('rebuildMetadata: start');
    await _lightClear();
    _log.info('rebuildMetadata: seed replace scheduled in background');
    unawaited(
      Future(() async {
        Future<void> fullRetry() async {
          await _recreateDatabaseFromSeed();
          await _runBootstrap();
        }

        try {
          await fullRetry();
          _log.info('rebuildMetadata: background seed+bootstrap done');
        } on Object catch (e, st) {
          _log.warning(
            'rebuildMetadata: background seed replace failed',
            e,
            st,
          );
          _onResetFailed?.call(fullRetry);
        }
      }),
    );
  }
}
