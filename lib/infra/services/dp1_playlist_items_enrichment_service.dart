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
  })  : _indexerService = indexerService,
        _databaseService = databaseService,
        _log = Logger('DP1PlaylistItemsEnrichmentService');

  final IndexerService _indexerService;
  final DatabaseService _databaseService;
  final Logger _log;

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
  Future<void> processAll() async {
    var totalProcessed = 0;
    var batchCount = 0;
    var totalUpdated = 0;

    // Process high-priority items first by repeatedly pulling from DB.
    _log.info('Loading high-priority items from database (paged)...');
    while (true) {
      final highItems = await _loadHighPriorityBareItems();
      if (highItems.isEmpty) break;

      batchCount++;

      _log.info(
        'Processing high-priority batch $batchCount: '
        '${highItems.length} items',
      );
      try {
        final updated = await _processBatch(highItems);
        totalProcessed += highItems.length;
        totalUpdated += updated;
        if (updated == 0) {
          _log.warning(
            'No high-priority items were updated in batch $batchCount; '
            'stopping to avoid reprocessing the same rows.',
          );
          break;
        }
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
      final lowItems = await _loadLowPriorityBareItems();
      if (lowItems.isEmpty) break;

      batchCount++;

      _log.info(
        'Processing low-priority batch $batchCount: '
        '${lowItems.length} items',
      );
      try {
        final updated = await _processBatch(lowItems);
        totalProcessed += lowItems.length;
        totalUpdated += updated;
        if (updated == 0) {
          _log.warning(
            'No low-priority items were updated in batch $batchCount; '
            'stopping to avoid reprocessing the same rows.',
          );
          break;
        }
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
    return rows
        .map((row) {
          final cid = _databaseService.buildTokenCidFromProvenanceJson(row.$2);
          if (cid == null || cid.isEmpty) {
            return null;
          }

          return _BareItem(
              itemId: row.$1,
              cid: cid,
              playlistId: row.$3,
              position: row.$4,
            );
        })
        .whereType<_BareItem>()
        .toList();
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
    return rows
        .map((row) {
          final cid = _databaseService.buildTokenCidFromProvenanceJson(row.$2);
          if (cid == null || cid.isEmpty) {
            return null;
          }

          return _BareItem(
              itemId: row.$1,
              cid: cid,
              playlistId: row.$3,
              position: row.$4,
            );
        })
        .whereType<_BareItem>()
        .toList();
  }

  /// Process a batch of bare items.
  ///
  /// Fetches tokens from indexer and updates items in database.
  Future<int> _processBatch(List<_BareItem> batch) async {
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

    final validEnrichments =
        enrichments.whereType<(String, AssetToken)>().toList();
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
