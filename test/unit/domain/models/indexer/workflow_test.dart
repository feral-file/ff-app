import 'package:app/domain/models/indexer/workflow.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('IndexingJobStatus', () {
    test('isDone/isSuccess', () {
      expect(IndexingJobStatus.completed.isDone, isTrue);
      expect(IndexingJobStatus.completed.isSuccess, isTrue);
      expect(IndexingJobStatus.running.isDone, isFalse);
    });
  });

  group('TriggerIndexingResult', () {
    test('fromJson parses workflow_id and run_id', () {
      final result = TriggerIndexingResult.fromJson(const {
        'workflow_id': 'wf-123',
        'run_id': 'run-456',
      });
      expect(result.workflowId, 'wf-123');
      expect(result.runId, 'run-456');
    });

    test('toJson serializes correctly', () {
      const result = TriggerIndexingResult(
        workflowId: 'wf-a',
        runId: 'run-b',
      );
      expect(result.toJson(), {
        'workflow_id': 'wf-a',
        'run_id': 'run-b',
      });
    });
  });

  group('WorkflowStatusResponse', () {
    test('fromJson parses status', () {
      final resp = WorkflowStatusResponse.fromJson(const {
        'workflow_id': 'wf-1',
        'run_id': 'run-1',
        'status': 'COMPLETED',
      });
      expect(resp.status, 'COMPLETED');
      expect(resp.isTerminal, isTrue);
      expect(resp.isSuccess, isTrue);
    });

    test('isTerminal true for FAILED', () {
      final resp = WorkflowStatusResponse.fromJson(const {
        'workflow_id': 'wf-1',
        'run_id': 'run-1',
        'status': 'FAILED',
      });
      expect(resp.isTerminal, isTrue);
      expect(resp.isSuccess, isFalse);
    });

    test('isTerminal false for RUNNING', () {
      final resp = WorkflowStatusResponse.fromJson(const {
        'workflow_id': 'wf-1',
        'run_id': 'run-1',
        'status': 'RUNNING',
      });
      expect(resp.isTerminal, isFalse);
    });
  });
}

// End of file.
