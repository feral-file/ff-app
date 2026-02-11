import 'dart:async';
import 'dart:isolate';

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
    int maxEnrichmentWorkers = 4,
  }) : _enrichmentService = enrichmentService,
       _indexerSyncService = indexerSyncService,
       _maxEnrichmentWorkers = maxEnrichmentWorkers > 0
           ? maxEnrichmentWorkers
           : 1,
       _log = Logger('IndexerEnrichmentSchedulerService');

  final DP1PlaylistItemsEnrichmentService _enrichmentService;
  final IndexerSyncService _indexerSyncService;
  final int _maxEnrichmentWorkers;
  final Logger _log;

  static const int _batchSize = 50;
  static const int _lowBurstBatchSize = _batchSize * 2;
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
    } on Object catch (e, stack) {
      if (_isOperationCancelled(e)) {
        _log.info('Feed enrichment cancelled while draining');
        return false;
      }
      _log.severe('Feed enrichment failed', e, stack);
      rethrow;
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
    } on Object catch (e, stack) {
      if (_isOperationCancelled(e)) {
        _log.info('Address queue cancelled while draining');
        return false;
      }
      _log.severe('Address queue failed', e, stack);
      rethrow;
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
      final plan = await _buildEnrichmentPlan();
      if (plan.assignments.isEmpty) {
        return;
      }

      final updatedByWorker = await Future.wait<int>(
        plan.assignments.map(_runEnrichmentAssignment),
      );

      final totalUpdated = updatedByWorker.fold<int>(0, (sum, v) => sum + v);
      if (totalUpdated <= 0) {
        return;
      }

      if (plan.reservedWorkers > 0) {
        _hasPendingEnrichmentSignal = true;
      }
    }
  }

  Future<int> _runEnrichmentAssignment(
    _EnrichmentAssignment assignment,
  ) async {
    if (assignment.cidToItemId.isEmpty) return 0;
    return _enrichmentService.enrichCidToItemMap(assignment.cidToItemId);
  }

  Future<_EnrichmentPlan> _buildEnrichmentPlan() async {
    final maxHighPrefetch = _maxEnrichmentWorkers * _batchSize;
    final highItems = await _enrichmentService.loadHighPriorityWorkItems(
      limit: maxHighPrefetch,
    );

    final hasHigh = highItems.isNotEmpty;
    final reservedWorkers = hasHigh && _maxEnrichmentWorkers > 1 ? 1 : 0;
    final activeWorkers = (_maxEnrichmentWorkers - reservedWorkers).clamp(
      1,
      64,
    );
    final lowItems = await _enrichmentService.loadLowPriorityWorkItems(
      limit: hasHigh
          ? activeWorkers * _lowBurstBatchSize
          : _maxEnrichmentWorkers * _lowBurstBatchSize,
    );

    final payload = <String, Object>{
      'highCidItemPairs': highItems
          .map((item) => <String>[item.cid, item.itemId])
          .toList(growable: false),
      'lowCidItemPairs': lowItems
          .map((item) => <String>[item.cid, item.itemId])
          .toList(growable: false),
      'maxWorkers': _maxEnrichmentWorkers,
      'activeWorkers': activeWorkers,
      'batchSize': _batchSize,
      'lowBurstBatchSize': _lowBurstBatchSize,
      'hasHighPriority': hasHigh,
    };
    final selected = await Isolate.run(
      () => _buildCidItemAssignmentsOnIsolate(payload),
    );

    final assignments = selected
        .map(
          (cidToItemId) => _EnrichmentAssignment(cidToItemId: cidToItemId),
        )
        .where((assignment) => assignment.cidToItemId.isNotEmpty)
        .toList(growable: false);

    return _EnrichmentPlan(
      assignments: assignments,
      reservedWorkers: reservedWorkers,
    );
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

class _EnrichmentPlan {
  const _EnrichmentPlan({
    required this.assignments,
    this.reservedWorkers = 0,
  });

  final List<_EnrichmentAssignment> assignments;
  final int reservedWorkers;
}

class _EnrichmentAssignment {
  const _EnrichmentAssignment({
    required this.cidToItemId,
  });

  final Map<String, String> cidToItemId;
}

bool _isOperationCancelled(Object error) {
  return error.runtimeType.toString() == 'CancellationException' ||
      error.toString().contains('Operation was cancelled');
}

List<Map<String, String>> _buildCidItemAssignmentsOnIsolate(
  Map<String, Object> payload,
) {
  final highCidItemPairs = (payload['highCidItemPairs']! as List)
      .map((pair) => List<String>.from(pair as List))
      .toList(growable: false);
  final lowCidItemPairs = (payload['lowCidItemPairs']! as List)
      .map((pair) => List<String>.from(pair as List))
      .toList(growable: false);
  final maxWorkers = payload['maxWorkers']! as int;
  final activeWorkers = payload['activeWorkers']! as int;
  final batchSize = payload['batchSize']! as int;
  final lowBurstBatchSize = payload['lowBurstBatchSize']! as int;
  final hasHighPriority = payload['hasHighPriority']! as bool;

  final highQueue = List<List<String>>.from(highCidItemPairs);
  final lowQueue = List<List<String>>.from(lowCidItemPairs);

  List<List<String>> takeFrom(List<List<String>> queue, int count) {
    if (queue.isEmpty || count <= 0) return const <List<String>>[];
    final takeCount = count < queue.length ? count : queue.length;
    final items = queue.sublist(0, takeCount);
    queue.removeRange(0, takeCount);
    return items;
  }

  Map<String, String> toCidItemMap(List<List<String>> pairs) {
    final map = <String, String>{};
    for (final pair in pairs) {
      if (pair.length < 2) continue;
      final cid = pair[0];
      final itemId = pair[1];
      if (cid.isEmpty || itemId.isEmpty) continue;
      map[cid] = itemId;
    }
    return map;
  }

  final assignments = <Map<String, String>>[];

  if (!hasHighPriority) {
    for (var worker = 0; worker < maxWorkers && lowQueue.isNotEmpty; worker++) {
      assignments.add(
        toCidItemMap(takeFrom(lowQueue, lowBurstBatchSize)),
      );
    }
    return assignments.where((m) => m.isNotEmpty).toList(growable: false);
  }

  final firstPairs = <List<String>>[
    ...takeFrom(highQueue, batchSize),
  ];
  if (firstPairs.length < batchSize && lowQueue.isNotEmpty) {
    firstPairs.addAll(
      takeFrom(lowQueue, batchSize - firstPairs.length),
    );
  }
  final firstAssignment = toCidItemMap(firstPairs);
  if (firstAssignment.isNotEmpty) {
    assignments.add(firstAssignment);
  }

  for (
    var worker = 1;
    worker < activeWorkers && (highQueue.isNotEmpty || lowQueue.isNotEmpty);
    worker++
  ) {
    final pairs = <List<String>>[];
    if (highQueue.isNotEmpty) {
      pairs.addAll(takeFrom(highQueue, batchSize));
      if (pairs.length < batchSize && lowQueue.isNotEmpty) {
        pairs.addAll(takeFrom(lowQueue, batchSize - pairs.length));
      }
    } else {
      pairs.addAll(takeFrom(lowQueue, lowBurstBatchSize));
    }

    final assignment = toCidItemMap(pairs);
    if (assignment.isNotEmpty) {
      assignments.add(assignment);
    }
  }

  return assignments.where((m) => m.isNotEmpty).toList(growable: false);
}
