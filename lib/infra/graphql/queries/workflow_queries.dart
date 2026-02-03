/// GraphQL queries for Temporal workflow status and address indexing jobs.
///
/// These map to the indexer API schema.

/// Fetch address indexing job status by workflow_id.
const String addressIndexingJobStatusQuery = r'''
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

// End of file.
