/// GraphQL queries for the indexer syncCollection API.
///
/// Fetches token events for an address with checkpoint-based pagination.
const String syncCollectionQuery = r'''
  query syncCollection(
    $address: String!
    $checkpoint_timestamp: Time
    $checkpoint_event_id: Uint64
    $limit: Uint8
  ) {
    syncCollection(
      address: $address
      checkpoint_timestamp: $checkpoint_timestamp
      checkpoint_event_id: $checkpoint_event_id
      limit: $limit
    ) {
      events {
        id
        token_id
        event_type
        owner_address
        occurred_at
        metadata
      }
      next_checkpoint {
        timestamp
        event_id
      }
      server_time
    }
  }
''';
