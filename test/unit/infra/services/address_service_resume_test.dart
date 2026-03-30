import 'package:app/domain/extensions/playlist_ext.dart';
import 'package:app/domain/models/models.dart';
import 'package:app/infra/config/app_state_service.dart';
import 'package:app/infra/database/app_database.dart';
import 'package:app/infra/database/database_service.dart';
import 'package:app/infra/database/seed_database_gate.dart';
import 'package:app/infra/graphql/indexer_client.dart';
import 'package:app/infra/services/address_service.dart';
import 'package:app/infra/services/domain_address_service.dart';
import 'package:app/infra/services/indexer_service.dart';
import 'package:app/infra/services/indexer_sync_service.dart';
import 'package:app/infra/services/personal_tokens_sync_service.dart';
import 'package:drift/native.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_indexer_service_isolate.dart';

/// Fake AppStateService for resume tests with configurable statuses.
class _FakeAppStateServiceForResume implements AppStateServiceBase {
  _FakeAppStateServiceForResume({
    this.statuses = const {},
    this.trackedAddresses = const [],
  });

  final Map<String, AddressIndexingProcessStatus> statuses;
  final List<String> trackedAddresses;
  final List<String> setStatusCalls = <String>[];
  final List<AddressIndexingProcessStatus> recordedStatuses =
      <AddressIndexingProcessStatus>[];

  @override
  Future<Map<String, AddressIndexingProcessStatus>>
      getAllAddressIndexingStatuses() async =>
      Map.fromEntries(statuses.entries);

  @override
  Future<void> setAddressIndexingStatus({
    required String address,
    required AddressIndexingProcessStatus status,
  }) async {
    recordedStatuses.add(status);
    setStatusCalls.add('$address:${status.state.name}');
  }

  @override
  Future<void> addTrackedAddress(String address, {String alias = ''}) async {}

  @override
  Stream<AddressIndexingProcessStatus?> watchAddressIndexingStatus(
    String address,
  ) =>
      Stream.value(statuses[address]);

  @override
  Future<void> trackPersonalAddress(String address) async {}

  @override
  Future<List<String>> getTrackedPersonalAddresses() async => trackedAddresses;

  @override
  Future<void> clearAddressState(String address) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  setUpAll(() {
    dotenv.testLoad(fileInput: 'INDEXER_API_URL=https://example.invalid');
  });

