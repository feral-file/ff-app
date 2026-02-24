import 'package:app/domain/models/indexer/asset_token.dart';
import 'package:app/infra/database/database_service.dart';
import 'package:app/infra/services/indexer_service.dart';
import 'package:logging/logging.dart';

/// Service for enriching playlist items with indexer token data.
///
/// Uses SQLite as the single source of truth instead of in-memory queues.
/// - Loads bare items (no token enrichment) from database
/// - Prioritizes: high (first 8 per playlist), then low priority items
/// - Enriches with tokens from indexer
/// - Updates items back to database
class DP1PlaylistItemsEnrichmentService {
  /// Creates a DP1PlaylistItemsEnrichmentService.
  DP1PlaylistItemsEnrichmentService({
    required IndexerService indexerService,
    required DatabaseService databaseService,
    bool Function()? shouldContinue,
  }) : _indexerService = indexerService,
       _databaseService = databaseService,
       _shouldContinue = shouldContinue ?? _alwaysContinue,
       _log = Logger('DP1PlaylistItemsEnrichmentService');

  final IndexerService _indexerService;
  final DatabaseService _databaseService;
  final bool Function() _shouldContinue;
  final Logger _log;

  static bool _alwaysContinue() => true;

  /// Maximum high-priority items per playlist.
  static const int highPriorityPerPlaylist = 8;

  /// Total high-priority items per batch (across all playlists).
  static const int highPriorityMaxItems = 48;

  /// Maximum items to load and process per batch.
  static const int maxBatchSize = 50;

  /// Deprecated: kept for backward compatibility with tests.
  @Deprecated('Use highPriorityPerPlaylist instead')
  static const int highPerPlaylist = highPriorityPerPlaylist;

  /// Deprecated: kept for backward compatibility with tests.
  @Deprecated('Use maxBatchSize instead')
  static const int indexerBatchSize = maxBatchSize;

  /// Placeholder enqueuePlaylist for backward compatibility.
  /// No-op since we now use database as source of truth.
  Future<void> enqueuePlaylist({
    required String playlistId,
    required dynamic items,
  }) async {
    _log.fine('enqueuePlaylist called (no-op; using database as source)');
  }

  /// Placeholder clear for backward compatibility.
  /// No-op since we now use database as source of truth.
  Future<void> clear() async {
    _log.fine('clear called (no-op; using database as source)');
  }

  /// Process all bare items from database: high priority first, then low.
  ///
  /// Loads bare items (only title, no enrichment fields) from database,
  /// prioritizes high (first 8 per playlist), then processes batches.
  Future<bool> processAll() async {
    var totalProcessed = 0;
    var batchCount = 0;
    var totalUpdated = 0;

    // Process high-priority items first by repeatedly pulling from DB.
    _log.info('Loading high-priority items from database (paged)...');
    while (true) {
      if (!_shouldContinue()) {
        _log.info('Enrichment paused before high-priority batch');
        return false;
      }
      batchCount++;
      try {
        final updated = await processNextHighPriorityBatch();
        if (updated == 0) {
          break;
        }
        totalProcessed += updated;
        totalUpdated += updated;
      } on Exception catch (e, stack) {
        _log.severe(
          'Failed to process high-priority batch $batchCount',
          e,
          stack,
        );
      }
    }

    // Then process low-priority items by repeatedly pulling from DB.
    _log.info('Loading low-priority items from database (paged)...');
    while (true) {
      if (!_shouldContinue()) {
        _log.info('Enrichment paused before low-priority batch');
        return false;
      }
      batchCount++;
      try {
        final updated = await processNextLowPriorityBatch();
        if (updated == 0) {
          break;
        }
        totalProcessed += updated;
        totalUpdated += updated;
      } on Exception catch (e, stack) {
        _log.severe(
          'Failed to process low-priority batch $batchCount',
          e,
          stack,
        );
      }
    }

    _log.info(
      'Enrichment complete: '
      'processed $totalProcessed items, '
      'updated $totalUpdated items in $batchCount batches',
    );
    return true;
  }

  /// Process the next high-priority enrichment batch.
  ///
  /// Returns the number of playlist items updated in this batch.
  Future<int> processNextHighPriorityBatch() async {
    if (!_shouldContinue()) return 0;
    late final List<EnrichmentWorkItem> highItems;
    try {
      highItems = await loadHighPriorityWorkItems();
    } on Exception catch (e, stack) {
      if (_isOperationCancelled(e)) {
        _log.info('High-priority enrichment query cancelled');
        return 0;
      }
      _log.severe('Failed to load high-priority bare items', e, stack);
      rethrow;
    }

    if (highItems.isEmpty) {
      return 0;
    }

    _log.info('Processing high-priority batch: ${highItems.length} items');
    return enrichWorkItems(highItems);
  }

