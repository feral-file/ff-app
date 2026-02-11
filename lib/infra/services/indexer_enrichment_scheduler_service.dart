import 'dart:async';

import 'package:app/infra/services/dp1_playlist_items_enrichment_service.dart';
import 'package:app/infra/services/indexer_sync_service.dart';
import 'package:logging/logging.dart';

/// Shared scheduler for feed enrichment + personal address token sync.
///
/// This service runs two independent processes:
/// 1) Feed enrichment batches (high -> low priority)
/// 2) Personal address batch syncing
class IndexerEnrichmentSchedulerService {
  /// Creates an IndexerEnrichmentSchedulerService.
  IndexerEnrichmentSchedulerService({
    required DP1PlaylistItemsEnrichmentService enrichmentService,
    required IndexerSyncService indexerSyncService,
  }) : _enrichmentService = enrichmentService,
       _indexerSyncService = indexerSyncService,
       _log = Logger('IndexerEnrichmentSchedulerService');

  final DP1PlaylistItemsEnrichmentService _enrichmentService;
  final IndexerSyncService _indexerSyncService;
  final Logger _log;

  static const int _batchSize = 50;
  static const int _maxEmptyRetriesPerAddress = 5;
  static const Duration _emptyRetryDelay = Duration(seconds: 3);

  final Map<String, _PersonalSyncCursor> _personalQueue =
      <String, _PersonalSyncCursor>{};

  Future<void>? _enrichmentLoop;
  Future<void>? _addressLoop;
  bool _hasPendingEnrichmentSignal = false;
  bool _hasPendingAddressSignal = false;

  /// Adds/refreshes an address in personal sync queue and starts loop.
  void enqueuePersonalAddress(String address) {
    _personalQueue.putIfAbsent(address, () => const _PersonalSyncCursor());
    unawaited(processAddressQueueUntilIdle());
  }

  /// Notify that feed ingest has new bare items ready for enrichment.
  void notifyFeedWorkAvailable() {
    unawaited(processFeedEnrichmentUntilIdle());
  }

  /// Runs feed enrichment process to completion (or joins in-flight run).
  Future<bool> processFeedEnrichmentUntilIdle() async {
    if (_enrichmentLoop != null) {
      _hasPendingEnrichmentSignal = true;
      await _enrichmentLoop;
      return true;
    }

    final completer = Completer<void>();
    _enrichmentLoop = completer.future;

    try {
      do {
        _hasPendingEnrichmentSignal = false;
        await _drainFeedEnrichmentOnce();
      } while (_hasPendingEnrichmentSignal);
      return true;
    } finally {
      _enrichmentLoop = null;
      completer.complete();
    }
  }

  /// Runs personal address batch sync process to completion.
  Future<bool> processAddressQueueUntilIdle() async {
    if (_addressLoop != null) {
      _hasPendingAddressSignal = true;
      await _addressLoop;
      return true;
    }

    final completer = Completer<void>();
    _addressLoop = completer.future;

    try {
      do {
        _hasPendingAddressSignal = false;
        await _drainAddressQueueOnce();
      } while (_hasPendingAddressSignal);
      return true;
    } finally {
      _addressLoop = null;
      completer.complete();
    }
  }

  /// Runs both processes independently and waits until both are idle.
  Future<bool> processUntilIdle() async {
    final results = await Future.wait(<Future<bool>>[
      processFeedEnrichmentUntilIdle(),
      processAddressQueueUntilIdle(),
    ]);
    return results.every((value) => value);
  }

  Future<void> _drainFeedEnrichmentOnce() async {
    while (true) {
      final highUpdated = await _enrichmentService
          .processNextHighPriorityBatch();
      var lowUpdated = 0;
      if (highUpdated == 0) {
        lowUpdated = await _enrichmentService.processNextLowPriorityBatch();
      }

      final hasWork = highUpdated > 0 || lowUpdated > 0;
      if (!hasWork) {
        return;
      }
    }
  }

  Future<void> _drainAddressQueueOnce() async {
    while (_personalQueue.isNotEmpty) {
      final loaded = await _processNextPersonalBatch();
      if (loaded > 0) {
        continue;
      }
      if (_personalQueue.isEmpty) {
        return;
      }
    }
  }

  Future<int> _processNextPersonalBatch() async {
    if (_personalQueue.isEmpty) {
      return 0;
    }

    final address = _personalQueue.keys.first;
    final cursor = _personalQueue[address]!;

    final loaded = await _indexerSyncService.syncTokensForAddresses(
      addresses: <String>[address],
      limit: _batchSize,
      offset: cursor.offset,
    );

    if (loaded <= 0) {
      final retries = cursor.emptyRetries + 1;
      if (retries >= _maxEmptyRetriesPerAddress) {
        _personalQueue.remove(address);
        _log.info(
          'Removed personal sync queue address after empty retries: $address',
        );
      } else {
        _personalQueue[address] = cursor.copyWith(emptyRetries: retries);
        await Future<void>.delayed(_emptyRetryDelay);
      }
      return 0;
    }

    if (loaded < _batchSize) {
      _personalQueue.remove(address);
    } else {
      _personalQueue[address] = cursor.copyWith(
        offset: cursor.offset + _batchSize,
        emptyRetries: 0,
      );
    }

    return loaded;
  }
}

class _PersonalSyncCursor {
  const _PersonalSyncCursor({
    this.offset = 0,
    this.emptyRetries = 0,
  });

  final int offset;
  final int emptyRetries;

  _PersonalSyncCursor copyWith({
    int? offset,
    int? emptyRetries,
  }) {
    return _PersonalSyncCursor(
      offset: offset ?? this.offset,
      emptyRetries: emptyRetries ?? this.emptyRetries,
    );
  }
}
