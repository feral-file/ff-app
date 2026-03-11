import 'package:app/domain/models/indexer/changes/change.dart';
import 'package:app/infra/graphql/indexer_client.dart';
import 'package:app/infra/graphql/queries/token_queries.dart';
import 'package:app/infra/services/indexer_service.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeIndexerClient extends IndexerClient {
  FakeIndexerClient() : super(endpoint: 'http://localhost');

  Map<String, dynamic>? changesPayload;
  Map<String, dynamic>? tokensPayload;
  Map<String, dynamic>? workflowStatusPayload;
  Map<String, dynamic>? triggerMetadataIndexingPayload;
  Map<String, dynamic>? Function(Map<String, dynamic> vars)?
      tokensPayloadBuilder;

  String? lastDoc;
  Map<String, dynamic> lastVars = const {};
  String? lastSubKey;

  final List<Map<String, dynamic>> tokenQueryVars = <Map<String, dynamic>>[];

  @override
  Future<Map<String, dynamic>?> mutate({
    required String doc,
    Map<String, dynamic> vars = const {},
    String? subKey,
  }) async {
    lastDoc = doc;
    lastVars = vars;
    lastSubKey = subKey;
    if (subKey == 'triggerMetadataIndexing') {
      return triggerMetadataIndexingPayload;
    }
    return null;
  }

  @override
  Future<Map<String, dynamic>?> query({
    required String doc,
    Map<String, dynamic> vars = const {},
    String? subKey,
  }) async {
    lastDoc = doc;
    lastVars = vars;
    lastSubKey = subKey;

    if (subKey == 'changes') {
      return changesPayload;
    }
    if (subKey == 'tokens') {
      tokenQueryVars.add(vars);
      final builder = tokensPayloadBuilder;
      if (builder != null) return builder(vars);
      return tokensPayload;
    }
    if (subKey == 'workflowStatus') {
      return workflowStatusPayload;
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
          },
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

  test(
    'IndexerService.fetchTokensByAddresses uses getTokens vars '
    'mapping contract',
    () async {
      final client = FakeIndexerClient()
        ..tokensPayload = <String, dynamic>{
          'items': [
            {
              'id': '1',
              'chain': 'eip155:1',
              'contract_address': '0xabc',
              'standard': 'erc721',
              'token_cid': 'bafy...',
              'token_number': '1',
              'current_owner': '0x111',
              'metadata': <String, dynamic>{},
            },
          ],
          'offset': 0,
        };

      final service = IndexerService(client: client);
      final tokens = await service.fetchTokensByAddresses(
        addresses: const ['0x111', '0x222'],
      );

      expect(tokens, hasLength(1));
      expect(client.lastSubKey, equals('tokens'));
      expect(client.lastDoc, equals(getTokens));
      expect(client.lastVars['owners'], equals(['0x111', '0x222']));
      expect(client.lastVars['limit'], equals(50));
      expect(client.lastVars['chains'], equals(['eip155:1', 'tezos:mainnet']));
      expect(client.lastVars.containsKey('offset'), isFalse);
    },
  );

  test(
    'IndexerService.fetchTokensPageByAddresses maps next offset cursor',
    () async {
      final client = FakeIndexerClient()
        ..tokensPayload = <String, dynamic>{
          'items': [
            {
              'id': '1',
              'chain': 'eip155:1',
              'contract_address': '0xabc',
              'standard': 'erc721',
              'token_cid': 'bafy...',
              'token_number': '1',
              'current_owner': '0x111',
              'metadata': <String, dynamic>{},
            },
          ],
          'offset': 50,
        };

      final service = IndexerService(client: client);
      final page = await service.fetchTokensPageByAddresses(
        addresses: const ['0x111'],
        limit: 50,
        offset: 0,
      );

      expect(page.tokens, hasLength(1));
      expect(page.nextOffset, equals(50));
      expect(client.lastVars['owners'], equals(['0x111']));
      expect(client.lastVars['limit'], equals(50));
      expect(client.lastVars['offset'], equals(0));
    },
  );

  test(
    'IndexerService.getManualTokens(tokenCids) maps token_cids + '
    'limit + offset',
    () async {
      final client = FakeIndexerClient()
        ..tokensPayload = <String, dynamic>{
          'items': [
            {
              'id': '1',
              'chain': 'eip155:1',
              'contract_address': '0xabc',
              'standard': 'erc721',
              'token_cid': 'cid1',
              'token_number': '1',
              'current_owner': '0x111',
              'metadata': <String, dynamic>{},
            },
            {
              'id': '2',
              'chain': 'eip155:1',
              'contract_address': '0xabc',
              'standard': 'erc721',
              'token_cid': 'cid2',
              'token_number': '2',
              'current_owner': '0x111',
              'metadata': <String, dynamic>{},
            },
            {
              'id': '3',
              'chain': 'eip155:1',
              'contract_address': '0xabc',
              'standard': 'erc721',
              'token_cid': 'cid3',
              'token_number': '3',
              'current_owner': '0x111',
              'metadata': <String, dynamic>{},
            },
          ],
          'offset': 0,
        };

      final service = IndexerService(client: client);
      final tokens = await service.getManualTokens(
        tokenCids: const ['cid1', 'cid2', 'cid3'],
      );

      expect(tokens, hasLength(3));
      expect(client.lastSubKey, equals('tokens'));
      expect(client.lastDoc, equals(getTokens));
      expect(client.lastVars['token_cids'], equals(['cid1', 'cid2', 'cid3']));
      expect(client.lastVars['limit'], equals(3));
      expect(client.lastVars['offset'], equals(0));
      expect(client.lastVars.containsKey('chains'), isFalse);
    },
  );

  test(
    'IndexerService.getManualTokens(tokenCids) batches in chunks of 40 '
    'when list is large',
    () async {
      final client = FakeIndexerClient()
        ..tokensPayloadBuilder = (vars) {
          final cids = List<String>.from(vars['token_cids'] as List);
          return <String, dynamic>{
            'items': [
              for (final cid in cids.reversed)
                {
                  'id': cid.replaceFirst('cid', ''),
                  'chain': 'eip155:1',
                  'contract_address': '0xabc',
                  'standard': 'erc721',
                  'token_cid': cid,
                  'token_number': '1',
                  'current_owner': '0x111',
                },
            ],
            'offset': 0,
          };
        };

      final service = IndexerService(client: client);
      final cids = List<String>.generate(85, (i) => 'cid$i');
      final tokens = await service.getManualTokens(tokenCids: cids);

      expect(tokens, hasLength(85));
      expect(tokens.first.cid, equals('cid0'));
      expect(tokens.last.cid, equals('cid84'));

      expect(client.tokenQueryVars, hasLength(3));
      expect(
        List<String>.from(client.tokenQueryVars[0]['token_cids'] as List),
        hasLength(40),
      );
      expect(client.tokenQueryVars[0]['limit'], equals(40));
      expect(client.tokenQueryVars[0]['offset'], equals(0));

      expect(
        List<String>.from(client.tokenQueryVars[1]['token_cids'] as List),
        hasLength(40),
      );
      expect(client.tokenQueryVars[1]['limit'], equals(40));
      expect(client.tokenQueryVars[1]['offset'], equals(0));

      expect(
        List<String>.from(client.tokenQueryVars[2]['token_cids'] as List),
        hasLength(5),
      );
      expect(client.tokenQueryVars[2]['limit'], equals(5));
      expect(client.tokenQueryVars[2]['offset'], equals(0));
    },
  );

  test(
    'IndexerService.getManualTokens(tokenIds) batches at 255 and applies offset/limit after merge',
    () async {
      final client = FakeIndexerClient()
        ..tokensPayloadBuilder = (vars) {
          final ids = List<int>.from(vars['token_ids'] as List);
          return <String, dynamic>{
            'items': [
              for (final id in ids.reversed)
                {
                  'id': id.toString(),
                  'chain': 'eip155:1',
                  'contract_address': '0xabc',
                  'standard': 'erc721',
                  'token_cid': 'cid$id',
                  'token_number': '1',
                  'current_owner': '0x111',
                },
            ],
            'offset': 0,
          };
        };

      final service = IndexerService(client: client);
      final tokenIds = List<int>.generate(300, (i) => i + 1);

      final tokens = await service.getManualTokens(
        tokenIds: tokenIds,
        offset: 10,
        limit: 20,
      );

      // Applied after merge in requested order.
      expect(tokens, hasLength(20));
      expect(tokens.first.id, equals(11));
      expect(tokens.last.id, equals(30));

      expect(client.tokenQueryVars, hasLength(2));
      expect(
        List<int>.from(client.tokenQueryVars[0]['token_ids'] as List),
        hasLength(255),
      );
      expect(client.tokenQueryVars[0]['limit'], equals(255));
      expect(client.tokenQueryVars[0]['offset'], equals(0));

      expect(
        List<int>.from(client.tokenQueryVars[1]['token_ids'] as List),
        hasLength(45),
      );
      expect(client.tokenQueryVars[1]['limit'], equals(45));
      expect(client.tokenQueryVars[1]['offset'], equals(0));
    },
  );

  test(
    'IndexerService.getManualTokens(tokenCids) returns empty on '
    'GraphQL failure',
    () async {
      final client = FakeIndexerClient()
        ..tokensPayloadBuilder = (_) => throw Exception('GraphQL 500');

      final service = IndexerService(client: client);
      final tokens = await service.getManualTokens(
        tokenCids: const ['cid1', 'cid2'],
      );

      expect(tokens, isEmpty);
    },
  );

  test(
    'IndexerService.getManualTokens(tokenCids) skips failed CID batch '
    'and continues',
    () async {
      final client = FakeIndexerClient()
        ..tokensPayloadBuilder = (vars) {
          final cids = List<String>.from(vars['token_cids'] as List);
          if (cids.contains('bad')) {
            throw Exception('GraphQL 500 for bad cid');
          }
          return <String, dynamic>{
            'items': [
              for (final cid in cids)
                {
                  'id': cid.replaceFirst('cid', ''),
                  'chain': 'eip155:1',
                  'contract_address': '0xabc',
                  'standard': 'erc721',
                  'token_cid': cid,
                  'token_number': '1',
                  'current_owner': '0x111',
                },
            ],
            'offset': 0,
          };
        };

      final service = IndexerService(client: client);
      final cids = <String>[
        ...List<String>.generate(40, (i) => i == 0 ? 'bad' : 'cid$i'),
        ...List<String>.generate(5, (i) => 'cid${40 + i}'),
      ];

      final tokens = await service.getManualTokens(tokenCids: cids);

      expect(tokens, hasLength(5));
      expect(tokens.map((t) => t.cid), equals(cids.skip(40).toList()));
    },
  );

  test(
    'IndexerService.getManualTokens concatenates ids then cids and '
    'dedupes by cid',
    () async {
      final client = FakeIndexerClient()
        ..tokensPayloadBuilder = (vars) {
          if (vars.containsKey('token_ids')) {
            final ids = List<int>.from(vars['token_ids'] as List);
            return <String, dynamic>{
              'items': [
                for (final id in ids)
                  {
                    'id': id.toString(),
                    'chain': 'eip155:1',
                    'contract_address': '0xabc',
                    'standard': 'erc721',
                    'token_cid': 'shared',
                    'token_number': '1',
                    'current_owner': '0x111',
                  },
              ],
              'offset': 0,
            };
          }
          final cids = List<String>.from(vars['token_cids'] as List);
          return <String, dynamic>{
            'items': [
              for (final cid in cids)
                {
                  'id': cid == 'shared' ? '999' : cid.replaceFirst('cid', ''),
                  'chain': 'eip155:1',
                  'contract_address': '0xabc',
                  'standard': 'erc721',
                  'token_cid': cid,
                  'token_number': '1',
                  'current_owner': '0x111',
                },
            ],
            'offset': 0,
          };
        };

      final service = IndexerService(client: client);
      final tokens = await service.getManualTokens(
        tokenIds: const [1],
        tokenCids: const ['shared', 'cid2'],
      );

      // Keep ID tokens first, then append non-duplicate CIDs.
      expect(tokens.map((t) => t.cid), equals(const ['shared', 'cid2']));
    },
  );

  test('IndexerService.triggerMetadataIndexing returns workflow_id and run_id',
      () async {
    final client = FakeIndexerClient()
      ..triggerMetadataIndexingPayload = const {
        'workflow_id': 'wf-123',
        'run_id': 'run-456',
      };

    final service = IndexerService(client: client);
    final result = await service.triggerMetadataIndexing(['bafy-test']);

    expect(result.workflowId, 'wf-123');
    expect(result.runId, 'run-456');
    expect(client.lastSubKey, equals('triggerMetadataIndexing'));
    expect(client.lastDoc, contains('triggerMetadataIndexing'));
    expect(client.lastVars['token_cids'], equals(['bafy-test']));
  });

  test('IndexerService.getWorkflowStatus returns status', () async {
    final client = FakeIndexerClient()
      ..workflowStatusPayload = const {
        'workflow_id': 'wf-1',
        'run_id': 'run-1',
        'status': 'COMPLETED',
      };

    final service = IndexerService(client: client);
    final result = await service.getWorkflowStatus(
      workflowId: 'wf-1',
      runId: 'run-1',
    );

    expect(result.workflowId, 'wf-1');
    expect(result.runId, 'run-1');
    expect(result.status, 'COMPLETED');
    expect(result.isTerminal, isTrue);
    expect(result.isSuccess, isTrue);
    expect(client.lastSubKey, equals('workflowStatus'));
    expect(client.lastVars['workflow_id'], equals('wf-1'));
    expect(client.lastVars['run_id'], equals('run-1'));
  });
}
