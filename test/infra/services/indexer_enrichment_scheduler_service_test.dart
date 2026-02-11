import 'package:app/domain/models/indexer/asset_token.dart';
import 'package:app/infra/database/app_database.dart';
import 'package:app/infra/database/database_service.dart';
import 'package:app/infra/graphql/indexer_client.dart';
import 'package:app/infra/services/dp1_playlist_items_enrichment_service.dart';
import 'package:app/infra/services/indexer_enrichment_scheduler_service.dart';
import 'package:app/infra/services/indexer_service.dart';
import 'package:app/infra/services/indexer_sync_service.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeIndexerClient extends IndexerClient {
  _FakeIndexerClient() : super(endpoint: 'http://localhost');
}

class _FakeIndexerService extends IndexerService {
  _FakeIndexerService() : super(client: _FakeIndexerClient());

  @override
  Future<List<AssetToken>> fetchTokensByCIDs({
    required List<String> tokenCids,
  }) async {
    return const <AssetToken>[];
  }
}

class _FakeDatabaseService extends DatabaseService {
  _FakeDatabaseService()
    : this._(AppDatabase.forTesting(NativeDatabase.memory()));

  _FakeDatabaseService._(this._ownedDb) : super(_ownedDb);

  final AppDatabase _ownedDb;

  @override
  Future<void> close() => _ownedDb.close();
}

class _FakeIndexerSyncService extends IndexerSyncService {
  _FakeIndexerSyncService({
    required super.indexerService,
    required super.databaseService,
  });

  @override
  Future<int> syncTokensForAddresses({
    required List<String> addresses,
    int? limit,
    int? offset,
  }) async {
    return 0;
  }
}

class _FakeEnrichmentService extends DP1PlaylistItemsEnrichmentService {
  _FakeEnrichmentService({
    required super.indexerService,
    required super.databaseService,
    required List<EnrichmentWorkItem> high,
    required List<EnrichmentWorkItem> low,
  }) : _high = List<EnrichmentWorkItem>.from(high),
       _low = List<EnrichmentWorkItem>.from(low);

  final List<EnrichmentWorkItem> _high;
  final List<EnrichmentWorkItem> _low;

  final List<Map<String, String>> assignments = <Map<String, String>>[];

  int _active = 0;
  int maxObservedParallelism = 0;

  @override
  Future<List<EnrichmentWorkItem>> loadHighPriorityWorkItems({
    required int limit,
  }) async {
    return _high.take(limit).toList(growable: false);
  }

  @override
  Future<List<EnrichmentWorkItem>> loadLowPriorityWorkItems({
    required int limit,
  }) async {
    return _low.take(limit).toList(growable: false);
  }

  @override
  Future<int> enrichCidToItemMap(Map<String, String> cidToItemId) async {
    if (cidToItemId.isEmpty) return 0;

    _active += 1;
    if (_active > maxObservedParallelism) {
      maxObservedParallelism = _active;
    }

    assignments.add(Map<String, String>.from(cidToItemId));
    await Future<void>.delayed(const Duration(milliseconds: 20));

    final ids = cidToItemId.values.toSet();
    _high.removeWhere((item) => ids.contains(item.itemId));
    _low.removeWhere((item) => ids.contains(item.itemId));

    _active -= 1;
    return cidToItemId.length;
  }
}

class _CancellationEnrichmentService extends DP1PlaylistItemsEnrichmentService {
  _CancellationEnrichmentService({
    required super.indexerService,
    required super.databaseService,
  });

  @override
  Future<List<EnrichmentWorkItem>> loadHighPriorityWorkItems({
    required int limit,
  }) async {
    throw Exception('CancellationException (Operation was cancelled)');
  }
}

List<EnrichmentWorkItem> _workItems(String prefix, int count) {
  return List<EnrichmentWorkItem>.generate(
    count,
    (i) => EnrichmentWorkItem(
      itemId: '${prefix}_$i',
      cid: 'cid_${prefix}_$i',
      playlistId: 'pl_$prefix',
      position: i,
    ),
    growable: false,
  );
}

void main() {
  group('IndexerEnrichmentSchedulerService', () {
    late _FakeDatabaseService databaseService;
    late _FakeIndexerService indexerService;
    late _FakeIndexerSyncService syncService;

    setUp(() {
      databaseService = _FakeDatabaseService();
      indexerService = _FakeIndexerService();
      syncService = _FakeIndexerSyncService(
        indexerService: indexerService,
        databaseService: databaseService,
      );
    });

    tearDown(() async {
      await databaseService.close();
    });

    test(
      'high-priority backlog keeps one worker reserved and bursts low queue',
      () async {
        final enrichmentService = _FakeEnrichmentService(
          indexerService: indexerService,
          databaseService: databaseService,
          high: _workItems('h', 40),
          low: _workItems('l', 200),
        );

        final scheduler = IndexerEnrichmentSchedulerService(
          enrichmentService: enrichmentService,
          indexerSyncService: syncService,
        );

        final ok = await scheduler.processFeedEnrichmentUntilIdle();

        expect(ok, isTrue);
        expect(enrichmentService.assignments, hasLength(3));

        final sizes =
            enrichmentService.assignments.map((batch) => batch.length).toList()
              ..sort();
        expect(sizes, equals(<int>[50, 90, 100]));

        final mixed = enrichmentService.assignments.singleWhere(
          (batch) {
            final highCount = batch.values
                .where((itemId) => itemId.startsWith('h_'))
                .length;
            final lowCount = batch.values
                .where((itemId) => itemId.startsWith('l_'))
                .length;
            return highCount == 40 && lowCount == 10;
          },
        );
        expect(mixed.length, equals(50));

        expect(enrichmentService.maxObservedParallelism, equals(3));
      },
    );

    test(
      'without high-priority backlog all workers maximize low throughput',
      () async {
        final enrichmentService = _FakeEnrichmentService(
          indexerService: indexerService,
          databaseService: databaseService,
          high: const <EnrichmentWorkItem>[],
          low: _workItems('l', 350),
        );

        final scheduler = IndexerEnrichmentSchedulerService(
          enrichmentService: enrichmentService,
          indexerSyncService: syncService,
        );

        final ok = await scheduler.processFeedEnrichmentUntilIdle();

        expect(ok, isTrue);
        final sizes =
            enrichmentService.assignments.map((batch) => batch.length).toList()
              ..sort();
        expect(sizes, equals(<int>[50, 100, 100, 100]));
        expect(enrichmentService.maxObservedParallelism, equals(4));
      },
    );

    test('returns false instead of throwing on cancellation', () async {
      final enrichmentService = _CancellationEnrichmentService(
        indexerService: indexerService,
        databaseService: databaseService,
      );

      final scheduler = IndexerEnrichmentSchedulerService(
        enrichmentService: enrichmentService,
        indexerSyncService: syncService,
      );

      final result = await scheduler.processFeedEnrichmentUntilIdle();
      expect(result, isFalse);
    });
  });
}
