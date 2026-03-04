import 'package:app/domain/models/indexer/workflow.dart';

/// Status text and retry hint for address-based playlist indexing.
class IndexingStatusText {
  const IndexingStatusText({
    required this.text,
    required this.showRetry,
  });

  final String? text;
  final bool showRetry;
}

/// Derives a status line for address-based playlist indexing.
///
/// Mirrors the old repo copy patterns:
/// - running: Syncing • {ready} ready • {found} found
/// - paused: Paused • {ready} ready • resumes later
/// - completed: Up to date • {works} works
/// - failed/canceled: Sync issue (+ retry)
IndexingStatusText deriveIndexingStatusText({
  required AddressIndexingJobResponse? job,
  required int? readyCount,
}) {
  if (job == null) {
    return const IndexingStatusText(text: null, showRetry: false);
  }

  switch (job.status) {
    case IndexingJobStatus.running:
      return IndexingStatusText(
        text: _joinParts(<String>[
          'Syncing',
          if (readyCount != null) '$readyCount ready',
          if (job.totalTokensIndexed != null) '${job.totalTokensIndexed} found',
        ]),
        showRetry: false,
      );

    case IndexingJobStatus.paused:
      return IndexingStatusText(
        text: _joinParts(<String>[
          'Paused',
          if (readyCount != null) '$readyCount ready',
          'resumes later',
        ]),
        showRetry: false,
      );

    case IndexingJobStatus.completed:
      final worksCount = readyCount ?? job.totalTokensViewable;
      return IndexingStatusText(
        text: _joinParts(<String>[
          'Up to date',
          if (worksCount != null) '$worksCount works',
        ]),
        showRetry: false,
      );

    case IndexingJobStatus.failed:
    case IndexingJobStatus.canceled:
      return const IndexingStatusText(text: 'Sync issue', showRetry: true);
  }
}

String _joinParts(List<String> parts) {
  final trimmed = parts
      .map((p) => p.trim())
      .where((p) => p.isNotEmpty)
      .toList();
  return trimmed.join(' • ');
}
