import 'package:app/domain/models/dp1/dp1_playlist_item.dart';
import 'package:app/domain/models/dp1/dp1_provenance.dart';
import 'package:app/infra/database/app_database.dart';
import 'package:app/infra/database/database_service.dart';
import 'package:drift/drift.dart' show Value;
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

  test(
    'buildTokenCidFromProvenanceJson preserves explicit eip155 chain id',
    () {
      final cid = service.buildTokenCidFromProvenanceJson(
        '{"contract":{"chain":"eip155:11155111","standard":"erc721",'
        '"address":"0xabc","tokenId":"42"}}',
      );

      expect(cid, equals('eip155:11155111:erc721:0xabc:42'));
    },
  );

  test(
    'buildTokenCidFromProvenanceJson preserves explicit tezos network',
    () {
      final cid = service.buildTokenCidFromProvenanceJson(
        '{"contract":{"chain":"tezos:ghostnet","standard":"fa2",'
        '"address":"KT1xyz","tokenId":"7"}}',
      );

      expect(cid, equals('tezos:ghostnet:fa2:KT1xyz:7'));
    },
  );

  test(
    'buildTokenCidFromProvenanceJson normalizes EVM contract address',
    () {
      final cid = service.buildTokenCidFromProvenanceJson(
        '{"contract":{"chain":"eip155:1","standard":"erc721",'
        '"address":"0xa7d8d9ef8d8ce8992df33d8b8cf4aebabd5bd270","tokenId":"1234"}}',
      );

      expect(
        cid,
        equals(
          'eip155:1:erc721:0xa7d8d9ef8D8Ce8992Df33D8b8CF4Aebabd5bD270:1234',
        ),
      );
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

  test('markPlaylistItemsEnrichmentFailed persists failed status', () async {
    const itemId = 'item-failed-1';
    final nowUs = BigInt.from(DateTime.now().microsecondsSinceEpoch);
    await database.upsertItem(
      ItemsCompanion.insert(
        id: itemId,
        kind: 0,
        updatedAtUs: nowUs,
      ),
    );

    await service.markPlaylistItemsEnrichmentFailed([itemId]);

    final row = await database.getItemById(itemId);
    expect(row, isNotNull);
    expect(
      row!.enrichmentStatus,
      equals(DatabaseService.enrichmentStatusFailed),
    );
  });

  test('loadHighPriorityBareItems excludes enrichment-failed items', () async {
    const playlistId = 'pl-1';
    const itemId = 'item-1';
    final nowUs = BigInt.from(DateTime.now().microsecondsSinceEpoch);

    await database.upsertPlaylist(
      PlaylistsCompanion.insert(
        id: playlistId,
        type: 0,
        title: 'Playlist 1',
        createdAtUs: nowUs,
        updatedAtUs: nowUs,
        sortMode: 0,
      ),
    );

    await database.upsertItem(
      ItemsCompanion.insert(
        id: itemId,
        kind: 0,
        provenanceJson: const Value(
          '{"contract":{"chain":"evm","standard":"erc721","address":"0xabc","tokenId":"1"}}',
        ),
        updatedAtUs: nowUs,
      ),
    );

    await database.upsertPlaylistEntry(
      PlaylistEntriesCompanion.insert(
        playlistId: playlistId,
        itemId: itemId,
        position: const Value(0),
        sortKeyUs: nowUs,
        updatedAtUs: nowUs,
      ),
    );

    final before = await service.loadHighPriorityBareItems(
      maxPerPlaylist: 8,
      maxItems: 48,
    );
    expect(before, hasLength(1));

    await service.markPlaylistItemsEnrichmentFailed([itemId]);

    final after = await service.loadHighPriorityBareItems(
      maxPerPlaylist: 8,
      maxItems: 48,
    );
    expect(after, isEmpty);
  });
}
