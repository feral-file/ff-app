import 'dart:async';

import 'package:app/infra/database/database_provider.dart';
import 'package:app/app/providers/indexer_tokens_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';

// ignore_for_file: public_member_api_docs // Reason: provider state objects are small and self-explanatory; keep surfaces stable.

/// State for incremental sync via the indexer change journal.
class IncrementalSyncState {
  /// Creates an IncrementalSyncState.
  const IncrementalSyncState({
    required this.isRunning,
    this.lastRunAt,
    this.lastError,
  });

  final bool isRunning;
  final DateTime? lastRunAt;
  final Object? lastError;

  IncrementalSyncState copyWith({
    bool? isRunning,
    DateTime? lastRunAt,
    Object? lastError,
    bool clearLastError = false,
  }) {
    return IncrementalSyncState(
      isRunning: isRunning ?? this.isRunning,
      lastRunAt: lastRunAt ?? this.lastRunAt,
      lastError: clearLastError ? null : (lastError ?? this.lastError),
    );
  }
}

/// Periodically syncs address playlists using indexer change journal entries.
///
/// This delegates all heavy lifting to [TokensSyncCoordinatorNotifier], which
/// wraps the isolate-backed worker and persists anchors/indexing metadata.
class IncrementalSyncNotifier extends Notifier<IncrementalSyncState> {
  late final Logger _log;
  Timer? _timer;

  @override
  IncrementalSyncState build() {
    _log = Logger('IncrementalSyncNotifier');
    ref.onDispose(_stopTimer);
    return const IncrementalSyncState(isRunning: false);
  }

  /// Start periodic sync.
  void start({
    Duration interval = const Duration(seconds: 30),
  }) {
    if (state.isRunning) return;
    state = state.copyWith(isRunning: true, clearLastError: true);

    _log.info('Starting incremental sync (interval: ${interval.inSeconds}s)');
    _timer = Timer.periodic(interval, (_) {
      // Best-effort: do not block timer tick.
      unawaited(syncNow());
    });

    // Run once immediately.
    unawaited(syncNow());
  }

  /// Stop periodic sync.
  void stop() {
    _stopTimer();
    state = state.copyWith(isRunning: false);
  }

  /// Run a sync pass immediately.
  Future<void> syncNow() async {
    if (!state.isRunning) return;

    try {
      final databaseService = ref.read(databaseServiceProvider);
      final playlists = await databaseService.getAddressPlaylists();
      final addresses = playlists
          .map((p) => p.ownerAddress)
          .whereType<String>()
          .map((a) => a.toUpperCase())
          .toList();

      if (addresses.isEmpty) {
        _log.fine('No address playlists found; skipping sync');
        state = state.copyWith(lastRunAt: DateTime.now(), clearLastError: true);
        return;
      }

      final coordinator = ref.read(tokensSyncCoordinatorProvider.notifier);
      await coordinator.syncAddresses(addresses);

      state = state.copyWith(lastRunAt: DateTime.now(), clearLastError: true);
    } on Object catch (e, stack) {
      _log.warning('Incremental sync failed', e, stack);
      state = state.copyWith(lastRunAt: DateTime.now(), lastError: e);
    }
  }

  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
  }
}

/// Provider for incremental sync.
final incrementalSyncProvider =
    NotifierProvider<IncrementalSyncNotifier, IncrementalSyncState>(
  IncrementalSyncNotifier.new,
);

// End of file.
