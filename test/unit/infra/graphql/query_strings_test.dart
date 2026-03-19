import 'package:app/infra/graphql/queries/changes_queries.dart';
import 'package:app/infra/graphql/queries/collection_queries.dart';
import 'package:app/infra/graphql/queries/identity_queries.dart';
import 'package:app/infra/graphql/queries/mutations.dart';
import 'package:app/infra/graphql/queries/token_queries.dart';
import 'package:app/infra/graphql/queries/workflow_queries.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('GraphQL query strings match the current auditable contract', () {
    const expectedGetTokens = r'''
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

    const expectedGetTokenByCidQuery = r'''
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

    const expectedGetTokenWithOwnersAndProvenanceQuery = r'''
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

    const expectedGetChangesQuery = r'''
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
        subject
        created_at
        updated_at
      }
      offset
      total
      next_anchor
    }
  }
''';

    const expectedAddressIndexingJobStatusQuery = r'''
  query indexingJob($workflow_id: String!) {
    indexingJob(workflow_id: $workflow_id) {
      workflow_id
      address
      status
      total_tokens_indexed
      total_tokens_viewable
    }
  }
''';

    const expectedTriggerOwnerIndexingList = r'''
  mutation triggerAddressIndexing($addresses: [String!]!) {
  triggerAddressIndexing(addresses: $addresses) {
    jobs {
      address
      workflow_id
    }
  }
}
''';

    const expectedIdentity = r'''
  query identity($account: String!) {
  identity(account: $account) {
    blockchain
    accountNumber
    name
  }
}
''';

    const expectedCollectionQuery = r'''
    query GetCollections($creators: [String!]! = [], $offset: Int64! = 0, $size: Int64! = 100) {
  collections(
    creators: $creators,
    offset: $offset,
    size: $size,
  ) {
    id
    description
    externalID
    imageURL
    items
    name
    creators
    published
    source
    createdAt
  }
}
''';

    expect(getTokens, expectedGetTokens);
    expect(getTokenByCidQuery, expectedGetTokenByCidQuery);
    expect(
      getTokenWithOwnersAndProvenanceQuery,
      expectedGetTokenWithOwnersAndProvenanceQuery,
    );

    expect(getChangesQuery, expectedGetChangesQuery);
    expect(
      addressIndexingJobStatusQuery,
      expectedAddressIndexingJobStatusQuery,
    );

    expect(triggerOwnerIndexingList, expectedTriggerOwnerIndexingList);

    expect(identity, expectedIdentity);
    expect(collectionQuery, expectedCollectionQuery);
  });
}

// End of file.
