import 'package:app/app/providers/address_indexing_job_provider.dart';
import 'package:app/domain/models/indexer/workflow.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('addressIndexingJobProvider', () {
    test('stores and retrieves jobs by lowercased address', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      const response = AddressIndexingJobResponse(
        workflowId: 'wf_1',
        address: '0xAbC',
        status: IndexingJobStatus.running,
        totalTokensIndexed: 1,
        totalTokensViewable: 2,
      );

      container.read(addressIndexingJobProvider.notifier).updateJob(response);

      final state = container.read(addressIndexingJobProvider);
      expect(state.getJob('0xabc')?.workflowId, 'wf_1');
      expect(state.getJob('0xABC')?.totalTokensIndexed, 1);
      expect(state.isIndexing('0xABC'), isTrue);
      expect(state.activeIndexingCount, 1);
    });

    test('clearJob removes stored job', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      const response = AddressIndexingJobResponse(
        workflowId: 'wf_1',
        address: '0xAbC',
        status: IndexingJobStatus.running,
        totalTokensIndexed: 1,
        totalTokensViewable: 2,
      );

      final notifier = container.read(addressIndexingJobProvider.notifier);
      notifier.updateJob(response);
      expect(
        container.read(addressIndexingJobProvider).getJob('0xabc'),
        isNotNull,
      );

      notifier.clearJob('0xABC');
      expect(
        container.read(addressIndexingJobProvider).getJob('0xabc'),
        isNull,
      );
    });

    test('indexingJobStatusProvider returns job for address', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      const response = AddressIndexingJobResponse(
        workflowId: 'wf_2',
        address: '0xDeF',
        status: IndexingJobStatus.completed,
        totalTokensIndexed: 10,
        totalTokensViewable: 9,
      );

      container.read(addressIndexingJobProvider.notifier).updateJob(response);

      final job = container.read(indexingJobStatusProvider('0xdef'));
      expect(job?.workflowId, 'wf_2');
      expect(job?.status, IndexingJobStatus.completed);
    });
  });
}
