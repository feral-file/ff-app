import 'dart:async';

import 'package:app/infra/services/dp1_playlist_items_enrichment_service.dart';
import 'package:app/infra/services/indexer_service.dart';
import 'package:app/infra/services/indexer_sync_service.dart';
import 'package:logging/logging.dart';

/// Shared scheduler for feed enrichment + personal address token sync.
///
/// Loop priority per cycle:
/// 1) High-priority feed enrichment batch (50 max)
/// 2) Otherwise low-priority feed enrichment batch (50 max)
/// 3) Then one personal-address batch (50 max)
///
/// The loop runs until all three queues are empty.
class IndexerEnrichmentSchedulerService {
  /// Creates an IndexerEnrichmentSchedulerService.
  IndexerEnrichmentSchedulerService({
    required DP1PlaylistItemsEnrichmentService enrichmentService,
    required IndexerService indexerService,
    required IndexerSyncService indexerSyncService,
  }) : _enrichmentService = enrichmentService,
       _indexerService = indexerService,
       _indexerSyncService = indexerSyncService,
       _log = Logger('IndexerEnrichmentSchedulerService');

  final DP1PlaylistItemsEnrichmentService _enrichmentService;
  final IndexerService _indexerService;
  final IndexerSyncService _indexerSyncService;
  final Logger _log;

  static const int _batchSize = 50;
  static const int _maxEmptyRetriesPerAddress = 5;
  static const Duration _emptyRetryDelay = Duration(seconds: 3);
  static const Duration _indexingPollDelay = Duration(seconds: 5);
  static const Duration _indexingTimeout = Duration(minutes: 15);

  final Map<String, _PersonalSyncCursor> _personalQueue =
      <String, _PersonalSyncCursor>{};

  Future<void>? _runningLoop;
  bool _hasPendingSignal = false;

  /// Adds/refreshes an address in personal sync queue and starts loop.
  void enqueuePersonalAddress(String address) {
    _personalQueue.putIfAbsent(address, () => const _PersonalSyncCursor());
    unawaited(processUntilIdle());
  }

  /// Notify that feed ingest has new bare items ready for enrichment.
  void notifyFeedWorkAvailable() {
    unawaited(processUntilIdle());
  }

  /// Runs shared queue loop to completion (or joins in-flight run).
  Future<bool> processUntilIdle() async {
    if (_runningLoop != null) {
      _hasPendingSignal = true;
      await _runningLoop;
      return true;
    }

    final completer = Completer<void>();
    _runningLoop = completer.future;

    try {
      do {
        _hasPendingSignal = false;
        await _drainOnce();
      } while (_hasPendingSignal);
      return true;
    } finally {
      _runningLoop = null;
      completer.complete();
    }
  }

  Future<void> _drainOnce() async {
    while (true) {
      final highUpdated = await _enrichmentService
          .processNextHighPriorityBatch();
      var lowUpdated = 0;
      if (highUpdated == 0) {
        lowUpdated = await _enrichmentService.processNextLowPriorityBatch();
      }

      final personalLoaded = await _processNextPersonalBatch();

      final hasWork = highUpdated > 0 || lowUpdated > 0 || personalLoaded > 0;
      if (!hasWork) {
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

    final ready = await _ensurePersonalAddressIndexingReady(
      address: address,
      cursor: cursor,
    );
    if (!ready) {
      return 0;
    }

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

  Future<bool> _ensurePersonalAddressIndexingReady({
    required String address,
    required _PersonalSyncCursor cursor,
  }) async {
    var workflowId = cursor.workflowId;
    if (workflowId == null || workflowId.isEmpty) {
      try {
        final results = await _indexerService.indexAddressesList(<String>[
          address,
        ]);
        for (final result in results) {
          if (_addressesEqual(result.address, address) &&
              result.workflowId.isNotEmpty) {
            workflowId = result.workflowId;
            _personalQueue[address] = cursor.copyWith(workflowId: workflowId);
            break;
          }
        }
      } on Object catch (e, stack) {
        _log.warning('Failed to trigger indexing for personal address $address', e, stack);
        return false;
      }
    }

    if (workflowId == null || workflowId.isEmpty) {
      return false;
    }

    if (cursor.indexingDone) {
      return true;
    }

    final done = await _waitForAddressIndexingWorkflow(
      workflowId: workflowId,
      address: address,
    );
    if (!done) {
      return false;
    }

    final latest = _personalQueue[address];
    if (latest == null) {
      return false;
    }
    _personalQueue[address] = latest.copyWith(indexingDone: true);
    return true;
  }

  Future<bool> _waitForAddressIndexingWorkflow({
    required String workflowId,
    required String address,
  }) async {
    final startedAt = DateTime.now();
    while (true) {
      try {
        final status = await _indexerService.getAddressIndexingJobStatus(
          workflowId: workflowId,
        );
        if (status.status.isDone) {
          if (!status.status.isSuccess) {
            _log.warning(
              'Address indexing finished with non-success status '
              'for $address: ${status.status.name}',
            );
          }
          return status.status.isSuccess;
        }
      } on Object catch (e, stack) {
        _log.warning(
          'Failed to read indexing status for $address workflow=$workflowId',
          e,
          stack,
        );
      }

      if (DateTime.now().difference(startedAt) > _indexingTimeout) {
        _log.warning(
          'Timed out waiting for indexing workflow $workflowId for $address',
        );
        return false;
      }
      await Future<void>.delayed(_indexingPollDelay);
    }
  }

  bool _addressesEqual(String left, String right) {
    if (_isEthereumAddress(left) || _isEthereumAddress(right)) {
      return left.toLowerCase() == right.toLowerCase();
    }
    return left == right;
  }

  bool _isEthereumAddress(String address) {
    return address.startsWith('0x') || address.startsWith('0X');
  }
}

class _PersonalSyncCursor {
  const _PersonalSyncCursor({
    this.offset = 0,
    this.emptyRetries = 0,
    this.workflowId,
    this.indexingDone = false,
  });

  final int offset;
  final int emptyRetries;
  final String? workflowId;
  final bool indexingDone;

  _PersonalSyncCursor copyWith({
    int? offset,
    int? emptyRetries,
    String? workflowId,
    bool? indexingDone,
  }) {
    return _PersonalSyncCursor(
      offset: offset ?? this.offset,
      emptyRetries: emptyRetries ?? this.emptyRetries,
      workflowId: workflowId ?? this.workflowId,
      indexingDone: indexingDone ?? this.indexingDone,
    );
  }
}
