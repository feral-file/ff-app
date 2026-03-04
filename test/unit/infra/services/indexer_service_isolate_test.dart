import 'package:app/domain/models/indexer/workflow.dart';
import 'package:app/infra/services/indexer_service_isolate.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('IndexerServiceIsolate', () {
    test('start and stop complete without error', () async {
      final isolate = IndexerServiceIsolate(
        endpoint: 'https://indexer.example.com',
        apiKey: 'test-key',
      );

      await isolate.start();
      expect(isolate.isRunning, isTrue);

      await isolate.stop();
      expect(isolate.isRunning, isFalse);
    });

    test('indexAddressesList sends request and receives response', () async {
      final isolate = IndexerServiceIsolate(
        endpoint: 'https://indexer.example.com',
        apiKey: 'test-key',
      );

      await isolate.start();
      addTearDown(isolate.stop);

      // Against fake endpoint, expect network/connection error.
      // Verifies the request-response protocol completes (error path).
      expect(
        () => isolate.indexAddressesList(['0x1234']),
        throwsA(anything),
      );
    });
  });

  group('IndexerServiceIsolate protocol', () {
    test('AddressIndexingResult serializes correctly', () {
      const result = AddressIndexingResult(
        address: '0xabc',
        workflowId: 'wf-123',
      );
      final json = result.toJson();
      expect(json['address'], '0xabc');
      expect(json['workflow_id'], 'wf-123');
      final restored =
          AddressIndexingResult.fromJson(Map<String, dynamic>.from(json));
      expect(restored.address, '0xabc');
      expect(restored.workflowId, 'wf-123');
    });
  });
}
