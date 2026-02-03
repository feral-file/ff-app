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
  })  : _indexerService = indexerService,
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

    final tokens = await _indexerService.fetchTokensByAddresses(
      addresses: addresses,
      limit: limit,
      offset: offset,
    );

    int totalIngested = 0;
    for (final address in addresses) {
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
}

// End of file.

