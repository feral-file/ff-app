import 'dart:async';
import 'dart:io';

import 'package:app/app/providers/indexer_provider.dart';
import 'package:app/app/providers/indexer_tokens_provider.dart';
import 'package:app/domain/models/indexer/asset_token.dart';
import 'package:app/domain/models/indexer/changes/change.dart';
import 'package:app/domain/models/indexer/workflow.dart';
import 'package:app/infra/config/app_state_service.dart';
import 'package:app/infra/database/objectbox_models.dart';
import 'package:app/objectbox.g.dart' show openStore;
import 'package:app/infra/database/app_database.dart';
import 'package:app/infra/database/database_provider.dart';
import 'package:app/infra/database/database_service.dart';
import 'package:app/infra/graphql/indexer_client.dart';
import 'package:app/infra/indexer/isolate/indexer_tokens_worker.dart';
import 'package:app/infra/indexer/isolate/worker_messages.dart';
import 'package:app/infra/indexer/isolate/worker_tasks.dart';
import 'package:app/infra/services/indexer_service.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class FakeIndexerTokensWorker implements IndexerTokensWorker {
  FakeIndexerTokensWorker();

  final _controller = StreamController<TokensWorkerMessage>.broadcast();
  final _ready = Completer<void>()..complete();

  @override
  Stream<TokensWorkerMessage> get messages => _controller.stream;

  @override
  Future<void> get ready => _ready.future;

  @override
  bool get isRunning => true;

  List<AddressAnchor>? lastUpdateAnchors;

  void emit(TokensWorkerMessage message) => _controller.add(message);

  @override
  Future<void> start() async {}

  @override
  void updateTokensInIsolate({
    required String uuid,
    required List<AddressAnchor> addressAnchors,
  }) {
    lastUpdateAnchors = addressAnchors;
  }

  // Unused in these tests:
  @override
  String get endpoint => 'fake';

  @override
  String get apiKey => 'fake';

  @override
  void sendRaw(List<Object?> message) {}

  @override
  void fetchAllTokens({
    required String uuid,
    required List<String> addresses,
    int? offset,
    int? size,
  }) {}

  @override
  void reindexAddressesList({
    required String uuid,
    required List<String> addresses,
  }) {}

  @override
  void fetchManualTokens({
    required String uuid,
    required List<String> tokenCids,
  }) {}

  @override
  void notifyChannelIngested({required String uuid}) {}

  @override
  Future<void> stop() async {
    await _controller.close();
  }
}

class FakeIndexerService extends IndexerService {
  FakeIndexerService() : super(client: IndexerClient(endpoint: 'http://fake'));

  List<int> lastTokenIds = const [];
  List<String> lastOwners = const [];

  List<AssetToken> nextTokens = const [];

  @override
  Future<List<AssetToken>> fetchTokensByTokenIds({
    required List<int> tokenIds,
    List<String> owners = const [],
    int? limit,
    int? offset,
  }) async {
    lastTokenIds = tokenIds;
    lastOwners = owners;
    return nextTokens;
  }
}

class RecordingDatabaseService extends DatabaseService {
  RecordingDatabaseService()
    : super(AppDatabase.forTesting(NativeDatabase.memory()));

  final ingestedByAddress = <String, List<AssetToken>>{};
  final deletedByAddress = <String, List<String>>{};

  @override
  Future<void> ingestTokensForAddress({
    required String address,
    required List<AssetToken> tokens,
  }) async {
    ingestedByAddress[address] = [...tokens];
  }

  @override
  Future<void> deleteTokensByCids({
    required String address,
    required List<String> cids,
  }) async {
    deletedByAddress[address] = [...cids];
  }
}

