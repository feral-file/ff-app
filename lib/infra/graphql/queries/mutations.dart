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

// End of file.
