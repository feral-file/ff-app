import 'package:app/domain/models/indexer/asset_token.dart';
import 'package:app/domain/models/indexer/changes/change.dart';
import 'package:app/domain/models/indexer/workflow.dart';
import 'package:app/infra/graphql/indexer_client.dart';
import 'package:app/infra/graphql/queries/changes_queries.dart';
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

  // The indexer schema uses Uint8 for `limit`, so we must never send > 255.
  //
  // The prior app additionally batched some flows more aggressively (e.g.
  // manual fetch by CID in batches of 40) to avoid overly large payloads.
  static const int _maxUint8Limit = 255;
  static const int _manualFetchCidsBatchSize = 40;
  static const int _defaultTokensPageSize = 50;
  static const List<String> _defaultChains = <String>[
    'eip155:1',
    'tezos:mainnet',
  ];

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
    required List<String> tokenCids,
  }) async {
    try {
      _log.info('Fetching ${tokenCids.length} tokens by tokenCids');
      final tokens = await _fetchTokensByCids(tokenCids: tokenCids);
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
      // Default behavior: QueryListTokensRequest page size is 50.
      final effectiveLimit = limit ?? _defaultTokensPageSize;
      final tokens = await _fetchTokens(
        owners: addresses,
        limit: effectiveLimit,
        offset: offset,
      );
      return tokens;
    } catch (e, stack) {
      _log.severe('Failed to fetch tokens by addresses', e, stack);
      rethrow;
    }
  }

  Future<List<AssetToken>> _fetchTokensByCids({
    required List<String> tokenCids,
  }) async {
    if (tokenCids.isEmpty) return const <AssetToken>[];

    // Legacy behavior: fetch manual tokens from indexer in batches of 40.
    final results = <AssetToken>[];
    for (final batch in _batchesOf(tokenCids, _manualFetchCidsBatchSize)) {
      final tokens = await _fetchTokens(
        tokenCids: batch,
        limit: batch.length.clamp(1, _maxUint8Limit),
        offset: 0,
      );
      results.addAll(tokens);
    }

    // Preserve requested order and dedupe by CID.
    return _orderTokensByCid(results, tokenCids);
  }

  /// Fetch tokens by indexer token IDs, optionally scoped to owners.
  ///
  /// This mirrors the old repo's `QueryListTokensRequest(tokenIds: ..., owners: ...)`
  /// usage in change-journal incremental sync.
  Future<List<AssetToken>> fetchTokensByTokenIds({
    required List<int> tokenIds,
    List<String> owners = const [],
    int? limit,
    int? offset,
  }) async {
    if (tokenIds.isEmpty) return const <AssetToken>[];

    // If tokenIds > 255, we must batch. We always fetch the full set then apply
    // offset/limit on the merged result to keep caller semantics stable.
    final results = <AssetToken>[];
    for (final batch in _batchesOf(tokenIds, _maxUint8Limit)) {
      final tokens = await _fetchTokens(
        tokenIds: batch,
        owners: owners.isEmpty ? null : owners,
        limit: batch.length.clamp(1, _maxUint8Limit),
        offset: 0,
      );
      results.addAll(tokens);
    }

    final ordered = _orderTokensById(results, tokenIds);
    return _applyOffsetLimit(ordered, offset: offset, limit: limit);
  }

  Future<List<AssetToken>> _fetchTokens({
    List<int>? tokenIds,
    List<String>? owners,
    List<String>? tokenCids,
    List<String>? chains,
    int? limit,
    int? offset,
  }) async {
    final vars = <String, dynamic>{};
    if (tokenIds != null) vars['token_ids'] = tokenIds;
    if (owners != null) vars['owners'] = owners;
    if (tokenCids != null) vars['token_cids'] = tokenCids;
    vars['chains'] = chains ?? _defaultChains;
    if (limit != null) vars['limit'] = limit;
    if (offset != null) vars['offset'] = offset;

    final data = await _client.query(
      doc: getTokens,
      vars: vars,
      subKey: 'tokens',
    );

    final items =
        (data?['items'] as List?)?.whereType<Map<Object?, Object?>>() ??
            const [];

    return items
        .map((e) => AssetToken.fromGraphQL(Map<String, dynamic>.from(e)))
        .toList();
  }

  static Iterable<List<T>> _batchesOf<T>(List<T> items, int batchSize) sync* {
    if (batchSize <= 0) {
      throw ArgumentError.value(batchSize, 'batchSize', 'must be > 0');
    }

    for (var i = 0; i < items.length; i += batchSize) {
      final end = (i + batchSize < items.length) ? i + batchSize : items.length;
      yield items.sublist(i, end);
    }
  }

  static List<AssetToken> _orderTokensByCid(
    List<AssetToken> tokens,
    List<String> requestedCids,
  ) {
    final byCid = <String, AssetToken>{};
    for (final t in tokens) {
      // Keep the first occurrence to preserve stable behavior under duplicates.
      byCid.putIfAbsent(t.cid, () => t);
    }

    final ordered = <AssetToken>[];
    for (final cid in requestedCids) {
      final token = byCid[cid];
      if (token != null) ordered.add(token);
    }
    return ordered;
  }

  static List<AssetToken> _orderTokensById(
    List<AssetToken> tokens,
    List<int> requestedIds,
  ) {
    final byId = <int, AssetToken>{};
    for (final t in tokens) {
      byId.putIfAbsent(t.id, () => t);
    }

    final ordered = <AssetToken>[];
    for (final id in requestedIds) {
      final token = byId[id];
      if (token != null) ordered.add(token);
    }
    return ordered;
  }

  static List<AssetToken> _applyOffsetLimit(
    List<AssetToken> items, {
    int? offset,
    int? limit,
  }) {
    final start = (offset ?? 0).clamp(0, items.length);
    final afterOffset = items.sublist(start);
    final lim = limit;
    if (lim == null) return afterOffset;
    return afterOffset.take(lim.clamp(0, afterOffset.length)).toList();
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
        doc: triggerOwnerIndexingList,
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
    final tokens = await fetchTokensByCIDs(tokenCids: [cid]);
    if (tokens.isEmpty) return null;
    return tokens.first;
  }
}
