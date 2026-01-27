import 'package:graphql/client.dart';

/// GraphQL client for the indexer service.
/// Handles fetching tokens from the indexer API.
class IndexerClient {
  /// Creates an IndexerClient.
  IndexerClient({
    required String endpoint,
    this.defaultHeaders = const {},
  }) : _client = GraphQLClient(
          link: HttpLink(
            endpoint,
            defaultHeaders: defaultHeaders,
          ),
          cache: GraphQLCache(),
        );

  final GraphQLClient _client;

  /// Default headers for requests.
  final Map<String, String> defaultHeaders;

  /// Fetch tokens for a list of owner addresses.
  /// Uses the actual indexer-v2 API schema.
  Future<List<Map<String, dynamic>>> fetchTokensByAddresses({
    required List<String> addresses,
    int? limit,
    int? offset,
  }) async {
    const query = r'''
      query GetTokensByAddresses(
        $owners: [String!]
        $limit: Uint8
        $offset: Uint64
      ) {
        tokens(
          owners: $owners
          limit: $limit
          offset: $offset
        ) {
          items {
            id
            token_cid
            chain
            contract_address
            token_number
            current_owner
            updated_at
            metadata {
              name
              description
              image_url
              animation_url
              mime_type
              artists {
                name
                did
              }
            }
            owners {
              items {
                owner_address
                quantity
              }
            }
            provenance_events {
              items {
                event_type
                from_address
                to_address
                tx_hash
                timestamp
                chain
              }
            }
            enrichment_source {
              name
              description
              image_url
              animation_url
              mime_type
              artists {
                name
                did
              }
            }
            metadata_media_assets {
              source_url
              mime_type
              variant_urls
            }
            enrichment_source_media_assets {
              source_url
              mime_type
              variant_urls
            }
          }
          offset
          total
        }
      }
    ''';

    final result = await _client.query(
      QueryOptions(
        document: gql(query),
        variables: {
          'owners': addresses,
          'limit': limit,
          'offset': offset,
        },
      ),
    );

    if (result.hasException) {
      throw Exception('GraphQL error: ${result.exception}');
    }

    final tokensResponse = result.data?['tokens'] as Map<String, dynamic>?;
    final tokens = (tokensResponse?['items'] as List?)
            ?.map((token) => token as Map<String, dynamic>)
            .toList() ??
        [];

    // Transform to match expected format
    return tokens.map((token) {
      final metadata = token['metadata'] as Map<String, dynamic>?;
      final enrichmentSource =
          token['enrichment_source'] as Map<String, dynamic>?;
      final metadataMediaAssets = token['metadata_media_assets'] as List?;
      final enrichmentSourceMediaAssets =
          token['enrichment_source_media_assets'] as List?;

      // Get thumbnail URL - enrichment source takes priority
      String? thumbnailUrl = enrichmentSource?['image_url'] as String? ??
          metadata?['image_url'] as String?;

      // Try to get variant URLs for 'xs' size
      if (thumbnailUrl != null && thumbnailUrl.isNotEmpty) {
        // Check enrichment source media assets first
        final enrichmentAsset =
            enrichmentSourceMediaAssets?.cast<Map<String, dynamic>>().firstWhere(
                  (asset) => asset['source_url'] == thumbnailUrl,
                  orElse: () => <String, dynamic>{},
                );
        if (enrichmentAsset != null && enrichmentAsset.isNotEmpty) {
          final variantUrls = enrichmentAsset['variant_urls'] as Map?;
          if (variantUrls != null) {
            final xsUrl = variantUrls['xs'] ?? variantUrls.values.firstOrNull;
            if (xsUrl != null) thumbnailUrl = xsUrl as String;
          }
        } else {
          // Fallback to metadata media assets
          final metadataAsset =
              metadataMediaAssets?.cast<Map<String, dynamic>>().firstWhere(
                    (asset) => asset['source_url'] == thumbnailUrl,
                    orElse: () => <String, dynamic>{},
                  );
          if (metadataAsset != null && metadataAsset.isNotEmpty) {
            final variantUrls = metadataAsset['variant_urls'] as Map?;
            if (variantUrls != null) {
              final xsUrl =
                  variantUrls['xs'] ?? variantUrls.values.firstOrNull;
              if (xsUrl != null) thumbnailUrl = xsUrl as String;
            }
          }
        }
      }

      return {
        'id': token['token_cid'] ?? token['id'],
        'contractAddress': token['contract_address'],
        'tokenId': token['token_number']?.toString(),
        'blockchain': token['chain'],
        'title': enrichmentSource?['name'] ?? metadata?['name'],
        'description':
            enrichmentSource?['description'] ?? metadata?['description'],
        'thumbnailUrl': thumbnailUrl,
        'previewUrl': enrichmentSource?['animation_url'] ??
            metadata?['animation_url'],
        'owners': ((token['owners'] as Map?)?['items'] as List?)
                ?.map((o) => {
                      'address': (o as Map)['owner_address'],
                      'blockchain': o['blockchain'],
                    })
                .toList() ??
            [],
        'provenance': ((token['provenance_events'] as Map?)?['items'] as List?)
                ?.map((p) => {
                      'txHash': (p as Map)['tx_hash'],
                      'fromAddress': p['from_address'],
                      'toAddress': p['to_address'],
                      'timestamp': p['timestamp'],
                      'type': p['event_type'],
                    })
                .toList() ??
            [],
        'metadata': metadata,
      };
    }).toList();
  }

