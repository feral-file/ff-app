import 'package:app/domain/models/indexer/workflow.dart';
import 'package:app/infra/config/app_state_service.dart';
import 'package:app/widgets/playlist/indexing_status_text.dart';
import 'package:flutter_test/flutter_test.dart';

AddressIndexingProcessStatus _status(AddressIndexingProcessState state) {
  switch (state) {
    case AddressIndexingProcessState.idle:
      return AddressIndexingProcessStatus.idle();
    case AddressIndexingProcessState.indexingTriggered:
      return AddressIndexingProcessStatus.indexingTriggered(
        workflowId: 'wf-test',
      );
    case AddressIndexingProcessState.waitingForIndexStatus:
      return AddressIndexingProcessStatus.waitingForIndexStatus();
    case AddressIndexingProcessState.syncingTokens:
      return AddressIndexingProcessStatus.syncingTokens();
    case AddressIndexingProcessState.paused:
      return AddressIndexingProcessStatus.paused();
    case AddressIndexingProcessState.stopped:
      return AddressIndexingProcessStatus.stopped();
    case AddressIndexingProcessState.completed:
      return AddressIndexingProcessStatus.completed();
    case AddressIndexingProcessState.failed:
      return AddressIndexingProcessStatus.failed();
  }
}

void main() {
  group('deriveIndexingStatusText', () {
    test('idle + no readyCount: shows Syncing', () {
      final result = deriveIndexingStatusText(
        processStatus: _status(AddressIndexingProcessState.idle),
        readyCount: null,
      );
      expect(result.text, 'Syncing');
      expect(result.showRetry, isFalse);
    });

    test('idle: shows Syncing with ready count', () {
      final result = deriveIndexingStatusText(
        processStatus: _status(AddressIndexingProcessState.idle),
        readyCount: 3,
      );
      expect(result.text, 'Syncing • 3 ready');
      expect(result.showRetry, isFalse);
    });

    test('waitingForIndexStatus + job null: Syncing with ready', () {
      final result = deriveIndexingStatusText(
        processStatus: _status(
          AddressIndexingProcessState.waitingForIndexStatus,
        ),
        readyCount: 2,
      );
      expect(result.text, 'Syncing • 2 ready');
      expect(result.showRetry, isFalse);
    });

    test('syncingTokens + job running: includes ready and found', () {
      const job = AddressIndexingJobResponse(
        workflowId: 'wf_1',
        address: '0xabc',
        status: IndexingJobStatus.running,
        totalTokensIndexed: 12,
        totalTokensViewable: 0,
      );
      final result = deriveIndexingStatusText(
        processStatus: _status(AddressIndexingProcessState.syncingTokens),
        job: job,
        readyCount: 5,
      );
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
      final result = deriveIndexingStatusText(
        processStatus: _status(AddressIndexingProcessState.paused),
        job: job,
        readyCount: 2,
      );
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
          deriveIndexingStatusText(
            processStatus: _status(AddressIndexingProcessState.completed),
            job: job,
            readyCount: 7,
          ).text,
          'Up to date • 7 works',
        );
        expect(
          deriveIndexingStatusText(
            processStatus: _status(AddressIndexingProcessState.completed),
            job: job,
            readyCount: 1,
          ).text,
          'Up to date • 1 work',
        );
        expect(
          deriveIndexingStatusText(
            processStatus: _status(AddressIndexingProcessState.completed),
            job: job,
            readyCount: null,
          ).text,
          'Up to date • 9 works',
        );
      },
    );

    test('failed: shows sync issue and retry', () {
      final result = deriveIndexingStatusText(
        processStatus: _status(AddressIndexingProcessState.failed),
        readyCount: 1,
      );
      expect(result.text, 'Sync issue');
      expect(result.showRetry, isTrue);
    });

    test('stopped: returns null', () {
      final result = deriveIndexingStatusText(
        processStatus: _status(AddressIndexingProcessState.stopped),
        readyCount: 1,
      );
      expect(result.text, isNull);
      expect(result.showRetry, isFalse);
    });

    test('processStatus null defaults to idle: shows Syncing with ready', () {
      final result = deriveIndexingStatusText(
        readyCount: 4,
      );
      expect(result.text, 'Syncing • 4 ready');
      expect(result.showRetry, isFalse);
    });

    test(
      'syncingTokens + job completed: shows Syncing with indexed found count',
      () {
        const job = AddressIndexingJobResponse(
          workflowId: 'wf_1',
          address: '0xabc',
          status: IndexingJobStatus.completed,
          totalTokensIndexed: 10,
          totalTokensViewable: 9,
        );
        final result = deriveIndexingStatusText(
          processStatus: _status(AddressIndexingProcessState.syncingTokens),
          job: job,
          readyCount: 5,
        );
        expect(result.text, 'Syncing • 5 ready • 10 found');
        expect(result.showRetry, isFalse);
      },
    );
  });
}
