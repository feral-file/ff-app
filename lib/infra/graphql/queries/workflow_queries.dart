/// GraphQL queries for Temporal workflow status and address indexing jobs.
///
/// These map to the indexer API schema.
library;

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

/// Fetch workflow status by workflow_id and run_id.
/// Used to poll until metadata indexing reaches terminal state.
const String workflowStatusQuery = r'''
  query workflowStatus($workflow_id: String!, $run_id: String!) {
    workflowStatus(workflow_id: $workflow_id, run_id: $run_id) {
      workflow_id
      run_id
      status
    }
  }
''';

// End of file.