  /// Fetch tokens by CIDs.
  /// Uses the actual indexer-v2 API schema.
  Future<List<Map<String, dynamic>>> fetchTokensByCIDs({
    required List<String> cids,
  }) async {
    const query = r'''
      query GetTokensByCIDs($cids: [String!]!) {
        tokens(
          token_cids: $cids
        ) {
          items {
            id
            token_cid
            chain
            contract_address
            token_number
            current_owner
            updated_at
            metadata {
              name
              description
              image_url
              animation_url
              mime_type
              artists {
                name
                did
              }
            }
            owners {
              items {
                owner_address
                quantity
              }
            }
            provenance_events {
              items {
                event_type
                from_address
                to_address
                tx_hash
                timestamp
                chain
              }
            }
            enrichment_source {
              name
              description
              image_url
              animation_url
              mime_type
              artists {
                name
                did
              }
            }
            metadata_media_assets {
              source_url
              mime_type
              variant_urls
            }
            enrichment_source_media_assets {
              source_url
              mime_type
              variant_urls
            }
          }
          offset
          total
        }
      }
    ''';

    final result = await _client.query(
      QueryOptions(
        document: gql(query),
        variables: {
          'cids': cids,
        },
      ),
    );

    if (result.hasException) {
      throw Exception('GraphQL error: ${result.exception}');
    }

    final tokensResponse = result.data?['tokens'] as Map<String, dynamic>?;
    final tokens = (tokensResponse?['items'] as List?)
            ?.map((token) => token as Map<String, dynamic>)
            .toList() ??
        [];

    // Transform to match expected format
    return tokens.map((token) {
      final metadata = token['metadata'] as Map<String, dynamic>?;
      final enrichmentSource =
          token['enrichment_source'] as Map<String, dynamic>?;
      final metadataMediaAssets = token['metadata_media_assets'] as List?;
      final enrichmentSourceMediaAssets =
          token['enrichment_source_media_assets'] as List?;

      // Get thumbnail URL - enrichment source takes priority
      String? thumbnailUrl = enrichmentSource?['image_url'] as String? ??
          metadata?['image_url'] as String?;

      // Try to get variant URLs for 'xs' size
      if (thumbnailUrl != null && thumbnailUrl.isNotEmpty) {
        // Check enrichment source media assets first
        final enrichmentAsset =
            enrichmentSourceMediaAssets?.cast<Map<String, dynamic>>().firstWhere(
                  (asset) => asset['source_url'] == thumbnailUrl,
                  orElse: () => <String, dynamic>{},
                );
        if (enrichmentAsset != null && enrichmentAsset.isNotEmpty) {
          final variantUrls = enrichmentAsset['variant_urls'] as Map?;
          if (variantUrls != null) {
            final xsUrl = variantUrls['xs'] ?? variantUrls.values.firstOrNull;
            if (xsUrl != null) thumbnailUrl = xsUrl as String;
          }
        } else {
          // Fallback to metadata media assets
          final metadataAsset =
              metadataMediaAssets?.cast<Map<String, dynamic>>().firstWhere(
                    (asset) => asset['source_url'] == thumbnailUrl,
                    orElse: () => <String, dynamic>{},
                  );
          if (metadataAsset != null && metadataAsset.isNotEmpty) {
            final variantUrls = metadataAsset['variant_urls'] as Map?;
            if (variantUrls != null) {
              final xsUrl =
                  variantUrls['xs'] ?? variantUrls.values.firstOrNull;
              if (xsUrl != null) thumbnailUrl = xsUrl as String;
            }
          }
        }
      }

      return {
        'id': token['token_cid'] ?? token['id'],
        'contractAddress': token['contract_address'],
        'tokenId': token['token_number']?.toString(),
        'blockchain': token['chain'],
        'title': enrichmentSource?['name'] ?? metadata?['name'],
        'description':
            enrichmentSource?['description'] ?? metadata?['description'],
        'thumbnailUrl': thumbnailUrl,
        'previewUrl': enrichmentSource?['animation_url'] ??
            metadata?['animation_url'],
        'owners': ((token['owners'] as Map?)?['items'] as List?)
                ?.map((o) => {
                      'address': (o as Map)['owner_address'],
                      'blockchain': o['blockchain'],
                    })
                .toList() ??
            [],
        'provenance': ((token['provenance_events'] as Map?)?['items'] as List?)
                ?.map((p) => {
                      'txHash': (p as Map)['tx_hash'],
                      'fromAddress': p['from_address'],
                      'toAddress': p['to_address'],
                      'timestamp': p['timestamp'],
                      'type': p['event_type'],
                    })
                .toList() ??
            [],
        'metadata': metadata,
      };
    }).toList();
  }

