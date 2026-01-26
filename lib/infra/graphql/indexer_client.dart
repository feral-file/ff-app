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
        $owners: [String!]!
        $limit: Int
        $offset: Int
        $expands: [String!]
      ) {
        tokens(
          owners: $owners
          limit: $limit
          offset: $offset
          expands: $expands
        ) {
          id
          token_cid
          chain
          contract_address
          token_number
          metadata
          owners {
            address
            blockchain
          }
          provenance_events {
            tx_hash
            from_address
            to_address
            timestamp
            type
          }
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
          'expands': const ['owners', 'provenance_events'],
        },
      ),
    );

    if (result.hasException) {
      throw Exception('GraphQL error: ${result.exception}');
    }

    final tokens = (result.data?['tokens'] as List?)
            ?.map((token) => token as Map<String, dynamic>)
            .toList() ??
        [];

    // Transform to match expected format
    return tokens.map((token) {
      final metadata = token['metadata'] as Map<String, dynamic>?;
      return {
        'id': token['token_cid'] ?? token['id'],
        'contractAddress': token['contract_address'],
        'tokenId': token['token_number']?.toString(),
        'blockchain': token['chain'],
        'title': metadata?['name'] ?? metadata?['title'],
        'description': metadata?['description'],
        'thumbnailUrl': metadata?['thumbnail_uri'] ?? 
                       metadata?['image'],
        'previewUrl': metadata?['animation_url'] ?? 
                     metadata?['image'],
        'owners': (token['owners'] as List?)
                ?.map((o) => {
                      'address': (o as Map)['address'],
                      'blockchain': o['blockchain'],
                    })
                .toList() ??
            [],
        'provenance': (token['provenance_events'] as List?)
                ?.map((p) => {
                      'txHash': (p as Map)['tx_hash'],
                      'fromAddress': p['from_address'],
                      'toAddress': p['to_address'],
                      'timestamp': p['timestamp'],
                      'type': p['type'],
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
      query GetTokensByCIDs($cids: [String!]!, $expands: [String!]) {
        tokens(
          token_cids: $cids
          expands: $expands
        ) {
          id
          token_cid
          chain
          contract_address
          token_number
          metadata
          owners {
            address
            blockchain
          }
          provenance_events {
            tx_hash
            from_address
            to_address
            timestamp
            type
          }
        }
      }
    ''';

    final result = await _client.query(
      QueryOptions(
        document: gql(query),
        variables: {
          'cids': cids,
          'expands': const ['owners', 'provenance_events'],
        },
      ),
    );

    if (result.hasException) {
      throw Exception('GraphQL error: ${result.exception}');
    }

    final tokens = (result.data?['tokens'] as List?)
            ?.map((token) => token as Map<String, dynamic>)
            .toList() ??
        [];

    // Transform to match expected format
    return tokens.map((token) {
      final metadata = token['metadata'] as Map<String, dynamic>?;
      return {
        'id': token['token_cid'] ?? token['id'],
        'contractAddress': token['contract_address'],
        'tokenId': token['token_number']?.toString(),
        'blockchain': token['chain'],
        'title': metadata?['name'] ?? metadata?['title'],
        'description': metadata?['description'],
        'thumbnailUrl': metadata?['thumbnail_uri'] ?? 
                       metadata?['image'],
        'previewUrl': metadata?['animation_url'] ?? 
                     metadata?['image'],
        'owners': (token['owners'] as List?)
                ?.map((o) => {
                      'address': (o as Map)['address'],
                      'blockchain': o['blockchain'],
                    })
                .toList() ??
            [],
        'provenance': (token['provenance_events'] as List?)
                ?.map((p) => {
                      'txHash': (p as Map)['tx_hash'],
                      'fromAddress': p['from_address'],
                      'toAddress': p['to_address'],
                      'timestamp': p['timestamp'],
                      'type': p['type'],
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
