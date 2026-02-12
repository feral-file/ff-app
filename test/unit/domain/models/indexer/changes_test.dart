import 'package:app/domain/models/indexer/changes/change.dart';
import 'package:app/domain/models/indexer/changes/change_meta.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Change parses provenance meta and detects mint/burn/transfer', () {
    final mint = Change(
      id: 1,
      subjectType: SubjectType.token,
      subjectId: 'token:1',
      changedAt: DateTime.parse('2025-01-01T00:00:00Z'),
      createdAt: DateTime.parse('2025-01-01T00:00:00Z'),
      updatedAt: DateTime.parse('2025-01-01T00:00:00Z'),
      meta: {
        'chain': 'eip155:1',
        'standard': 'erc721',
        'contract': '0xabc',
        'token_number': '1',
        'token_id': 123,
        'from': null,
        'to': '0x111',
      },
    );

    expect(mint.metaParsed, isA<ProvenanceChangeMeta>());
    expect(mint.isMint(), isTrue);
    expect(mint.isBurn(), isFalse);
    expect(mint.isTransfer(), isFalse);
    expect(mint.tokenCid, equals('eip155:1:erc721:0xabc:1'));
  });

  test('QueryChangesRequest serializes only non-empty filters', () {
    const req = QueryChangesRequest(
      addresses: ['0xAAA'],
      limit: 10,
      anchor: 42,
    );

    final json = req.toJson();
    expect(json['addresses'], equals(['0xAAA']));
    expect(json.containsKey('token_cids'), isFalse);
    expect(json['limit'], equals(10));
    expect(json['anchor'], equals(42));
  });
}

// End of file.
