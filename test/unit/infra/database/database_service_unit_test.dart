import 'package:app/domain/models/dp1/dp1_playlist_item.dart';
import 'package:app/domain/models/dp1/dp1_provenance.dart';
import 'package:app/infra/database/app_database.dart';
import 'package:app/infra/database/database_service.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;
  late DatabaseService service;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    service = DatabaseService(database);
  });

  tearDown(() async {
    await database.close();
  });

  // Unit test: verifies CID extraction accepts valid EVM provenance payloads.
  test('buildTokenCidFromProvenanceJson returns EVM CID for valid payload', () {
    final cid = service.buildTokenCidFromProvenanceJson(
      '{"contract":{"chain":"evm","standard":"erc721",'
      '"address":"0xabc","tokenId":"42"}}',
    );

    expect(cid, equals('eip155:1:erc721:0xabc:42'));
  });

  // Unit test: verifies CID extraction accepts valid Tezos provenance payloads.
  test(
    'buildTokenCidFromProvenanceJson returns Tezos CID for valid payload',
    () {
      final cid = service.buildTokenCidFromProvenanceJson(
        '{"contract":{"chain":"tezos","standard":"fa2",'
        '"address":"KT1xyz","tokenId":"7"}}',
      );

      expect(cid, equals('tezos:mainnet:fa2:KT1xyz:7'));
    },
  );

  // Unit test: verifies CID extraction safely rejects malformed
  // or unsupported payloads.
  test('buildTokenCidFromProvenanceJson returns null for invalid payload', () {
    final cid = service.buildTokenCidFromProvenanceJson(
      '{"contract":{"chain":"other","standard":"other","address":"x"}}',
    );

    expect(cid, isNull);
  });

  // Unit test: verifies DP1 CID extraction keeps only items
  // with a resolvable provenance CID.
  test('extractDP1ItemCids filters out items without CID', () {
    final items = <DP1PlaylistItem>[
      DP1PlaylistItem(
        id: 'item-with-cid',
        duration: 0,
        provenance: DP1Provenance(
          type: DP1ProvenanceType.onChain,
          contract: DP1Contract(
            chain: DP1ProvenanceChain.evm,
            standard: DP1ProvenanceStandard.erc721,
            address: '0xabc',
            tokenId: '1',
          ),
        ),
      ),
      DP1PlaylistItem(
        id: 'item-without-cid',
        duration: 0,
        provenance: DP1Provenance(
          type: DP1ProvenanceType.onChain,
          contract: DP1Contract(
            chain: DP1ProvenanceChain.other,
            standard: DP1ProvenanceStandard.other,
            seriesId: 'series-only',
          ),
        ),
      ),
    ];

    final cids = service.extractDP1ItemCids(items);

    expect(cids, equals(['eip155:1:erc721:0xabc:1']));
  });
}
