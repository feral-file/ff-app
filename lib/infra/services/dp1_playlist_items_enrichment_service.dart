import 'dart:async';
import 'dart:collection';

import 'package:app/domain/models/dp1/dp1_playlist_item.dart';
import 'package:app/domain/models/indexer/asset_token.dart';
import 'package:app/domain/models/playlist_item.dart';
import 'package:app/infra/database/converters.dart';
import 'package:app/infra/database/database_service.dart';
import 'package:app/infra/services/indexer_service.dart';
import 'package:logging/logging.dart';
import 'package:synchronized/synchronized.dart';

/// Task for enriching a playlist item with indexer token data.
class EnrichmentTask {
  /// Creates an enrichment task.
  const EnrichmentTask({
    required this.playlistId,
    required this.position,
    required this.dp1Item,
    required this.cid,
  });

  /// Playlist ID this item belongs to.
  final String playlistId;

  /// Position in playlist.
  final int position;

  /// DP1 playlist item (bare).
  final DP1PlaylistItem dp1Item;

  /// Computed CID for indexer lookup.
  final String cid;
}

/// Service for enriching playlist items with indexer token data.
///
/// Uses a locked high/low priority queue to batch indexer requests:
/// - High priority: first 8 items per playlist (for carousel preview)
/// - Low priority: remaining items
/// - Batch size: 50 tokens per indexer request
class DP1PlaylistItemsEnrichmentService {
  /// Creates a DP1PlaylistItemsEnrichmentService.
  DP1PlaylistItemsEnrichmentService({
    required IndexerService indexerService,
    required DatabaseService databaseService,
  })  : _indexerService = indexerService,
        _databaseService = databaseService,
        _log = Logger('DP1PlaylistItemsEnrichmentService');

  final IndexerService _indexerService;
  final DatabaseService _databaseService;
  final Logger _log;

  /// Lock for queue operations.
  final Lock _lock = Lock();

  /// High priority queue (first 8 items per playlist).
  final Queue<EnrichmentTask> _highQueue = Queue<EnrichmentTask>();

  /// Low priority queue (remaining items).
  final Queue<EnrichmentTask> _lowQueue = Queue<EnrichmentTask>();

  /// Number of high-priority items per playlist.
  static const int highPerPlaylist = 8;

  /// Batch size for indexer requests.
  static const int indexerBatchSize = 50;

  /// Enqueue tasks for a playlist's items.
  ///
  /// First [highPerPlaylist] items go to high queue, rest go to low queue.
  Future<void> enqueuePlaylist({
    required String playlistId,
    required List<DP1PlaylistItem> items,
  }) async {
    await _lock.synchronized(() {
      for (var i = 0; i < items.length; i++) {
        final item = items[i];
        final cid = item.cid;
        if (cid == null || cid.isEmpty) {
          _log.fine('Skipping item without CID: ${item.id}');
          continue;
        }

        final task = EnrichmentTask(
          playlistId: playlistId,
          position: i,
          dp1Item: item,
          cid: cid,
        );

        if (i < highPerPlaylist) {
          _highQueue.add(task);
        } else {
          _lowQueue.add(task);
        }
      }
      _log.info(
        'Enqueued ${items.length} items for playlist $playlistId '
        '(high: ${_highQueue.length}, low: ${_lowQueue.length})',
      );
    });
  }

  /// Take a batch of tasks from queues (high priority first).
  ///
  /// Returns up to [indexerBatchSize] tasks, draining high queue first,
  /// then filling remaining capacity from low queue.
  Future<List<EnrichmentTask>> _takeBatch() async {
    return _lock.synchronized(() {
      final batch = <EnrichmentTask>[];

      // Drain high queue first
      while (_highQueue.isNotEmpty && batch.length < indexerBatchSize) {
        batch.add(_highQueue.removeFirst());
      }

      // Fill remaining capacity from low queue
      while (_lowQueue.isNotEmpty && batch.length < indexerBatchSize) {
        batch.add(_lowQueue.removeFirst());
      }

      return batch;
    });
  }

  /// Check if queues are empty.
  Future<bool> isEmpty() async {
    return _lock.synchronized(() {
      return _highQueue.isEmpty && _lowQueue.isEmpty;
    });
  }

  /// Get queue sizes (for logging/debugging).
  Future<({int high, int low})> getQueueSizes() async {
    return _lock.synchronized(() {
      return (high: _highQueue.length, low: _lowQueue.length);
    });
  }

  /// Clear all queues.
  Future<void> clear() async {
    await _lock.synchronized(() {
      _highQueue.clear();
      _lowQueue.clear();
    });
  }

  /// Process all queued enrichment tasks.
  ///
  /// Drains queues in batches of [indexerBatchSize], fetches tokens from
  /// indexer, converts to enriched [PlaylistItem]s, and batch-upserts to DB.
  Future<void> processAll() async {
    var totalProcessed = 0;
    var batchCount = 0;

    while (true) {
      final batch = await _takeBatch();
      if (batch.isEmpty) {
        break;
      }

      batchCount++;
      final sizes = await getQueueSizes();
      _log.info(
        'Processing batch $batchCount: ${batch.length} tasks '
        '(remaining: high=${sizes.high}, low=${sizes.low})',
      );

      try {
        await _processBatch(batch);
        totalProcessed += batch.length;
      } on Exception catch (e, stack) {
        _log.severe('Failed to process batch $batchCount', e, stack);
        // Continue processing remaining batches even if one fails
      }
    }

    _log.info(
      'Enrichment complete: '
      'processed $totalProcessed items in $batchCount batches',
    );
  }

  /// Process a single batch of enrichment tasks.
  Future<void> _processBatch(List<EnrichmentTask> batch) async {
    if (batch.isEmpty) return;

    // Extract CIDs for indexer lookup
    final cids = batch.map((task) => task.cid).toList();

    // Fetch tokens from indexer
    final tokens = await _indexerService.fetchTokensByCIDs(tokenCids: cids);
    final tokensByCid = <String, AssetToken>{};
    for (final token in tokens) {
      tokensByCid[token.cid] = token;
    }

    _log.fine('Fetched ${tokens.length}/${cids.length} tokens from indexer');

    // Convert DP1 items + tokens to enriched PlaylistItems
    final enrichedItems = <PlaylistItem>[];
    for (final task in batch) {
      final token = tokensByCid[task.cid];
      final enrichedItem = DatabaseConverters.dp1PlaylistItemToPlaylistItem(
        task.dp1Item,
        token: token,
      );
      enrichedItems.add(enrichedItem);
    }

    // Batch-upsert enriched items to database
    await _databaseService.upsertPlaylistItemsEnriched(enrichedItems);

    _log.fine(
      'Upserted ${enrichedItems.length} enriched items to database',
    );
  }
}
