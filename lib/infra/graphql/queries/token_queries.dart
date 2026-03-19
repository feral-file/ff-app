/// GraphQL queries for the indexer API.
///
/// Keep these strings stable and auditable (OSS-first posture).
///
/// Source of truth: legacy Feral File app repo (`lib/nft_collection/graphql/queries/*`).
const String getTokens = r'''
  query getTokens(
    $owners: [String!]
    $chains: [String!]
    $contract_addresses: [String!]
    $token_ids: [Uint64!]
    $token_cids: [String!]
    $token_numbers: [String!]
    $limit: Uint8 = 20
    $offset: Uint64 = 0
    $sort_by: TokenSortBy = created_at
    $sort_order: Order = asc
  ) {
    tokens(
      owners: $owners
      chains: $chains
      contract_addresses: $contract_addresses
      token_ids: $token_ids
      token_cids: $token_cids
      token_numbers: $token_numbers
      limit: $limit
      offset: $offset
      sort_by: $sort_by
      sort_order: $sort_order
    ) {
      items {
        id
        chain
        contract_address
        standard
        token_cid
        token_number
        current_owner
        updated_at
        display {
          name
          description
          image_url
          animation_url
          mime_type
          artists {
            name
            did
          }
          publisher {
            name
            url
          }
        }
        owner_provenances {
          items {
            owner_address
            last_timestamp
            last_tx_index
          }
        }
        media_assets {
          source_url
          mime_type
          variants(keys: [xs, s, m, l, xl, xxl, hls, dash, preview])
        }
      }
      offset
    }
  }
''';

const String getTokenByCidQuery = r'''
  query getToken(
    $cid: String!
    $owners_limit: Uint8 = 10
    $owners_offset: Uint64 = 0
    $provenance_events_limit: Uint8 = 10
    $provenance_events_offset: Uint64 = 0
    $provenance_events_order: Order = desc
  ) {
    token(
      cid: $cid
      owners_limit: $owners_limit
      owners_offset: $owners_offset
      provenance_events_limit: $provenance_events_limit
      provenance_events_offset: $provenance_events_offset
      provenance_events_order: $provenance_events_order
    ) {
      id
      chain
      contract_address
      standard
      token_cid
      token_number
      current_owner
      updated_at
      display {
        name
        description
        image_url
        animation_url
        mime_type
        artists {
          name
          did
        }
        publisher {
          name
          url
        }
      }
      owners {
        items {
          quantity
          owner_address
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
      media_assets {
        source_url
        mime_type
        variants(keys: [xs, s, m, l, xl, xxl, hls, dash, preview])
      }
    }
  }
''';

const String getTokenWithOwnersAndProvenanceQuery = r'''
  query getToken(
    $cid: String!
    $owners_limit: Uint8 = 255
    $owners_offset: Uint64 = 0
    $provenance_events_limit: Uint8 = 255
    $provenance_events_offset: Uint64 = 0
    $provenance_events_order: Order = desc
  ) {
    token(
      cid: $cid
      provenance_events_order: $provenance_events_order
      provenance_events_limit: $provenance_events_limit
      provenance_events_offset: $provenance_events_offset
      owners_offset: $owners_offset
      owners_limit: $owners_limit
    ) {
      id
      token_cid
      owners {
        items {
          quantity
          owner_address
        }
        total
        offset
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
        total
        offset
      }
    }
  }
''';

// End of file.
