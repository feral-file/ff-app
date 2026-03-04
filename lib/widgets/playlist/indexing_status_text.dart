import 'package:app/domain/models/indexer/workflow.dart';
import 'package:app/infra/config/app_state_service.dart';

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
/// Primary source: [processStatus] (AddressIndexingProcessState).
/// When [job] is available (during active polling), it supplements with
/// ready/found counts.
///
/// Patterns:
/// - indexingTriggered, waitingForIndexStatus, syncingTokens: Syncing • ...
///   (IndexingJobStatus.completed is just one step; process may still be syncing)
/// - paused: Paused • {ready} ready • resumes later
/// - completed: Up to date • {works} works (only when processStatus.state is completed)
/// - failed: Sync issue (+ retry)
/// - idle + readyCount: fallback for already-indexed addresses
IndexingStatusText deriveIndexingStatusText({
  required int? readyCount, AddressIndexingProcessStatus? processStatus,
  AddressIndexingJobResponse? job,
}) {
  final state = processStatus?.state ?? AddressIndexingProcessState.idle;

  switch (state) {
    case AddressIndexingProcessState.idle:
      return IndexingStatusText(
        text: _joinParts(<String>[
          'Syncing',
          if (readyCount != null) '$readyCount ready',
        ]),
        showRetry: false,
      );

    case AddressIndexingProcessState.completed:
      final worksCount = readyCount ?? job?.totalTokensViewable;
      return IndexingStatusText(
        text: _joinParts(<String>[
          'Up to date',
          if (worksCount != null) '$worksCount works',
        ]),
        showRetry: false,
      );

    case AddressIndexingProcessState.indexingTriggered:
    case AddressIndexingProcessState.waitingForIndexStatus:
    case AddressIndexingProcessState.syncingTokens:
      if (job != null) {
        switch (job.status) {
          case IndexingJobStatus.running:
            return IndexingStatusText(
              text: _joinParts(<String>[
                'Syncing',
                if (readyCount != null) '$readyCount ready',
                if (job.totalTokensIndexed != null)
                  '${job.totalTokensIndexed} found',
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
            return IndexingStatusText(
              text: _joinParts(<String>[
                'Syncing',
                if (readyCount != null) '$readyCount ready',
                if (job.totalTokensViewable != null)
                  '${job.totalTokensViewable} found',
              ]),
              showRetry: false,
            );
          case IndexingJobStatus.failed:
          case IndexingJobStatus.canceled:
            return const IndexingStatusText(text: 'Sync issue', showRetry: true);
        }
      }
      return IndexingStatusText(
        text: _joinParts(<String>[
          'Syncing',
          if (readyCount != null) '$readyCount ready',
        ]),
        showRetry: false,
      );

    case AddressIndexingProcessState.paused:
      return IndexingStatusText(
        text: _joinParts(<String>[
          'Paused',
          if (readyCount != null) '$readyCount ready',
          'resumes later',
        ]),
        showRetry: false,
      );

    case AddressIndexingProcessState.failed:
      return const IndexingStatusText(text: 'Sync issue', showRetry: true);

    case AddressIndexingProcessState.stopped:
      return const IndexingStatusText(text: null, showRetry: false);
  }
}

String _joinParts(List<String> parts) {
  final trimmed = parts
      .map((p) => p.trim())
      .where((p) => p.isNotEmpty)
      .toList();
  return trimmed.join(' • ');
}
