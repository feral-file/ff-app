/// GraphQL operations for the legacy index-addresses indexing workflow.
///
/// These map to the existing indexer-v2 API schema used by the app today.
const String indexAddressesMutation = r'''
  mutation IndexAddresses($addresses: [String!]!) {
    indexAddresses(addresses: $addresses) {
      workflowIds
    }
  }
''';

const String indexingStatusQuery = r'''
  query GetIndexingStatus($workflowIds: [String!]!) {
    indexingStatus(workflowIds: $workflowIds) {
      workflowId
      status
    }
  }
''';

// End of file.