void main() {
  test(
    'coordinator persists indexing status on ReindexAddressesListDone',
    () async {
      final tempDir = Directory.systemTemp.createTempSync('idx_cfg_');
      addTearDown(() => tempDir.deleteSync(recursive: true));
      final objectBoxStore = await openStore(directory: tempDir.path);
      addTearDown(objectBoxStore.close);

      final appStateService = AppStateService(
        appStateBox: objectBoxStore.box<AppStateEntity>(),
        appStateAddressBox: objectBoxStore.box<AppStateAddressEntity>(),
      );
      final worker = FakeIndexerTokensWorker();

      final container = ProviderContainer.test(
        overrides: [
          appStateServiceProvider.overrideWithValue(appStateService),
          indexerTokensWorkerProvider.overrideWithValue(worker),
        ],
      );
      addTearDown(container.dispose);

      container.read(tokensSyncCoordinatorProvider);

      worker.emit(
        const ReindexAddressesListDone(
          'u1',
          [
            AddressIndexingResult(address: '0xabc', workflowId: 'wf123'),
          ],
        ),
      );

      await Future<void>.delayed(Duration.zero);

      final status = await appStateService.getAddressIndexingStatus('0xABC');
      expect(
        status?.state,
        equals(AddressIndexingProcessState.waitingForIndexStatus),
      );
    },
  );

  test('coordinator uses tokenIds+owners and deletes missing cids', () async {
    final tempDir = Directory.systemTemp.createTempSync('idx_cfg_');
    addTearDown(() => tempDir.deleteSync(recursive: true));
    final objectBoxStore = await openStore(directory: tempDir.path);
    addTearDown(objectBoxStore.close);

    final appStateService = AppStateService(
      appStateBox: objectBoxStore.box<AppStateEntity>(),
      appStateAddressBox: objectBoxStore.box<AppStateAddressEntity>(),
    );
    final worker = FakeIndexerTokensWorker();
    final fakeIndexer = FakeIndexerService();
    final db = RecordingDatabaseService();

    // Return only cid1; cid2 should be deleted.
    fakeIndexer.nextTokens = [
      AssetToken.fromGraphQL({
        'id': '1',
        'chain': 'eip155:1',
        'contract_address': '0xabc',
        'standard': 'erc721',
        'token_cid': 'eip155:1:erc721:0xabc:1',
        'token_number': '1',
        'current_owner': '0xABC',
        'metadata': <String, dynamic>{},
      }),
    ];

    final container = ProviderContainer.test(
      overrides: [
        appStateServiceProvider.overrideWithValue(appStateService),
        indexerTokensWorkerProvider.overrideWithValue(worker),
        indexerServiceProvider.overrideWithValue(fakeIndexer),
        databaseServiceProvider.overrideWithValue(db),
      ],
    );
    addTearDown(container.dispose);

    container.read(tokensSyncCoordinatorProvider);

    // Build a ChangeList with 2 tokenIds and 2 derived tokenCids.
    final changes = ChangeList.fromJson({
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
            'token_id': 101,
            'from': null,
            'to': '0xABC',
          },
          'created_at': '2025-01-01T00:00:00Z',
          'updated_at': '2025-01-01T00:00:00Z',
        },
        {
          'id': 2,
          'subject_type': 'token',
          'subject_id': 't2',
          'changed_at': '2025-01-01T00:00:00Z',
          'meta': {
            'chain': 'eip155:1',
            'standard': 'erc721',
            'contract': '0xabc',
            'token_number': '2',
            'token_id': 202,
            'from': null,
            'to': '0xABC',
          },
          'created_at': '2025-01-01T00:00:00Z',
          'updated_at': '2025-01-01T00:00:00Z',
        },
      ],
      'offset': 0,
      'total': 2,
      'next_anchor': '50',
    });

    worker.emit(UpdateTokensData('u2', changes, const ['0xABC']));
    await Future<void>.delayed(Duration.zero);

    expect(fakeIndexer.lastTokenIds.toSet(), equals({101, 202}));
    expect(fakeIndexer.lastOwners, equals(['0xABC']));

    expect(db.ingestedByAddress['0xABC'], isNotNull);
    expect(
      db.deletedByAddress['0xABC'],
      equals(['eip155:1:erc721:0xabc:2']),
    );

    expect(await appStateService.getAddressAnchor('0xABC'), equals(50));
  });
}
