import 'package:logging/logging.dart';

import '../database/database_service.dart';
import '../graphql/indexer_client.dart';

/// Service for fetching and ingesting tokens from the indexer.
class IndexerService {
  /// Creates an IndexerService.
  IndexerService({
    required IndexerClient client,
    required DatabaseService databaseService,
  })  : _client = client,
        _databaseService = databaseService {
    _log = Logger('IndexerService');
  }

  final IndexerClient _client;
  final DatabaseService _databaseService;
  late final Logger _log;

  /// Fetch and ingest tokens for a list of addresses.
  /// Returns the number of tokens ingested.
  Future<int> fetchTokensForAddresses({
    required List<String> addresses,
    int? limit,
    int? offset,
  }) async {
    try {
      _log.info('Fetching tokens for ${addresses.length} addresses');

      final tokens = await _client.fetchTokensByAddresses(
        addresses: addresses,
        limit: limit,
        offset: offset,
      );

      _log.info('Fetched ${tokens.length} tokens from indexer');

      // Ingest tokens for each address
      int totalIngested = 0;
      for (final address in addresses) {
        await _databaseService.ingestTokensForAddress(
          address: address,
          tokens: tokens,
        );
        
        // Count how many tokens were actually for this address
        final normalizedAddress = address.toUpperCase();
        final ownedCount = tokens.where((token) {
          final owners = token['owners'] as List?;
          if (owners == null || owners.isEmpty) {
            final currentOwner = token['currentOwner'] as String?;
            return currentOwner?.toUpperCase() == normalizedAddress;
          }
          return owners.any((owner) {
            final ownerAddr = 
                (owner as Map<String, dynamic>)['address'] as String?;
            return ownerAddr?.toUpperCase() == normalizedAddress;
          });
        }).length;
        
        totalIngested += ownedCount;
      }

      _log.info('Ingested $totalIngested tokens total');
      return totalIngested;
    } catch (e, stack) {
      _log.severe('Failed to fetch tokens for addresses', e, stack);
      rethrow;
    }
  }

  /// Fetch tokens by CIDs (for enriching DP1 items).
  Future<List<Map<String, dynamic>>> fetchTokensByCIDs({
    required List<String> cids,
  }) async {
    try {
      _log.info('Fetching ${cids.length} tokens by CIDs');
      final tokens = await _client.fetchTokensByCIDs(cids: cids);
      _log.info('Fetched ${tokens.length} tokens');
      return tokens;
    } catch (e, stack) {
      _log.severe('Failed to fetch tokens by CIDs', e, stack);
      rethrow;
    }
  }

  /// Reindex addresses (trigger indexer to scan addresses).
  /// Returns workflow IDs for tracking progress.
  Future<List<String>> reindexAddresses({
    required List<String> addresses,
  }) async {
    try {
      _log.info('Reindexing ${addresses.length} addresses');
      final workflowIds = await _client.indexAddresses(addresses: addresses);
      _log.info('Started reindexing with ${workflowIds.length} workflows');
      return workflowIds;
    } catch (e, stack) {
      _log.severe('Failed to reindex addresses', e, stack);
      rethrow;
    }
  }

  /// Check indexing status for workflow IDs.
  Future<Map<String, String>> getIndexingStatus({
    required List<String> workflowIds,
  }) async {
    try {
      final status = await _client.getIndexingStatus(workflowIds: workflowIds);
      return status;
    } catch (e, stack) {
      _log.severe('Failed to get indexing status', e, stack);
      rethrow;
    }
  }

  /// Poll indexing status until complete.
  /// Returns true if all workflows completed successfully.
  Future<bool> pollIndexingStatus({
    required List<String> workflowIds,
    Duration pollInterval = const Duration(seconds: 2),
    Duration timeout = const Duration(minutes: 5),
  }) async {
    final startTime = DateTime.now();

    while (true) {
      final elapsed = DateTime.now().difference(startTime);
      if (elapsed > timeout) {
        _log.warning('Indexing status polling timed out');
        return false;
      }

      final status = await getIndexingStatus(workflowIds: workflowIds);

      final allComplete = workflowIds.every((id) {
        final state = status[id];
        return state == 'completed' || state == 'failed';
      });

      if (allComplete) {
        final allSuccessful = workflowIds.every((id) {
          return status[id] == 'completed';
        });
        return allSuccessful;
      }

      await Future.delayed(pollInterval);
    }
  }
}
