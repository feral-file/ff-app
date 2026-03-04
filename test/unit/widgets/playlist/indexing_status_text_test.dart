import 'package:app/domain/models/indexer/workflow.dart';
import 'package:app/widgets/playlist/indexing_status_text.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('deriveIndexingStatusText', () {
    test('returns null when job is null', () {
      final result = deriveIndexingStatusText(job: null, readyCount: 3);
      expect(result.text, isNull);
      expect(result.showRetry, isFalse);
    });

    test('running: includes ready and found when available', () {
      const job = AddressIndexingJobResponse(
        workflowId: 'wf_1',
        address: '0xabc',
        status: IndexingJobStatus.running,
        totalTokensIndexed: 12,
        totalTokensViewable: 0,
      );
      final result = deriveIndexingStatusText(job: job, readyCount: 5);
      expect(result.text, 'Syncing • 5 ready • 12 found');
      expect(result.showRetry, isFalse);
    });

    test('paused: includes ready and resumes later', () {
      const job = AddressIndexingJobResponse(
        workflowId: 'wf_1',
        address: '0xabc',
        status: IndexingJobStatus.paused,
        totalTokensIndexed: null,
        totalTokensViewable: null,
      );
      final result = deriveIndexingStatusText(job: job, readyCount: 2);
      expect(result.text, 'Paused • 2 ready • resumes later');
      expect(result.showRetry, isFalse);
    });

    test(
      'completed: prefers readyCount, falls back to totalTokensViewable',
      () {
        const job = AddressIndexingJobResponse(
          workflowId: 'wf_1',
          address: '0xabc',
          status: IndexingJobStatus.completed,
          totalTokensIndexed: 10,
          totalTokensViewable: 9,
        );
        expect(
          deriveIndexingStatusText(job: job, readyCount: 7).text,
          'Up to date • 7 works',
        );
        expect(
          deriveIndexingStatusText(job: job, readyCount: null).text,
          'Up to date • 9 works',
        );
      },
    );

    test('failed/canceled: shows sync issue and retry', () {
      const failed = AddressIndexingJobResponse(
        workflowId: 'wf_1',
        address: '0xabc',
        status: IndexingJobStatus.failed,
        totalTokensIndexed: null,
        totalTokensViewable: null,
      );
      final failedResult = deriveIndexingStatusText(job: failed, readyCount: 1);
      expect(failedResult.text, 'Sync issue');
      expect(failedResult.showRetry, isTrue);

      const canceled = AddressIndexingJobResponse(
        workflowId: 'wf_1',
        address: '0xabc',
        status: IndexingJobStatus.canceled,
        totalTokensIndexed: null,
        totalTokensViewable: null,
      );
      final canceledResult = deriveIndexingStatusText(
        job: canceled,
        readyCount: 1,
      );
      expect(canceledResult.text, 'Sync issue');
      expect(canceledResult.showRetry, isTrue);
    });
  });
}
