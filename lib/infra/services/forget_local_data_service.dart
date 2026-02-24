import 'package:logging/logging.dart';

/// Clears local app data and stops background work for a fresh onboarding run.
class ForgetLocalDataService {
  /// Creates a [ForgetLocalDataService].
  ForgetLocalDataService({
    required Future<void> Function() stopWorkersGracefully,
    required Future<void> Function() checkpointDatabase,
    required Future<void> Function() truncateDatabase,
    required Future<void> Function() clearObjectBoxData,
    required void Function() pauseFeedWork,
    required void Function() pauseTokenPolling,
    Future<void> Function()? onResetCompleted,
    this.enablePostDrainSweep = true,
    this.postDrainSettleDuration = const Duration(milliseconds: 200),
    Logger? logger,
  }) : _stopWorkersGracefully = stopWorkersGracefully,
       _checkpointDatabase = checkpointDatabase,
       _truncateDatabase = truncateDatabase,
       _clearObjectBoxData = clearObjectBoxData,
       _pauseFeedWork = pauseFeedWork,
       _pauseTokenPolling = pauseTokenPolling,
       _onResetCompleted = onResetCompleted,
       _log = logger ?? Logger('ForgetLocalDataService');

  final Future<void> Function() _stopWorkersGracefully;
  final Future<void> Function() _checkpointDatabase;
  final Future<void> Function() _truncateDatabase;
  final Future<void> Function() _clearObjectBoxData;
  final void Function() _pauseFeedWork;
  final void Function() _pauseTokenPolling;
  final Future<void> Function()? _onResetCompleted;
  final bool enablePostDrainSweep;
  final Duration postDrainSettleDuration;
  final Logger _log;

  /// Stops workers, checkpoints pending changes, truncates SQLite, and clears
  /// ObjectBox state used by local app flows.
  Future<void> forgetIExist() async {
    _pauseFeedWork();
    _pauseTokenPolling();

    // Stop all writers before touching SQLite durability/truncation.
    await _stopWorkersGracefully();

    // Flush final settled state after workers are down.
    await _checkpointDatabase();

    await _truncateDatabase();

    // Persist truncation to disk before clearing ObjectBox state.
    await _checkpointDatabase();

    await _clearObjectBoxData();

    if (enablePostDrainSweep) {
      // Defensive final pass: catches late async writes racing reset teardown.
      await Future<void>.delayed(postDrainSettleDuration);
      await _truncateDatabase();
      await _checkpointDatabase();
    }

    final onResetCompleted = _onResetCompleted;
    if (onResetCompleted != null) {
      await onResetCompleted();
    }

    _log.info('Local data cleared and workers stopped');
  }
}
