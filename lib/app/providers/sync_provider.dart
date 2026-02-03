import 'dart:async';

import 'package:app/app/providers/indexer_provider.dart';
import 'package:app/app/providers/services_provider.dart';
import 'package:app/domain/models/indexer/changes/change.dart';
import 'package:app/domain/models/indexer/changes/change_meta.dart';
import 'package:app/infra/database/database_provider.dart';
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
/// This is a lightweight, provider-driven alternative to the legacy isolate
/// tokens service. It prioritizes correctness and auditability over maximal
/// throughput.
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

      for (final address in addresses) {
        await _syncAddress(address);
      }

      state = state.copyWith(lastRunAt: DateTime.now(), clearLastError: true);
    } on Object catch (e, stack) {
      _log.warning('Incremental sync failed', e, stack);
      state = state.copyWith(lastRunAt: DateTime.now(), lastError: e);
    }
  }

  Future<void> _syncAddress(String address) async {
    final indexer = ref.read(indexerServiceProvider);
    final databaseService = ref.read(databaseServiceProvider);
    final anchorStore = ref.read(changesAnchorProvider.notifier);

    final anchor = anchorStore.getAnchor(address);
    var nextAnchor = anchor;
    var latestAnchorSeen = anchor;

    while (true) {
      final page = await indexer.getChanges(
        QueryChangesRequest(
          addresses: [address],
          anchor: nextAnchor,
          limit: 50,
        ),
      );

      if (page.items.isEmpty) {
        break;
      }

      final cidsToUpsert = <String>{};
      final cidsToDelete = <String>{};

      for (final change in page.items) {
        final cid = change.tokenCid;
        if (cid == null || cid.isEmpty) continue;

        final parsed = change.metaParsed;
        if (parsed is ProvenanceChangeMeta) {
          final from = parsed.from?.toUpperCase();
          final to = parsed.to?.toUpperCase();

          if (parsed.isBurn()) {
            cidsToDelete.add(cid);
            continue;
          }

          if (parsed.isTransfer()) {
            // Remove when token transferred out of the tracked address.
            if (from == address) {
              cidsToDelete.add(cid);
            }
            // Add/update when token transferred into the tracked address.
            if (to == address) {
              cidsToUpsert.add(cid);
            }
            continue;
          }

          if (parsed.isMint()) {
            cidsToUpsert.add(cid);
            continue;
          }
        }

        // For metadata/enrichment/viewability, refetch and upsert.
        if (change.isMetadataUpdate() ||
            change.isEnrichmentSourceUpdate() ||
            change.subjectType == SubjectType.tokenViewability) {
          cidsToUpsert.add(cid);
        }
      }

      if (cidsToUpsert.isNotEmpty) {
        final tokens =
            await indexer.fetchTokensByCIDs(cids: cidsToUpsert.toList());
        if (tokens.isNotEmpty) {
          await databaseService.ingestTokensForAddress(
            address: address,
            tokens: tokens,
          );
        }
      }

      if (cidsToDelete.isNotEmpty) {
        await databaseService.deleteTokensByCids(
          address: address,
          cids: cidsToDelete.toList(),
        );
      }

      nextAnchor = page.nextAnchor;
      if (nextAnchor != null) {
        latestAnchorSeen = nextAnchor;
      }
      if (nextAnchor == null) {
        break;
      }
    }

    // Persist the latest anchor in-memory.
    if (latestAnchorSeen != null) {
      anchorStore.setAnchor(address: address, anchor: latestAnchorSeen);
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
