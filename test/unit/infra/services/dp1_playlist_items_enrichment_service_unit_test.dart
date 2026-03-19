import 'package:app/domain/models/indexer/asset_token.dart';
import 'package:app/infra/database/app_database.dart';
import 'package:app/infra/database/database_service.dart';
import 'package:app/infra/graphql/indexer_client.dart';
import 'package:app/infra/services/dp1_playlist_items_enrichment_service.dart';
import 'package:app/infra/services/indexer_service.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late _FakeIndexerService indexerService;
  late _RecordingDatabaseService databaseService;

  setUp(() {
    indexerService = _FakeIndexerService();
    databaseService = _RecordingDatabaseService();
  });

  tearDown(() async {
    await databaseService.close();
  });

  // Unit test: verifies enrichment requests are chunked by
  // the configured batch size (50).
  test('enrichCidToItemMap splits requests into 50-sized chunks', () async {
    final service = DP1PlaylistItemsEnrichmentService(
      indexerService: indexerService,
      databaseService: databaseService,
    );

    final cidToItemId = <String, String>{
      for (var i = 0; i < 120; i++) 'cid-$i': 'item-$i',
    };

    final updatedCount = await service.enrichCidToItemMap(cidToItemId);

    expect(indexerService.requestBatchSizes, equals([50, 50, 20]));
    expect(databaseService.batchUpdateSizes, equals([50, 50, 20]));
    expect(updatedCount, equals(120));
  });

  // Unit test: verifies processAll consumes high-priority rows first
  // and then low-priority rows.
  test(
    'processAll drains high-priority and low-priority queues from database',
    () async {
      databaseService
        ..highPriorityRows = [
          ('item-high-1', _validProvenanceJson('1'), 'pl-1', 0),
          ('item-high-2', _validProvenanceJson('2'), 'pl-1', 1),
        ]
        ..lowPriorityRows = [
          ('item-low-1', _validProvenanceJson('3'), 'pl-1', 9),
        ];

      final service = DP1PlaylistItemsEnrichmentService(
        indexerService: indexerService,
        databaseService: databaseService,
      );

      final completed = await service.processAll();

      expect(completed, isTrue);
      expect(databaseService.highPriorityReadCount, greaterThanOrEqualTo(2));
      expect(databaseService.lowPriorityReadCount, greaterThanOrEqualTo(2));
      expect(databaseService.batchUpdateSizes, equals([2, 1]));
    },
  );
}

class _FakeIndexerService extends IndexerService {
  _FakeIndexerService()
    : super(client: IndexerClient(endpoint: 'http://localhost'));

  final List<int> requestBatchSizes = <int>[];

  @override
  Future<List<AssetToken>> getManualTokens({
    List<int>? tokenIds,
    List<String>? owners,
    List<String>? tokenCids,
    int? limit,
    int? offset,
  }) async {
    final cids = tokenCids ?? const <String>[];
    requestBatchSizes.add(cids.length);
    return cids
        .map(
          (cid) => AssetToken(
            id: cid.hashCode,
            cid: cid,
            chain: 'eip155:1',
            standard: 'erc721',
            contractAddress: '0xabc',
            tokenNumber: '1',
            display: TokenMetadata(
              name: 'Work $cid',
              imageUrl: 'https://images.example/$cid.png',
            ),
          ),
        )
        .toList(growable: false);
  }
}

class _RecordingDatabaseService extends DatabaseService {
  _RecordingDatabaseService()
    : super(AppDatabase.forTesting(NativeDatabase.memory()));
  final List<int> batchUpdateSizes = <int>[];
  int highPriorityReadCount = 0;
  int lowPriorityReadCount = 0;

  List<(String, String?, String, int)> highPriorityRows =
      <(String, String?, String, int)>[];
  List<(String, String?, String, int)> lowPriorityRows =
      <(String, String?, String, int)>[];

  @override
  Future<List<(String, String?, String, int)>> loadHighPriorityBareItems({
    required int maxPerPlaylist,
    required int maxItems,
  }) async {
    highPriorityReadCount++;
    if (highPriorityRows.isEmpty) {
      return const <(String, String?, String, int)>[];
    }
    final rows = List<(String, String?, String, int)>.from(highPriorityRows);
    highPriorityRows = <(String, String?, String, int)>[];
    return rows;
  }

  @override
  Future<List<(String, String?, String, int)>> loadLowPriorityBareItems({
    required int maxPerPlaylist,
    required int maxTotal,
  }) async {
    lowPriorityReadCount++;
    if (lowPriorityRows.isEmpty) {
      return const <(String, String?, String, int)>[];
    }
    final rows = List<(String, String?, String, int)>.from(lowPriorityRows);
    lowPriorityRows = <(String, String?, String, int)>[];
    return rows;
  }

  @override
  Future<List<(String, String, String, int)>> extractTokenCidsFromBareRows({
    required List<(String, String?, String, int)> rows,
  }) async {
    return rows
        .where((row) => row.$2 != null)
        .map(
          (row) => (
            row.$1,
            'eip155:1:erc721:0xabc:${row.$4}',
            row.$3,
            row.$4,
          ),
        )
        .toList(growable: false);
  }

  @override
  Future<void> enrichPlaylistItemsWithTokensBatch({
    required List<(String, AssetToken)> enrichments,
  }) async {
    batchUpdateSizes.add(enrichments.length);
  }
}

String _validProvenanceJson(String tokenId) {
  return '{"contract":{"chain":"evm","standard":"erc721",'
      '"address":"0xabc","tokenId":"$tokenId"}}';
}