  /// Process the next low-priority enrichment batch.
  ///
  /// Returns the number of playlist items updated in this batch.
  Future<int> processNextLowPriorityBatch() async {
    if (!_shouldContinue()) return 0;
    late final List<EnrichmentWorkItem> lowItems;
    try {
      lowItems = await loadLowPriorityWorkItems(limit: maxBatchSize);
    } on Exception catch (e, stack) {
      if (_isOperationCancelled(e)) {
        _log.info('Low-priority enrichment query cancelled');
        return 0;
      }
      _log.severe('Failed to load low-priority bare items', e, stack);
      rethrow;
    }

    if (lowItems.isEmpty) {
      return 0;
    }

    _log.info('Processing low-priority batch: ${lowItems.length} items');
    return enrichWorkItems(lowItems);
  }

  /// Load high-priority bare items from database.
  ///
  /// Returns first [highPriorityPerPlaylist] items from every playlist with
  /// unenriched items, ordered newest-playlist-first (UI order), capped at
  /// [highPriorityMaxItems] total. Spans as many playlists as needed to fill
  /// the batch, so small playlists do not leave the batch under-populated.
  Future<List<EnrichmentWorkItem>> loadHighPriorityWorkItems() async {
    final rows = await _databaseService.loadHighPriorityBareItems(
      maxPerPlaylist: highPriorityPerPlaylist,
      maxItems: highPriorityMaxItems,
    );
    final rowsWithCid = await _databaseService.extractTokenCidsFromBareRows(
      rows: rows,
    );
    return rowsWithCid
        .map(
          (row) => EnrichmentWorkItem(
            itemId: row.$1,
            cid: row.$2,
            playlistId: row.$3,
            position: row.$4,
          ),
        )
        .toList(growable: false);
  }

  /// Load low-priority bare items from database.
  ///
  /// Returns bare items (have only title set, no enrichment fields) beyond
  /// the high-priority set, ordered by creation date.
  Future<List<EnrichmentWorkItem>> loadLowPriorityWorkItems({
    required int limit,
  }) async {
    final rows = await _databaseService.loadLowPriorityBareItems(
      maxPerPlaylist: highPriorityPerPlaylist,
      maxTotal: limit,
    );
    final rowsWithCid = await _databaseService.extractTokenCidsFromBareRows(
      rows: rows,
    );
    return rowsWithCid
        .map(
          (row) => EnrichmentWorkItem(
            itemId: row.$1,
            cid: row.$2,
            playlistId: row.$3,
            position: row.$4,
          ),
        )
        .toList(growable: false);
  }

  /// Enrich provided work items in chunks of [maxBatchSize].
  ///
  /// Keeping a strict chunk size ensures indexer requests stay at 50 items.
  Future<int> enrichWorkItems(List<EnrichmentWorkItem> items) async {
    if (!_shouldContinue()) return 0;
    if (items.isEmpty) return 0;

    final cidToItemId = <String, String>{};
    for (final item in items) {
      cidToItemId[item.cid] = item.itemId;
    }
    return enrichCidToItemMap(cidToItemId);
  }

  /// Enrich a map of `{cid: itemId}`.
  ///
  /// Worker input is map-shaped so workers do not re-select bare rows from DB.
  Future<int> enrichCidToItemMap(Map<String, String> cidToItemId) async {
    if (!_shouldContinue()) return 0;
    if (cidToItemId.isEmpty) return 0;

    final entries = cidToItemId.entries.toList(growable: false);
    var totalUpdated = 0;
    for (var start = 0; start < entries.length; start += maxBatchSize) {
      if (!_shouldContinue()) break;
      final end = (start + maxBatchSize).clamp(0, entries.length);
      final chunk = entries.sublist(start, end);
      totalUpdated += await _enrichCidToItemChunk(chunk);
    }
    return totalUpdated;
  }

  Future<int> _enrichCidToItemChunk(
    List<MapEntry<String, String>> chunk,
  ) async {
    if (chunk.isEmpty) return 0;

    final cids = chunk.map((entry) => entry.key).toList(growable: false);
    _log.fine('Fetching ${cids.length} tokens from indexer...');
    final tokens = await _indexerService.fetchTokensByCIDs(tokenCids: cids);
    final tokensByCid = <String, AssetToken>{};
    for (final token in tokens) {
      tokensByCid[token.cid] = token;
    }

    final enrichments = <(String, AssetToken)>[];
    for (final entry in chunk) {
      final token = tokensByCid[entry.key];
      if (token == null) continue;
      enrichments.add((entry.value, token));
    }

    await _databaseService.enrichPlaylistItemsWithTokensBatch(
      enrichments: enrichments,
    );
    _log.fine('Updated ${enrichments.length} items in database');
    return enrichments.length;
  }
}

/// Bare playlist item selected for enrichment.
class EnrichmentWorkItem {
  /// Creates an [EnrichmentWorkItem].
  const EnrichmentWorkItem({
    required this.itemId,
    required this.cid,
    required this.playlistId,
    required this.position,
  });

  /// Item ID in database.
  final String itemId;

  /// CID for indexer lookup.
  final String cid;

  /// Playlist ID.
  final String playlistId;

  /// Position in playlist.
  final int position;
}

bool _isOperationCancelled(Object error) {
  return error.runtimeType.toString() == 'CancellationException' ||
      error.toString().contains('Operation was cancelled');
}