  group('AddressService resume', () {
    late AppDatabase database;
    late DatabaseService databaseService;
    late FakeIndexerServiceIsolate fakeIndexer;
    late _FakeAppStateServiceForResume fakeAppState;

    setUp(() {
      SeedDatabaseGate.complete();
      database = AppDatabase.forTesting(NativeDatabase.memory());
      databaseService = DatabaseService(database);
      fakeIndexer = FakeIndexerServiceIsolate();
      fakeAppState = _FakeAppStateServiceForResume();
    });

    tearDown(() async {
      await database.close();
      SeedDatabaseGate.resetForTesting();
    });

    AddressService createAddressService({
      Map<String, AddressIndexingProcessStatus>? statuses,
      List<String>? trackedAddresses,
    }) {
      final s = statuses ?? {};
      fakeAppState = _FakeAppStateServiceForResume(
        statuses: s,
        trackedAddresses: trackedAddresses ?? s.keys.toList(),
      );
      return AddressService(
        databaseService: databaseService,
        indexerSyncService: IndexerSyncService(
          indexerService: IndexerService(
            client: IndexerClient(endpoint: 'https://example.invalid'),
          ),
          databaseService: databaseService,
        ),
        domainAddressService: DomainAddressService(
          resolverUrl: '',
          resolverApiKey: '',
        ),
        personalTokensSyncService: PersonalTokensSyncService(
          indexerService: IndexerService(
            client: IndexerClient(endpoint: 'https://example.invalid'),
          ),
          databaseService: databaseService,
          appStateService: fakeAppState,
        ),
        indexerServiceIsolate: fakeIndexer,
        appStateService: fakeAppState,
      );
    }

    test(
        'indexAndSyncAddress sets indexingTriggeredPending then workflow id '
        'when runTriggerIndex',
        () async {
      const address = '0xabc';
      fakeIndexer.pullStatusResult = const AddressIndexingJobResponse(
        workflowId: 'wf-1',
        address: address,
        status: IndexingJobStatus.completed,
        totalTokensIndexed: 2,
        totalTokensViewable: 2,
      );
      fakeIndexer.fetchTokensResult = TokensPage(
        tokens: [
          AssetToken(
            id: 1,
            cid: 'cid1',
            chain: 'eip155:1',
            standard: 'ERC-721',
            contractAddress: address,
            tokenNumber: '1',
          ),
        ],
      );

      final playlist = PlaylistExt.fromWalletAddress(
        WalletAddress(
          address: address,
          createdAt: DateTime.now(),
          name: 'Test',
        ),
      );
      await databaseService.ingestPlaylist(playlist);

      final service = createAddressService();
      await service.indexAndSyncAddress(address);

      expect(fakeAppState.recordedStatuses.first.state,
          AddressIndexingProcessState.indexingTriggered);
      expect(fakeAppState.recordedStatuses.first.workflowId, isNull);
      final withWorkflowId = fakeAppState.recordedStatuses
          .where((s) => s.workflowId == 'wf-1')
          .toList();
      expect(withWorkflowId, isNotEmpty);
      expect(withWorkflowId.first.state,
          AddressIndexingProcessState.indexingTriggered);
      expect(fakeIndexer.callSequence, contains('index'));
    });

    test('indexAndSyncAddress with resumeFrom.poll calls poll and completes',
        () async {
      const address = '0xabc';
      fakeIndexer.pullStatusResult = const AddressIndexingJobResponse(
        workflowId: 'wf-1',
        address: address,
        status: IndexingJobStatus.completed,
        totalTokensIndexed: 2,
        totalTokensViewable: 2,
      );
      fakeIndexer.fetchTokensResult = TokensPage(
        tokens: [
          AssetToken(
            id: 1,
            cid: 'cid1',
            chain: 'eip155:1',
            standard: 'ERC-721',
            contractAddress: address,
            tokenNumber: '1',
          ),
        ],
      );

      final playlist = PlaylistExt.fromWalletAddress(
        WalletAddress(
          address: address,
          createdAt: DateTime.now(),
          name: 'Test',
        ),
      );
      await databaseService.ingestPlaylist(playlist);

      final service = createAddressService();
      await service.indexAndSyncAddress(
        address,
        runFastPathFetch: false,
        runTriggerIndex: false,
        workflowId: 'wf-1',
      );

      expect(fakeIndexer.callSequence, contains('pullStatus'));
      expect(fakeIndexer.callSequence, contains('fetchTokens'));
      expect(fakeAppState.setStatusCalls, contains('0xabc:completed'));
    });

    test('indexAndSyncAddress with resumeFrom.fromFetchOnly completes', () async {
      const address = '0xabc';
      fakeIndexer.fetchTokensResult = TokensPage(
        tokens: [
          AssetToken(
            id: 1,
            cid: 'cid1',
            chain: 'eip155:1',
            standard: 'ERC-721',
            contractAddress: address,
            tokenNumber: '1',
          ),
        ],
      );

      final playlist = PlaylistExt.fromWalletAddress(
        WalletAddress(
          address: address,
          createdAt: DateTime.now(),
          name: 'Test',
        ),
      );
      await databaseService.ingestPlaylist(playlist);

      final service = createAddressService();
      await service.indexAndSyncAddress(
        address,
        runFastPathFetch: false,
        runTriggerIndex: false,
        runPoll: false,
      );

      expect(fakeIndexer.callSequence, contains('fetchTokens'));
      expect(fakeIndexer.callSequence, isNot(contains('index')));
      expect(fakeIndexer.callSequence, isNot(contains('pullStatus')));
      expect(fakeAppState.setStatusCalls, contains('0xabc:completed'));
    });

    test('resumeIndexingForAddresses skips completed', () async {
      const address = '0xabc';
      final playlist = PlaylistExt.fromWalletAddress(
        WalletAddress(
          address: address,
          createdAt: DateTime.now(),
          name: 'Test',
        ),
      );
      await databaseService.ingestPlaylist(playlist);

      final statuses = <String, AddressIndexingProcessStatus>{
        '0xabc': AddressIndexingProcessStatus.completed(),
      };
      final toResume = <String>[];
      final service = createAddressService(statuses: statuses);

      await service.resumeIndexingForAddresses(toResume);

      expect(fakeIndexer.callSequence, isEmpty);
    });

    test('resumeIndexingForAddresses routes idle to restart', () async {
      const address = '0xabc';
      final playlist = PlaylistExt.fromWalletAddress(
        WalletAddress(
          address: address,
          createdAt: DateTime.now(),
          name: 'Test',
        ),
      );
      await databaseService.ingestPlaylist(playlist);

      fakeIndexer.fetchTokensResult = const TokensPage(tokens: []);
      fakeIndexer.pullStatusResult = const AddressIndexingJobResponse(
        workflowId: 'wf-1',
        address: address,
        status: IndexingJobStatus.completed,
        totalTokensIndexed: 0,
        totalTokensViewable: 0,
      );

      final statuses = {
        address: AddressIndexingProcessStatus.idle(),
      };
      final toResume = [address];
      final service = createAddressService(statuses: statuses);

      await service.resumeIndexingForAddresses(toResume);

      // Wait for delay + unawaited indexAndSyncAddress to run.
      await Future<void>.delayed(const Duration(milliseconds: 600));

      expect(fakeIndexer.callSequence, contains('index'));
    });

    test(
      'resumeIndexingForAddresses with empty toResume does nothing',
      () async {
        const address = '0xabc';
        final playlist = PlaylistExt.fromWalletAddress(
          WalletAddress(
            address: address,
            createdAt: DateTime.now(),
            name: 'Test',
          ),
        );
        await databaseService.ingestPlaylist(playlist);

        fakeIndexer.fetchTokensResult = const TokensPage(tokens: []);
        fakeIndexer.pullStatusResult = const AddressIndexingJobResponse(
          workflowId: 'wf-1',
          address: address,
          status: IndexingJobStatus.completed,
          totalTokensIndexed: 0,
          totalTokensViewable: 0,
        );

        final statuses = <String, AddressIndexingProcessStatus>{};
        final toResume = <String>[];
        final service = createAddressService(
          statuses: statuses,
          trackedAddresses: [address],
        );

        await service.resumeIndexingForAddresses(toResume);

        expect(fakeAppState.setStatusCalls, isEmpty);

        await Future<void>.delayed(const Duration(milliseconds: 600));

        expect(fakeIndexer.callSequence, isEmpty);
      },
    );

    test(
      'resumeIndexingForAddresses routes indexingTriggered+workflowId to poll',
      () async {
        const address = '0xabc';
        final playlist = PlaylistExt.fromWalletAddress(
          WalletAddress(
            address: address,
            createdAt: DateTime.now(),
            name: 'Test',
          ),
        );
        await databaseService.ingestPlaylist(playlist);

        fakeIndexer.pullStatusResult = const AddressIndexingJobResponse(
          workflowId: 'wf-1',
          address: address,
          status: IndexingJobStatus.completed,
          totalTokensIndexed: 0,
          totalTokensViewable: 0,
        );
        fakeIndexer.fetchTokensResult = const TokensPage(tokens: []);

        final statuses = {
          address: AddressIndexingProcessStatus.indexingTriggered(
            workflowId: 'wf-1',
          ),
        };
        final toResume = [address];
        final service = createAddressService(statuses: statuses);

        await service.resumeIndexingForAddresses(toResume);

        await Future<void>.delayed(const Duration(milliseconds: 600));

        expect(fakeIndexer.callSequence, contains('pullStatus'));
        expect(fakeIndexer.callSequence, isNot(contains('index')));
      },
    );

    test('resumeIndexingForAddresses routes syncingTokens to fetch only',
        () async {
      const address = '0xabc';
      final playlist = PlaylistExt.fromWalletAddress(
        WalletAddress(
          address: address,
          createdAt: DateTime.now(),
          name: 'Test',
        ),
      );
      await databaseService.ingestPlaylist(playlist);

      fakeIndexer.fetchTokensResult = const TokensPage(tokens: []);

      final statuses = {
        address: AddressIndexingProcessStatus.syncingTokens(),
      };
      final toResume = [address];
      final service = createAddressService(statuses: statuses);

      await service.resumeIndexingForAddresses(toResume);

      await Future<void>.delayed(const Duration(milliseconds: 600));

      expect(fakeIndexer.callSequence, contains('fetchTokens'));
      expect(fakeIndexer.callSequence, isNot(contains('index')));
      expect(fakeIndexer.callSequence, isNot(contains('pullStatus')));
    });
  });
}
