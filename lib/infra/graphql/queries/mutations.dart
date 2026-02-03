// GraphQL mutations for triggering indexing actions.

/// Triggers address indexing and returns per-address workflow IDs.
const String triggerAddressIndexingList = r'''
  mutation triggerAddressIndexing($addresses: [String!]!) {
    triggerAddressIndexing(addresses: $addresses) {
      jobs {
        address
        workflow_id
      }
    }
  }
''';

// End of file.