  /// Fetch changes from the indexer (for reindexing).
  /// Returns workflow IDs for tracking.
  Future<List<String>> indexAddresses({
    required List<String> addresses,
  }) async {
    const mutation = r'''
      mutation IndexAddresses($addresses: [String!]!) {
        indexAddresses(addresses: $addresses) {
          workflowIds
        }
      }
    ''';

    final result = await _client.mutate(
      MutationOptions(
        document: gql(mutation),
        variables: {'addresses': addresses},
      ),
    );

    if (result.hasException) {
      throw Exception('GraphQL error: ${result.exception}');
    }

    final workflowIds =
        (result.data?['indexAddresses']?['workflowIds'] as List?)
                ?.map((id) => id as String)
                .toList() ??
            [];

    return workflowIds;
  }

  /// Get indexing status for workflow IDs.
  Future<Map<String, String>> getIndexingStatus({
    required List<String> workflowIds,
  }) async {
    const query = r'''
      query GetIndexingStatus($workflowIds: [String!]!) {
        indexingStatus(workflowIds: $workflowIds) {
          workflowId
          status
        }
      }
    ''';

    final result = await _client.query(
      QueryOptions(
        document: gql(query),
        variables: {'workflowIds': workflowIds},
      ),
    );

    if (result.hasException) {
      throw Exception('GraphQL error: ${result.exception}');
    }

    final statuses = (result.data?['indexingStatus'] as List?)
            ?.map(
              (item) => MapEntry(
                (item as Map<String, dynamic>)['workflowId'] as String,
                item['status'] as String,
              ),
            )
            .toList() ??
        [];

    return Map.fromEntries(statuses);
  }

  /// Dispose the client.
  void dispose() {
    // GraphQL client doesn't need explicit disposal
  }
}
