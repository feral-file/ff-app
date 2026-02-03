/// GraphQL queries for fetching tokens from the indexer.
///
/// Keep these strings stable and auditable (OSS-first posture).
const String getTokensByAddressesQuery = r'''
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

const String getTokensByCidsQuery = r'''
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

// End of file.

