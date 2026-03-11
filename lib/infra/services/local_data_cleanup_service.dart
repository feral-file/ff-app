import 'package:app/infra/database/favorite_history_snapshot.dart';
import 'package:logging/logging.dart';

/// Clears local app data and stops background work for a fresh onboarding run.
class LocalDataCleanupService {
  /// Creates a [LocalDataCleanupService].
  LocalDataCleanupService({
    required Future<void> Function() stopWorkersGracefully,
    required Future<void> Function() closeAndDeleteDatabase,
    required Future<void> Function() clearObjectBoxData,
    required Future<void> Function() clearPendingAddresses,
    required Future<void> Function() clearCachedImages,
    required Future<List<String>> Function() getPersonalAddresses,
    required Future<void> Function(List<String> addresses)
    restorePersonalAddressPlaylists,
    required Future<void> Function(List<String> addresses) refetchFromBeginning,
    required Future<void> Function() recreateDatabaseFromSeed,
    required Future<List<FavoriteHistoryEntrySnapshot>> Function()
    getFavoriteHistorySnapshot,
    required Future<void> Function(List<FavoriteHistoryEntrySnapshot> snapshot)
    restoreFavoriteHistory,
    required Future<void> Function() runBootstrap,
    required void Function() pauseFeedWork,
    required void Function() pauseTokenPolling,
    Future<void> Function()? onResetCompleted,
    this.enablePostDrainSweep = true,
    this.postDrainSettleDuration = const Duration(milliseconds: 200),
    Logger? logger,
  }) : _stopWorkersGracefully = stopWorkersGracefully,
       _closeAndDeleteDatabase = closeAndDeleteDatabase,
       _clearObjectBoxData = clearObjectBoxData,
       _clearPendingAddresses = clearPendingAddresses,
       _clearCachedImages = clearCachedImages,
       _getPersonalAddresses = getPersonalAddresses,
       _restorePersonalAddressPlaylists = restorePersonalAddressPlaylists,
       _refetchFromBeginning = refetchFromBeginning,
       _recreateDatabaseFromSeed = recreateDatabaseFromSeed,
       _getFavoriteHistorySnapshot = getFavoriteHistorySnapshot,
       _restoreFavoriteHistory = restoreFavoriteHistory,
       _runBootstrap = runBootstrap,
       _pauseFeedWork = pauseFeedWork,
       _pauseTokenPolling = pauseTokenPolling,
       _onResetCompleted = onResetCompleted,
       _log = logger ?? Logger('LocalDataCleanupService');

  final Future<void> Function() _stopWorkersGracefully;
  final Future<void> Function() _closeAndDeleteDatabase;
  final Future<void> Function() _clearObjectBoxData;

  /// Removes addresses queued before DB availability.
  final Future<void> Function() _clearPendingAddresses;
  final Future<void> Function() _clearCachedImages;
  final Future<List<String>> Function() _getPersonalAddresses;
  final Future<void> Function(List<String> addresses)
  _restorePersonalAddressPlaylists;
  final Future<void> Function(List<String> addresses) _refetchFromBeginning;
  final Future<void> Function() _recreateDatabaseFromSeed;
  final Future<List<FavoriteHistoryEntrySnapshot>> Function()
  _getFavoriteHistorySnapshot;
  final Future<void> Function(List<FavoriteHistoryEntrySnapshot> snapshot)
  _restoreFavoriteHistory;
  final Future<void> Function() _runBootstrap;
  final void Function() _pauseFeedWork;
  final void Function() _pauseTokenPolling;
  final Future<void> Function()? _onResetCompleted;

  /// Whether to run a second close/delete pass after a short settle delay.
  final bool enablePostDrainSweep;

  /// Delay before optional post-drain close/delete sweep.
  final Duration postDrainSettleDuration;
  final Logger _log;

  /// Stops workers, closes/removes SQLite files, and clears ObjectBox state
  /// used by local app flows.
  Future<void> clearLocalData() async {
    _log.info('clearLocalData: start');
    _pauseFeedWork();
    _pauseTokenPolling();

    // Stop all writers before touching SQLite durability/truncation.
    _log.info('clearLocalData: stopWorkersGracefully');
    await _stopWorkersGracefully();

    _log.info('clearLocalData: closeAndDeleteDatabase(1)');
    await _closeAndDeleteDatabase();

    _log.info('clearLocalData: clearObjectBoxData');
    await _clearObjectBoxData();
    _log.info('clearLocalData: clearPendingAddresses');
    await _clearPendingAddresses();
    _log.info('clearLocalData: clearCachedImages');
    await _clearCachedImages();

    if (enablePostDrainSweep) {
      // Defensive final pass: catches late async writes racing reset teardown.
      _log.info('clearLocalData: postDrainSettleDuration');
      await Future<void>.delayed(postDrainSettleDuration);
      _log.info('clearLocalData: closeAndDeleteDatabase(2)');
      await _closeAndDeleteDatabase();
    }

    final onResetCompleted = _onResetCompleted;
    if (onResetCompleted != null) {
      await onResetCompleted();
    }

    _log.info('Local data cleared and workers stopped');
  }

  /// Rebuilds metadata by clearing SQLite, restoring personal playlists,
  /// Favorite/History, and re-fetching data from the beginning.
  Future<void> rebuildMetadata() async {
    _log.info('rebuildMetadata: start');
    _pauseFeedWork();
    _pauseTokenPolling();

    _log.info('rebuildMetadata: stopWorkersGracefully');
    await _stopWorkersGracefully();

    _log.info('rebuildMetadata: getPersonalAddresses');
    final addresses = await _getPersonalAddresses();
    _log.info('rebuildMetadata: getFavoriteHistorySnapshot');
    final snapshot = await _getFavoriteHistorySnapshot();
    _log.info('rebuildMetadata: recreateDatabaseFromSeed');
    await _recreateDatabaseFromSeed();

    _log.info('rebuildMetadata: runBootstrap');
    await _runBootstrap();

    if (addresses.isNotEmpty) {
      _log.info('rebuildMetadata: restorePersonalAddressPlaylists');
      await _restorePersonalAddressPlaylists(addresses);
    }

    if (snapshot.isNotEmpty) {
      _log.info('rebuildMetadata: restoreFavoriteHistory');
      await _restoreFavoriteHistory(snapshot);
    }

    _log.info('rebuildMetadata: clearCachedImages');
    await _clearCachedImages();

    _log.info('rebuildMetadata: refetchFromBeginning');
    await _refetchFromBeginning(addresses);

    _log.info('Metadata rebuilt from scratch');
  }
}
