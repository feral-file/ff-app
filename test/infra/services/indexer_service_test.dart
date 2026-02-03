import 'package:app/domain/models/indexer/changes/change.dart';
import 'package:app/infra/graphql/indexer_client.dart';
import 'package:app/infra/services/indexer_service.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeIndexerClient extends IndexerClient {
  FakeIndexerClient() : super(endpoint: 'http://localhost');

  Map<String, dynamic>? changesPayload;

  @override
  Future<Map<String, dynamic>?> query({
    required String doc,
    Map<String, dynamic> vars = const {},
    String? subKey,
  }) async {
    if (subKey == 'changes') {
      return changesPayload;
    }
    return null;
  }
}

void main() {
  test('IndexerService.getChanges returns parsed ChangeList', () async {
    final client = FakeIndexerClient()
      ..changesPayload = <String, dynamic>{
        'items': [
          {
            'id': 1,
            'subject_type': 'token',
            'subject_id': 't1',
            'changed_at': '2025-01-01T00:00:00Z',
            'meta': {
              'chain': 'eip155:1',
              'standard': 'erc721',
              'contract': '0xabc',
              'token_number': '1',
              'token_id': 123,
              'from': null,
              'to': '0x111',
            },
            'created_at': '2025-01-01T00:00:00Z',
            'updated_at': '2025-01-01T00:00:00Z',
          }
        ],
        'offset': 0,
        'total': 1,
        'next_anchor': '42',
      };

    final service = IndexerService(
      client: client,
    );

    const req = QueryChangesRequest(addresses: ['0x111'], limit: 10);
    final result = await service.getChanges(req);

    expect(result.items, hasLength(1));
    expect(result.items.first.isMint(), isTrue);
    expect(result.nextAnchor, equals(42));
  });
}
