import 'package:app/domain/models/indexer/asset_token.dart';
import 'package:app/domain/models/indexer/changes/change.dart';
import 'package:app/domain/models/indexer/workflow.dart';
import 'package:app/infra/graphql/indexer_client.dart';
import 'package:app/infra/graphql/queries/changes_queries.dart';
import 'package:app/infra/graphql/queries/indexing_status_queries.dart';
import 'package:app/infra/graphql/queries/mutations.dart';
import 'package:app/infra/graphql/queries/token_queries.dart';
import 'package:app/infra/graphql/queries/workflow_queries.dart';
import 'package:logging/logging.dart';

/// Network-only service for talking to the indexer API.
///
/// This intentionally does NOT persist data. Offline-first persistence lives in
/// `DatabaseService` and higher-level orchestration services.
class IndexerService {
  /// Creates an IndexerService.
  IndexerService({
    required IndexerClient client,
  })  : _client = client,
        _log = Logger('IndexerService');

  final IndexerClient _client;
  final Logger _log;

  /// Fetch change journal entries.
  Future<ChangeList> getChanges(QueryChangesRequest request) async {
    try {
      _log.info(
        'Fetching changes (addresses: ${request.addresses.length}, tokenCids: ${request.tokenCids.length}, anchor: ${request.anchor})',
      );

      final data = await _client.query(
        doc: getChangesQuery,
        vars: request.toJson(),
        subKey: 'changes',
      );

      if (data == null) {
        throw Exception('Indexer returned null changes payload');
      }

      return ChangeList.fromJson(data);
    } catch (e, stack) {
      _log.severe('Failed to fetch changes', e, stack);
      rethrow;
    }
  }

  /// Fetch tokens by CIDs (for enriching DP1 items).
  Future<List<AssetToken>> fetchTokensByCIDs({
    required List<String> cids,
  }) async {
    try {
      _log.info('Fetching ${cids.length} tokens by CIDs');
      final tokens = await _fetchTokensByCids(cids: cids);
      _log.info('Fetched ${tokens.length} tokens');
      return tokens;
    } catch (e, stack) {
      _log.severe('Failed to fetch tokens by CIDs', e, stack);
      rethrow;
    }
  }

  /// Fetch tokens by owner addresses without ingesting.
  Future<List<AssetToken>> fetchTokensByAddresses({
    required List<String> addresses,
    int? limit,
    int? offset,
  }) async {
    try {
      final data = await _client.query(
        doc: getTokensByAddressesQuery,
        vars: {
          'owners': addresses,
          'limit': limit,
          'offset': offset,
        },
        subKey: 'tokens',
      );

      final items =
          (data?['items'] as List?)?.whereType<Map<Object?, Object?>>() ??
              const [];

      return items
          .map((e) => AssetToken.fromGraphQL(Map<String, dynamic>.from(e)))
          .toList();
    } catch (e, stack) {
      _log.severe('Failed to fetch tokens by addresses', e, stack);
      rethrow;
    }
  }

  Future<List<AssetToken>> _fetchTokensByCids({
    required List<String> cids,
  }) async {
    final data = await _client.query(
      doc: getTokensByCidsQuery,
      vars: {
        'cids': cids,
      },
      subKey: 'tokens',
    );

    final items =
        (data?['items'] as List?)?.whereType<Map<Object?, Object?>>() ??
            const [];

    return items
        .map((e) => AssetToken.fromGraphQL(Map<String, dynamic>.from(e)))
        .toList();
  }

  /// Reindex addresses (trigger indexer to scan addresses).
  /// Returns workflow IDs for tracking progress.
  Future<List<String>> reindexAddresses({
    required List<String> addresses,
  }) async {
    try {
      _log.info('Reindexing ${addresses.length} addresses');
      final data = await _client.mutate(
        doc: indexAddressesMutation,
        vars: {'addresses': addresses},
        subKey: 'indexAddresses',
      );

      final workflowIds =
          (data?['workflowIds'] as List?)?.whereType<String>().toList() ??
              const <String>[];
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
      final data = await _client.query(
        doc: indexingStatusQuery,
        vars: {'workflowIds': workflowIds},
      );

      final statuses = (data?['indexingStatus'] as List?)
              ?.whereType<Map<Object?, Object?>>()
              .map(
                (item) => MapEntry(
                  (item['workflowId'] as String?) ?? '',
                  (item['status'] as String?) ?? '',
                ),
              )
              .where((e) => e.key.isNotEmpty)
              .toList() ??
          const <MapEntry<String, String>>[];

      return Map<String, String>.fromEntries(statuses);
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

      await Future<void>.delayed(pollInterval);
    }
  }

  /// Index a list of addresses and return per-address workflow IDs.
  Future<List<AddressIndexingResult>> indexAddressesList(
    List<String> addresses,
  ) async {
    if (addresses.isEmpty) {
      throw ArgumentError('addresses must not be empty');
    }

    try {
      final data = await _client.mutate(
        doc: triggerAddressIndexingList,
        vars: {
          'addresses': addresses,
        },
        subKey: 'triggerAddressIndexing',
      );

      if (data == null) {
        throw Exception('Indexer returned null triggerAddressIndexing payload');
      }

      final jobs = data['jobs'];
      if (jobs is! List) {
        throw Exception('Indexer returned invalid jobs payload');
      }

      return jobs
          .whereType<Map<Object?, Object?>>()
          .map((e) =>
              AddressIndexingResult.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (e, stack) {
      _log.severe('Failed to trigger address indexing', e, stack);
      rethrow;
    }
  }

  /// Get address indexing job status by workflowId (no runId needed).
  Future<AddressIndexingJobResponse> getAddressIndexingJobStatus({
    required String workflowId,
  }) async {
    if (workflowId.isEmpty) {
      throw ArgumentError('workflowId must not be empty');
    }

    try {
      final data = await _client.query(
        doc: addressIndexingJobStatusQuery,
        vars: {
          'workflow_id': workflowId,
        },
        subKey: 'indexingJob',
      );

      if (data == null) {
        throw Exception('Indexer returned null indexingJob payload');
      }

      return AddressIndexingJobResponse.fromJson(data);
    } catch (e, stack) {
      _log.severe('Failed to fetch address indexing job status', e, stack);
      rethrow;
    }
  }

  /// Get a single token by CID.
  ///
  /// Note: This uses `fetchTokensByCIDs` under the hood to keep the client
  /// surface minimal and auditable.
  Future<AssetToken?> getTokenByCid(String cid) async {
    if (cid.isEmpty) return null;
    final tokens = await fetchTokensByCIDs(cids: [cid]);
    if (tokens.isEmpty) return null;
    return tokens.first;
  }
}
