import 'package:graphql/client.dart';

import 'package:app/domain/models/indexer/asset_token.dart';

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
  Future<List<AssetToken>> fetchTokensByAddresses({
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
            standard
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

    return tokens.map(AssetToken.fromGraphQL).toList();
  }

  /// Fetch tokens by CIDs.
  /// Uses the actual indexer-v2 API schema.
  Future<List<AssetToken>> fetchTokensByCIDs({
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
            standard
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

    return tokens.map(AssetToken.fromGraphQL).toList();
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
