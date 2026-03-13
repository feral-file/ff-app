import 'package:app/infra/database/favorite_history_snapshot.dart';
import 'package:logging/logging.dart';

/// Clears local app data and stops background work for a fresh onboarding run.
class LocalDataCleanupService {
  /// Creates a [LocalDataCleanupService].
  LocalDataCleanupService({
    required Future<void> Function() stopWorkersGracefully,
    required Future<void> Function() closeAndDeleteDatabase,
    required Future<void> Function() clearObjectBoxData,
    required Future<void> Function() clearObjectBoxLight,
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
    Future<void> Function()? onDatabaseReady,
    this.invalidateListProvidersBeforeDbClose,
    this.invalidateReconnectInfraProviders,
    this.enablePostDrainSweep = true,
    this.postDrainSettleDuration = const Duration(milliseconds: 200),
    Logger? logger,
  }) : _stopWorkersGracefully = stopWorkersGracefully,
       _closeAndDeleteDatabase = closeAndDeleteDatabase,
       _clearObjectBoxData = clearObjectBoxData,
       _clearObjectBoxLight = clearObjectBoxLight,
       _clearCachedImages = clearCachedImages,
       _recreateDatabaseFromSeed = recreateDatabaseFromSeed,
       _getFavoritePlaylistsSnapshot = getFavoritePlaylistsSnapshot,
       _restoreFavoritePlaylists = restoreFavoritePlaylists,
       _runBootstrap = runBootstrap,
       _pauseFeedWork = pauseFeedWork,
       _pauseTokenPolling = pauseTokenPolling,
       _clearLegacySqlite = clearLegacySqlite,
       _clearLegacyHive = clearLegacyHive,
       _onDatabaseReady = onDatabaseReady,
       _log = logger ?? Logger('LocalDataCleanupService');

  /// Invalidates core list providers before DB close. For app.dart seed sync.
  final void Function()? invalidateListProvidersBeforeDbClose;

  /// Invalidates infra providers after DB replace. For app.dart reconnect.
  final void Function()? invalidateReconnectInfraProviders;

  final Future<void> Function() _stopWorkersGracefully;
  final Future<void> Function() _closeAndDeleteDatabase;
  final Future<void> Function() _clearObjectBoxData;
  final Future<void> Function() _clearObjectBoxLight;
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
  final Future<void> Function()? _onDatabaseReady;

  /// Whether to run a second close/delete pass after a short settle delay.
  final bool enablePostDrainSweep;

  /// Delay before optional post-drain close/delete sweep.
  final Duration postDrainSettleDuration;
  final Logger _log;

  /// Light clear: DB, ObjectBox (except TrackedAddress), cached images.
  Future<void> _lightClear() async {
    _pauseFeedWork();
    _pauseTokenPolling();
    await _stopWorkersGracefully();
    await _closeAndDeleteDatabase();
    await _clearObjectBoxLight();
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

  /// Full reset (Forget I Exist): clears all local data, replaces DB from seed,
  /// and bootstraps for a fresh onboarding run.
  Future<void> forgetIExist() async {
    _log.info('forgetIExist: start');
    await _fullClear();
    await _recreateDatabaseFromSeed();
    await _runBootstrap();
    final onDatabaseReady = _onDatabaseReady;
    if (onDatabaseReady != null) await onDatabaseReady();
    _log.info('forgetIExist: done');
  }

  /// Rebuilds metadata by clearing SQLite, restoring Favorite playlists,
  /// and ensuring tracked addresses have playlists and resume indexing.
  Future<void> rebuildMetadata() async {
    _log.info('rebuildMetadata: start');
    final snapshots = await _getFavoritePlaylistsSnapshot();
    await _lightClear();
    await _recreateDatabaseFromSeed();
    await _runBootstrap();
    final onDatabaseReady = _onDatabaseReady;
    if (onDatabaseReady != null) await onDatabaseReady();
    if (snapshots.isNotEmpty) await _restoreFavoritePlaylists(snapshots);
    _log.info('rebuildMetadata: done');
  }
}
