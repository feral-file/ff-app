import 'package:app/domain/models/indexer/asset_token.dart';
import 'package:app/infra/database/database_service.dart';
import 'package:app/infra/services/indexer_service.dart';
import 'package:logging/logging.dart';

/// Orchestrates indexer fetch + local ingestion for address playlists.
///
/// This intentionally mirrors the legacy architecture:
/// - `IndexerService` is network-only (portable/auditable).
/// - `IndexerSyncService` handles offline-first persistence via `DatabaseService`.
class IndexerSyncService {
  IndexerSyncService({
    required IndexerService indexerService,
    required DatabaseService databaseService,
  }) : _indexerService = indexerService,
       _databaseService = databaseService,
       _log = Logger('IndexerSyncService');

  final IndexerService _indexerService;
  final DatabaseService _databaseService;
  final Logger _log;

  /// Fetch tokens for addresses and ingest them into address playlists.
  ///
  /// Returns the number of tokens ingested for the provided addresses.
  Future<int> syncTokensForAddresses({
    required List<String> addresses,
    int? limit,
    int? offset,
  }) async {
    _log.info('Syncing tokens for ${addresses.length} addresses');
    final queryAddresses = addresses
        .map(_normalizeAddressForIndexerQuery)
        .toList(growable: false);

    final tokens = await _indexerService.fetchTokensByAddresses(
      addresses: queryAddresses,
      limit: limit,
      offset: offset,
    );

    var totalIngested = 0;
    for (final address in queryAddresses) {
      await _databaseService.ingestTokensForAddress(
        address: address,
        tokens: tokens,
      );

      final normalizedAddress = address.toUpperCase();
      final ownedCount = tokens.where((AssetToken token) {
        final owners = token.owners?.items ?? const <Owner>[];
        if (owners.isEmpty) {
          return token.currentOwner?.toUpperCase() == normalizedAddress;
        }
        return owners.any(
          (owner) => owner.ownerAddress.toUpperCase() == normalizedAddress,
        );
      }).length;

      totalIngested += ownedCount;
    }

    _log.info('Synced $totalIngested tokens total');
    return totalIngested;
  }

  /// Fetch and ingest one paged batch for a single address playlist.
  ///
  /// Returns the fetched page count and next `offset` cursor.
  Future<AddressSyncPageResult> syncTokensPageForAddress({
    required String address,
    int? limit,
    int? offset,
  }) async {
    final queryAddress = _normalizeAddressForIndexerQuery(address);
    final page = await _indexerService.fetchTokensPageByAddresses(
      addresses: <String>[queryAddress],
      limit: limit,
      offset: offset,
    );

    await _databaseService.ingestTokensForAddress(
      address: queryAddress,
      tokens: page.tokens,
    );

    return AddressSyncPageResult(
      fetchedCount: page.tokens.length,
      nextOffset: page.nextOffset,
    );
  }

  String _normalizeAddressForIndexerQuery(String address) {
    if (address.startsWith('0X')) {
      return '0x${address.substring(2)}';
    }
    return address;
  }
}

class AddressSyncPageResult {
  /// Creates one page result for address token sync.
  const AddressSyncPageResult({
    required this.fetchedCount,
    this.nextOffset,
  });

  /// Number of tokens fetched in the page.
  final int fetchedCount;

  /// Cursor offset for requesting the next page.
  final int? nextOffset;
}

// End of file.
