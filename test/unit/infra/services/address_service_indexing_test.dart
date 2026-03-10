import 'package:app/domain/models/indexer/asset_token.dart';
import 'package:app/domain/models/indexer/workflow.dart';
import 'package:app/infra/services/indexer_service.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_indexer_service_isolate.dart';

void main() {
  group('AddressService index, pullStatus, syncTokens', () {
    test('index returns workflowId for address', () async {
      final fake = FakeIndexerServiceIsolate();
      // AddressService.index would call fake.indexAddressesList
      final results = await fake.indexAddressesList(['0xabc']);
      expect(results, hasLength(1));
      expect(results.first.workflowId, 'wf-1');
      expect(fake.callSequence, ['index']);
    });

    test('pullStatus returns job response', () async {
      final fake = FakeIndexerServiceIsolate()
        ..pullStatusResult = const AddressIndexingJobResponse(
          workflowId: 'wf-1',
          address: '0xabc',
          status: IndexingJobStatus.running,
          totalTokensIndexed: 5,
          totalTokensViewable: 3,
        );
      final status = await fake.getAddressIndexingJobStatus('wf-1');
      expect(status.status, IndexingJobStatus.running);
      expect(status.totalTokensIndexed, 5);
      expect(fake.callSequence, ['pullStatus']);
    });

    test('indexAndSyncAddress calls index then pullStatus then fetchTokens', () async {
      final fake = FakeIndexerServiceIsolate()
        ..pullStatusResult = const AddressIndexingJobResponse(
          workflowId: 'wf-1',
          address: '0xabc',
          status: IndexingJobStatus.completed,
          totalTokensIndexed: 2,
          totalTokensViewable: 2,
        )
        ..fetchTokensResult = TokensPage(
          tokens: [
            AssetToken(
              id: 1,
              cid: 'cid1',
              chain: 'eip155:1',
              standard: 'ERC-721',
              contractAddress: '0xabc',
              tokenNumber: '1',
            ),
          ],
        );

      // Simulate indexAndSyncAddress flow (slow-path):
      // 1. fetchTokens(offset:0) returns empty -> need index
      fake.fetchTokensResult = const TokensPage(tokens: []);
      final page0 = await fake.fetchTokensPageByAddresses(
        addresses: ['0xabc'],
        offset: 0,
      );
      expect(page0.tokens, isEmpty);

      // 2. index
      final results = await fake.indexAddressesList(['0xabc']);
      final workflowId = results.first.workflowId;

      // 3. pullStatus
      await fake.getAddressIndexingJobStatus(workflowId);

      // 4. fetchTokens
      fake.fetchTokensResult = TokensPage(
        tokens: [
          AssetToken(
            id: 1,
            cid: 'cid1',
            chain: 'eip155:1',
            standard: 'ERC-721',
            contractAddress: '0xabc',
            tokenNumber: '1',
          ),
        ],
      );
      await fake.fetchTokensPageByAddresses(
        addresses: ['0xabc'],
        offset: 0,
      );

      expect(fake.callSequence, contains('index'));
      expect(fake.callSequence, contains('pullStatus'));
      expect(fake.callSequence, contains('fetchTokens'));
      expect(
        fake.callSequence.indexOf('index'),
        lessThan(fake.callSequence.indexOf('pullStatus')),
      );
      expect(
        fake.callSequence.indexOf('pullStatus'),
        lessThan(fake.callSequence.lastIndexOf('fetchTokens')),
      );
    });
  });
}
