import 'dart:async';

import 'package:app/infra/database/favorite_history_snapshot.dart';
import 'package:logging/logging.dart';

/// Clears local app data and stops background work for a fresh onboarding run.
class LocalDataCleanupService {
  /// Creates a [LocalDataCleanupService].
  LocalDataCleanupService({
    required Future<void> Function() stopWorkersGracefully,
    required Future<void> Function() closeAndDeleteDatabase,
    required Future<void> Function() clearObjectBoxData,
    required Future<void> Function() clearCachedImages,
    required Future<void> Function() recreateDatabaseFromSeed,
    required Future<List<FavoritePlaylistSnapshot>> Function()
    getFavoritePlaylistsSnapshot,
    required Future<void> Function(List<FavoritePlaylistSnapshot> snapshots)
    restoreFavoritePlaylists,
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
  }) : _stopWorkersGracefully = stopWorkersGracefully,
       _closeAndDeleteDatabase = closeAndDeleteDatabase,
       _clearObjectBoxData = clearObjectBoxData,
       _clearCachedImages = clearCachedImages,
       _recreateDatabaseFromSeed = recreateDatabaseFromSeed,
       _getFavoritePlaylistsSnapshot = getFavoritePlaylistsSnapshot,
       _restoreFavoritePlaylists = restoreFavoritePlaylists,
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

  void performReconnectInfraInvalidation() {
    invalidateReconnectInfraProviders?.call();
  }

  final Future<void> Function() _stopWorkersGracefully;
  final Future<void> Function() _closeAndDeleteDatabase;
  final Future<void> Function() _clearObjectBoxData;
  final Future<void> Function() _clearCachedImages;
  final Future<void> Function() _recreateDatabaseFromSeed;
  final Future<List<FavoritePlaylistSnapshot>> Function()
  _getFavoritePlaylistsSnapshot;
  final Future<void> Function(List<FavoritePlaylistSnapshot> snapshots)
  _restoreFavoritePlaylists;
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

  /// Light clear: drain workers, delete SQLite, ObjectBox light clear (inside
  /// [closeAndDeleteDatabase] callback), cached images.
  Future<void> _lightClear() async {
    _pauseFeedWork();
    _pauseTokenPolling();
    await _stopWorkersGracefully();
    await _closeAndDeleteDatabase();
    await _clearCachedImages();
  }

  /// Full clear: lightClear + remaining ObjectBox + legacy + postDrain.
  Future<void> _fullClear() async {
    await _lightClear();
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
  /// Returns as soon as [_fullClear] completes. Caller may navigate to
  /// onboarding immediately. Seed download and bootstrap run fire-and-forget
  /// so UI is not blocked. [isSeedDatabaseReadyProvider] listener runs
  /// ensureTrackedAddresses when DB becomes ready.
  Future<void> forgetIExist() async {
    _log.info('forgetIExist: start');
    _prepareForReset?.call();
    await _fullClear();
    _log.info('forgetIExist: local data cleared; replacing seed in background');
    unawaited(Future(() async {
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
    }));
  }

  /// Rebuilds metadata by clearing SQLite, restoring Favorite playlists,
  /// and ensuring tracked addresses have playlists and resume indexing.
  ///
  /// Returns as soon as [_lightClear] completes. Caller may dismiss UI
  /// immediately. Seed replace, bootstrap, and restore run fire-and-forget so
  /// UI is not blocked. [isSeedDatabaseReadyProvider] listener runs
  /// ensureTrackedAddresses when DB becomes ready.
  Future<void> rebuildMetadata() async {
    _log.info('rebuildMetadata: start');
    final snapshots = await _getFavoritePlaylistsSnapshot();
    await _lightClear();
    _log.info('rebuildMetadata: local data cleared; replacing seed in background');
    unawaited(Future(() async {
      Future<void> fullRetry() async {
        await _recreateDatabaseFromSeed();
        await _runBootstrap();
        if (snapshots.isNotEmpty) await _restoreFavoritePlaylists(snapshots);
      }
      try {
        await fullRetry();
        _log.info('rebuildMetadata: background seed+restore done');
      } on Object catch (e, st) {
        _log.warning('rebuildMetadata: background seed replace failed', e, st);
        _onResetFailed?.call(fullRetry);
      }
    }));
  }
}
