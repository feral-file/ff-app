/// GraphQL mutations for triggering indexer workflows.
///
/// Keep these strings stable and auditable (OSS-first posture).
///
/// Source of truth: legacy Feral File app repo (`lib/nft_collection/graphql/queries/*`).
library;

/// Triggers address indexing and returns per-address workflow IDs.
///
/// Note: This is intentionally formatted to match the legacy repo.
const String triggerOwnerIndexingList = r'''
  mutation triggerAddressIndexing($addresses: [String!]!) {
  triggerAddressIndexing(addresses: $addresses) {
    jobs {
      address
      workflow_id
    }
  }
}
''';

/// Back-compat alias (will be removed when callers are migrated).
const String triggerAddressIndexingList = triggerOwnerIndexingList;

/// Triggers metadata refresh for tokens by CIDs.
/// Returns workflow_id and run_id for polling workflow status.
const String triggerMetadataIndexingMutation = r'''
  mutation triggerMetadataIndexing($token_cids: [String!]) {
    triggerMetadataIndexing(token_cids: $token_cids) {
      workflow_id
      run_id
    }
  }
''';

// End of file.
