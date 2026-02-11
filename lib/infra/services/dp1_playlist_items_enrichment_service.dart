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
    late final List<_BareItem> highItems;
    try {
      highItems = await _loadHighPriorityBareItems();
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
    return _processBatch(highItems);
  }

  /// Process the next low-priority enrichment batch.
  ///
  /// Returns the number of playlist items updated in this batch.
  Future<int> processNextLowPriorityBatch() async {
    if (!_shouldContinue()) return 0;
    late final List<_BareItem> lowItems;
    try {
      lowItems = await _loadLowPriorityBareItems();
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
    return _processBatch(lowItems);
  }

  /// Load high-priority bare items from database.
  ///
  /// Returns first [highPriorityPerPlaylist] items per playlist that are bare
  /// (have only title set, no enrichment fields), ordered by creation date.
  Future<List<_BareItem>> _loadHighPriorityBareItems() async {
    final rows = await _databaseService.loadHighPriorityBareItems(
      maxPerPlaylist: highPriorityPerPlaylist,
      maxTotal: maxBatchSize,
    );
    final rowsWithCid = await _databaseService.extractTokenCidsFromBareRows(
      rows: rows,
    );
    return rowsWithCid
        .map(
          (row) => _BareItem(
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
  Future<List<_BareItem>> _loadLowPriorityBareItems() async {
    final rows = await _databaseService.loadLowPriorityBareItems(
      maxPerPlaylist: highPriorityPerPlaylist,
      maxTotal: maxBatchSize,
    );
    final rowsWithCid = await _databaseService.extractTokenCidsFromBareRows(
      rows: rows,
    );
    return rowsWithCid
        .map(
          (row) => _BareItem(
            itemId: row.$1,
            cid: row.$2,
            playlistId: row.$3,
            position: row.$4,
          ),
        )
        .toList(growable: false);
  }

  /// Process a batch of bare items.
  ///
  /// Fetches tokens from indexer and updates items in database.
  Future<int> _processBatch(List<_BareItem> batch) async {
    if (!_shouldContinue()) return 0;
    if (batch.isEmpty) return 0;

    // Extract and de-dupe CIDs for indexer lookup.
    final cids = batch.map((item) => item.cid).toSet().toList();

    // Fetch tokens from indexer
    _log.fine('Fetching ${cids.length} tokens from indexer...');
    final tokens = await _indexerService.fetchTokensByCIDs(tokenCids: cids);
    final tokensByCid = <String, AssetToken>{};
    for (final token in tokens) {
      tokensByCid[token.cid] = token;
    }

    _log.fine('Fetched ${tokens.length}/${cids.length} tokens from indexer');

    // Build enrichment updates in parallel, then persist in one transaction.
    final enrichments = await Future.wait(
      batch.map((item) async {
        final token = tokensByCid[item.cid];
        if (token == null) {
          _log.fine('No token found for CID ${item.cid}');
          return null;
        }
        return (item.itemId, token);
      }),
    );

    final validEnrichments = enrichments
        .whereType<(String, AssetToken)>()
        .toList();
    await _databaseService.enrichPlaylistItemsWithTokensBatch(
      enrichments: validEnrichments,
    );

    _log.fine('Updated ${validEnrichments.length} items in database');
    return validEnrichments.length;
  }
}

/// Internal model for bare playlist items from database.
class _BareItem {
  /// Creates a _BareItem.
  const _BareItem({
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
