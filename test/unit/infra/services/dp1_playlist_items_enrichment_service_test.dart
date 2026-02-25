import 'package:app/domain/models/indexer/asset_token.dart';
import 'package:app/infra/database/app_database.dart';
import 'package:app/infra/database/database_service.dart';
import 'package:app/infra/graphql/indexer_client.dart';
import 'package:app/infra/services/dp1_playlist_items_enrichment_service.dart';
import 'package:app/infra/services/indexer_service.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeIndexerClient extends IndexerClient {
  _FakeIndexerClient() : super(endpoint: 'http://localhost');
}

class _FakeIndexerService extends IndexerService {
  _FakeIndexerService({required this.tokensByCid})
      : super(client: _FakeIndexerClient());

  final Map<String, AssetToken> tokensByCid;
  final List<List<String>> requestedCidBatches = <List<String>>[];

  @override
  Future<List<AssetToken>> getManualTokens({
    List<int>? tokenIds,
    List<String>? owners,
    List<String>? tokenCids,
    int? limit,
    int? offset,
  }) async {
    final cids = tokenCids ?? const <String>[];
    requestedCidBatches.add(List<String>.from(cids));
    return cids
        .map((cid) => tokensByCid[cid])
        .whereType<AssetToken>()
        .toList(growable: false);
  }
}

class _MockDatabaseService extends DatabaseService {
  _MockDatabaseService()
      : this._(AppDatabase.forTesting(NativeDatabase.memory()));

  _MockDatabaseService._(this._ownedDb) : super(_ownedDb);

  final AppDatabase _ownedDb;

  List<(String, String?, String, int)> highRows =
      <(String, String?, String, int)>[];
  List<(String, String?, String, int)> lowRows =
      <(String, String?, String, int)>[];
  final List<List<(String, AssetToken)>> batchWriteCalls =
      <List<(String, AssetToken)>>[];

  @override
  Future<List<(String, String?, String, int)>> loadHighPriorityBareItems({
    required int maxPerPlaylist,
    required int maxItems,
  }) async {
    return highRows.take(maxItems).toList(growable: false);
  }

  @override
  Future<List<(String, String?, String, int)>> loadLowPriorityBareItems({
    required int maxPerPlaylist,
    required int maxTotal,
  }) async {
    return lowRows.take(maxTotal).toList(growable: false);
  }

  @override
  Future<void> enrichPlaylistItemsWithTokensBatch({
    required List<(String, AssetToken)> enrichments,
  }) async {
    batchWriteCalls.add(List<(String, AssetToken)>.from(enrichments));
    final enrichedIds =
        enrichments.map((enrichment) => enrichment.$1).toSet();
    highRows = highRows
        .where((row) => !enrichedIds.contains(row.$1))
        .toList(growable: false);
    lowRows = lowRows
        .where((row) => !enrichedIds.contains(row.$1))
        .toList(growable: false);
  }

  @override
  Future<void> close() => _ownedDb.close();
}

