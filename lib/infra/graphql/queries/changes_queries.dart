/// GraphQL queries for the indexer changes API (change journal).
///
/// Keep these strings stable and auditable (OSS-first posture).
///
/// Fetches a paginated change journal for token/address filters.
const String getChangesQuery = r'''
  query getChanges(
    $token_cids: [String!]
    $addresses: [String!]
    $limit: Uint8
    $anchor: Uint64
  ) {
    changes(
      token_cids: $token_cids
      addresses: $addresses
      limit: $limit
      anchor: $anchor
    ) {
      items {
        id
        subject_type
        subject_id
        changed_at
        meta
        created_at
        updated_at
      }
      offset
      total
      next_anchor
    }
  }
''';

// End of file.
