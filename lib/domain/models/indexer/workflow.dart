// ignore_for_file: public_member_api_docs, sort_constructors_first // Reason: protocol-shaped indexer models; keep stable + auditable.

/// Status values for address indexing jobs.
enum IndexingJobStatus {
  running,
  paused,
  failed,
  completed,
  canceled;

  String toJson() {
    switch (this) {
      case IndexingJobStatus.running:
        return 'running';
      case IndexingJobStatus.paused:
        return 'paused';
      case IndexingJobStatus.failed:
        return 'failed';
      case IndexingJobStatus.completed:
        return 'completed';
      case IndexingJobStatus.canceled:
        return 'canceled';
    }
  }

  static IndexingJobStatus fromJson(String? value) {
    if (value == null) return IndexingJobStatus.running;
    switch (value.toLowerCase()) {
      case 'running':
        return IndexingJobStatus.running;
      case 'paused':
        return IndexingJobStatus.paused;
      case 'failed':
        return IndexingJobStatus.failed;
      case 'completed':
        return IndexingJobStatus.completed;
      case 'canceled':
        return IndexingJobStatus.canceled;
      default:
        return IndexingJobStatus.running;
    }
  }

  /// True when the job has reached a terminal state.
  bool get isDone =>
      this == IndexingJobStatus.completed ||
      this == IndexingJobStatus.failed ||
      this == IndexingJobStatus.canceled;

  /// True when the job completed successfully.
  bool get isSuccess => this == IndexingJobStatus.completed;
}

/// Result from batch address indexing operation.
class AddressIndexingResult {
  /// Creates an AddressIndexingResult.
  const AddressIndexingResult({
    required this.address,
    required this.workflowId,
  });

  final String address;
  final String workflowId;

  factory AddressIndexingResult.fromJson(Map<String, dynamic> json) =>
      AddressIndexingResult(
        address: json['address'] as String? ?? '',
        workflowId: json['workflow_id'] as String? ?? '',
      );

  Map<String, dynamic> toJson() => {
        'address': address,
        'workflow_id': workflowId,
      };
}

/// Address indexing job status response.
class AddressIndexingJobResponse {
  /// Creates an AddressIndexingJobResponse.
  const AddressIndexingJobResponse({
    required this.workflowId,
    required this.address,
    required this.status,
    required this.totalTokensIndexed,
    required this.totalTokensViewable,
  });

  final String workflowId;
  final String address;
  final IndexingJobStatus status;
  final int? totalTokensIndexed;
  final int? totalTokensViewable;

  factory AddressIndexingJobResponse.fromJson(Map<String, dynamic> json) =>
      AddressIndexingJobResponse(
        workflowId: json['workflow_id'] as String? ?? '',
        address: json['address'] as String? ?? '',
        status: IndexingJobStatus.fromJson(json['status'] as String?),
        totalTokensIndexed: json['total_tokens_indexed'] as int?,
        totalTokensViewable: json['total_tokens_viewable'] as int?,
      );

  Map<String, dynamic> toJson() => {
        'workflow_id': workflowId,
        'address': address,
        'status': status.toJson(),
        'total_tokens_indexed': totalTokensIndexed,
        'total_tokens_viewable': totalTokensViewable,
      };
}

// End of file.