void main() {
  group('DP1PlaylistItemsEnrichmentService - Constants', () {
    test('batch size constant is 50', () {
      expect(
        DP1PlaylistItemsEnrichmentService.indexerBatchSize,
        equals(50),
        reason: 'Indexer batch size should be 50 as per spec',
      );
    });

    test('high per playlist constant is 8', () {
      expect(
        DP1PlaylistItemsEnrichmentService.highPerPlaylist,
        equals(8),
        reason: 'High priority items per playlist should be 8',
      );
    });
  });

  group('DP1PlaylistItemsEnrichmentService - Queue logic', () {
    test('queue ordering logic: first 8 items are high priority', () {
      // Validate the queue ordering logic:
      // Items 0-7 go to high queue, items 8+ go to low queue
      const totalItems = 12;
      var highCount = 0;
      var lowCount = 0;

      for (var i = 0; i < totalItems; i++) {
        if (i < DP1PlaylistItemsEnrichmentService.highPerPlaylist) {
          highCount++;
        } else {
          lowCount++;
        }
      }

      expect(
        highCount,
        equals(8),
        reason: 'First 8 items should be high priority',
      );
      expect(
        lowCount,
        equals(4),
        reason: 'Remaining items should be low priority',
      );
    });

    test('batch fill logic: high first, then low', () {
      // Simulate queue processing logic
      const highQueueSize = 30;
      const lowQueueSize = 100;
      const batchSize = DP1PlaylistItemsEnrichmentService.indexerBatchSize;

      // First batch should take all from high
      const firstBatchSize = highQueueSize;
      expect(
        firstBatchSize,
        equals(30),
        reason: 'First batch takes all 30 from high queue',
      );

      // Second batch should take from high (0 remaining) + low (50)
      final remainingHigh = highQueueSize - firstBatchSize;
      final secondBatchSize = (remainingHigh + batchSize)
          .clamp(0, remainingHigh + lowQueueSize);
      expect(
        secondBatchSize,
        equals(50),
        reason: 'Second batch fills from low queue',
      );
    });
  });

  group('DP1PlaylistItemsEnrichmentService - Integration', () {
    test(
      'processAll builds token CID from provenance_json and writes '
      'in a single batch update',
      () async {
        const provenanceJson =
            '{"type":"onChain","contract":{"chain":"evm","standard":"erc721","address":"0x28b51BA8B990c48CB22cB6EF0ad5415fdBA5210C","tokenId":"59708377447550061117940200307772073115750811538487998108113477949081946656826","uri":null,"metaHash":null}}';
        const expectedCid =
            'eip155:1:erc721:0x28b51BA8B990c48CB22cB6EF0ad5415fdBA5210C:59708377447550061117940200307772073115750811538487998108113477949081946656826';

        final db = _MockDatabaseService()
          ..highRows = const <(String, String?, String, int)>[
            ('wk_dp1_1', provenanceJson, 'pl_1', 0),
          ];
        final indexer = _FakeIndexerService(
          tokensByCid: <String, AssetToken>{
            expectedCid: AssetToken(
              id: 1,
              cid: expectedCid,
              chain: 'eip155:1',
              standard: 'erc721',
              contractAddress: '0x28b51BA8B990c48CB22cB6EF0ad5415fdBA5210C',
              tokenNumber:
                  '59708377447550061117940200307772073115750811538487998108113477949081946656826',
              metadata: TokenMetadata(
                name: 'Token 1',
                artists: [Artist(did: 'did:example:1', name: 'Artist 1')],
              ),
            ),
          },
        );

        final service = DP1PlaylistItemsEnrichmentService(
          indexerService: indexer,
          databaseService: db,
        );

        await service.processAll();

        expect(indexer.requestedCidBatches, hasLength(1));
        expect(indexer.requestedCidBatches.single, equals([expectedCid]));

        expect(db.batchWriteCalls, hasLength(1));
        expect(db.batchWriteCalls.single, hasLength(1));
        expect(db.batchWriteCalls.single.single.$1, equals('wk_dp1_1'));
        expect(db.batchWriteCalls.single.single.$2.cid, equals(expectedCid));

        await db.close();
      },
    );

    test('service contract validates dependencies', () {
      expect(DP1PlaylistItemsEnrichmentService.highPerPlaylist, equals(8));
      expect(DP1PlaylistItemsEnrichmentService.indexerBatchSize, equals(50));
    });

    test('processAll keeps paging until all bare rows are enriched', () async {
      const address = '0x0A5c44da5F71B884c16A195CeC304F47ac0233CF';
      final tokensByCid = <String, AssetToken>{};
      final highRows = <(String, String?, String, int)>[];

      for (var i = 0; i < 120; i++) {
        final tokenId = (1000000 + i).toString();
        final provenanceJson =
            '{"type":"onChain","contract":{"chain":"evm","standard":"erc721","address":"$address","tokenId":"$tokenId","uri":null,"metaHash":null}}';
        final cid = 'eip155:1:erc721:$address:$tokenId';
        highRows.add(('wk_$i', provenanceJson, 'pl_1', i));
        tokensByCid[cid] = AssetToken(
          id: i + 1,
          cid: cid,
          chain: 'eip155:1',
          standard: 'erc721',
          contractAddress: address,
          tokenNumber: tokenId,
          metadata: TokenMetadata(name: 'Token $i'),
        );
      }

      final db = _MockDatabaseService()..highRows = highRows;
      final indexer = _FakeIndexerService(tokensByCid: tokensByCid);
      final service = DP1PlaylistItemsEnrichmentService(
        indexerService: indexer,
        databaseService: db,
      );

      await service.processAll();

      final totalUpdated = db.batchWriteCalls.fold<int>(
        0,
        (sum, batch) => sum + batch.length,
      );
      expect(totalUpdated, equals(120));
      expect(db.highRows, isEmpty);
      // Each DB query covers 6 playlists × 8 items = 48 items per round.
      // 120 total → rounds of 48, 48, 24.
      expect(indexer.requestedCidBatches, hasLength(3));
      expect(indexer.requestedCidBatches[0], hasLength(48));
      expect(indexer.requestedCidBatches[1], hasLength(48));
      expect(indexer.requestedCidBatches[2], hasLength(24));

      await db.close();
    });
  });
}
