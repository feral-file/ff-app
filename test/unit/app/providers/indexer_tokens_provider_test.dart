import 'package:app/app/providers/indexer_tokens_provider.dart';
import 'package:app/domain/models/indexer/asset_token.dart';
import 'package:app/domain/models/indexer/changes/change.dart';
import 'package:app/infra/config/app_state_service.dart';
import 'package:app/infra/database/app_database.dart';
import 'package:app/infra/database/database_provider.dart';
import 'package:app/infra/database/database_service.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'provider_test_helpers.dart';

class TestAppStateService implements AppStateService {
  final Map<String, int> anchors = <String, int>{};

  @override
  Future<int?> getAddressAnchor(String address) async => anchors[address];

  @override
  Future<void> setAddressAnchor({
    required String address,
    required int anchor,
  }) async {
    anchors[address] = anchor;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

AssetToken _buildToken({
  required int id,
  required String cid,
  String currentOwner = 'EINSTEIN-ROSEN.ETH',
}) {
  return AssetToken(
    id: id,
    cid: cid,
    chain: 'eip155:1',
    standard: 'erc721',
    contractAddress: '0xabc',
    tokenNumber: '$id',
    currentOwner: currentOwner,
    metadata: TokenMetadata(imageUrl: 'https://example.com/$id.png'),
  );
}

Change _buildChange({
  required int id,
  required int tokenId,
  required String tokenCid,
}) {
  final parts = tokenCid.split(':');
  return Change.fromJson(<String, dynamic>{
    'id': id,
    'subject_type': 'token',
    'subject_id': 'subject_$id',
    'changed_at': DateTime.now().toIso8601String(),
    'created_at': DateTime.now().toIso8601String(),
    'updated_at': DateTime.now().toIso8601String(),
    'meta': <String, dynamic>{
      'chain': '${parts[0]}:${parts[1]}',
      'standard': parts[2],
      'contract': parts[3],
      'token_number': parts[4],
      'token_id': tokenId,
      'to': '0xowner',
    },
  });
}

Future<void> _seedAddressPlaylist(AppDatabase database, String address) async {
  final nowUs = DateTime.now().microsecondsSinceEpoch;
  await database.customStatement(
    '''
    INSERT INTO playlists (
      id, channel_id, type, base_url, dp_version, slug, title,
      created_at_us, updated_at_us, signatures_json, defaults_json,
      dynamic_queries_json, owner_address, owner_chain, sort_mode, item_count
    ) VALUES (?, NULL, 1, NULL, NULL, NULL, ?, ?, ?, '[]', NULL, NULL, ?, NULL, 1, 0)
    ''',
    <Object>[
      'pl_$address',
      'Address $address',
      nowUs,
      nowUs,
      address.toUpperCase(),
    ],
  );
}

void main() {
  test('TokensSyncState copyWith updates fields', () {
    // Unit test: verifies data-state copy semantics for token sync coordinator state.
    const initial = TokensSyncState();
    final next = initial.copyWith(
      syncingAddresses: {'0xabc'},
      errorMessage: 'failed',
    );
    expect(next.syncingAddresses, {'0xabc'});
    expect(next.errorMessage, 'failed');
  });

  test('tokensSyncCoordinatorProvider builds with fake worker/app state', () {
    // Unit test: verifies coordinator notifier can initialize with mocked dependencies.
    final container = ProviderContainer.test(
      overrides: [
        appStateServiceProvider.overrideWithValue(MockAppStateService()),
        indexerTokensWorkerProvider.overrideWithValue(
          FakeIndexerTokensWorker(),
        ),
      ],
    );
    addTearDown(container.dispose);

    final state = container.read(tokensSyncCoordinatorProvider);
    expect(state.syncingAddresses, isEmpty);
    expect(state.errorMessage, isNull);
  });

  test('tokens sync coordinator can stop and drain for reset', () async {
    final container = ProviderContainer.test(
      overrides: [
        appStateServiceProvider.overrideWithValue(MockAppStateService()),
        indexerTokensWorkerProvider.overrideWithValue(
          FakeIndexerTokensWorker(),
        ),
      ],
    );
    addTearDown(container.dispose);

    final notifier = container.read(tokensSyncCoordinatorProvider.notifier);
    await notifier.stopAndDrainForReset();
    final state = container.read(tokensSyncCoordinatorProvider);
    expect(state.syncingAddresses, isEmpty);
  });

  test('syncAddresses uses getManualTokens and ingests tokens', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final databaseService = DatabaseService(database);
    final appState = TestAppStateService();
    final worker = FakeIndexerTokensWorker();
    const tokenCid = 'eip155:1:erc721:0xabc:1';
    worker
      ..updateTokensDataResponse = ChangeList(
        items: <Change>[
          _buildChange(id: 1, tokenId: 1, tokenCid: tokenCid),
        ],
        total: 1,
        nextAnchor: 88,
      )
      ..manualTokenResponse = <AssetToken>[
        _buildToken(id: 1, cid: tokenCid),
      ];

    final container = ProviderContainer.test(
      overrides: [
        appStateServiceProvider.overrideWithValue(appState),
        indexerTokensWorkerProvider.overrideWithValue(worker),
        databaseServiceProvider.overrideWithValue(databaseService),
      ],
    );
    addTearDown(container.dispose);
    await _seedAddressPlaylist(database, 'einstein-rosen.eth');

    final notifier = container.read(tokensSyncCoordinatorProvider.notifier);
    await notifier.syncAddresses(const <String>['einstein-rosen.eth']);

    expect(worker.lastRequestedTokenIds, contains(1));
    expect(worker.lastRequestedTokenOwners, contains('einstein-rosen.eth'));
    expect(appState.anchors['einstein-rosen.eth'], equals(88));

    final playlists = await databaseService.getAddressPlaylists();
    expect(playlists, isNotEmpty);
    final items = await databaseService.getPlaylistItems(playlists.first.id);
    expect(items.length, equals(1));
    expect(items.first.id, equals(tokenCid));
  });

  test('syncAddresses skips getManualTokens when no tokenIds', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final databaseService = DatabaseService(database);
    final appState = TestAppStateService();
    final worker = FakeIndexerTokensWorker()
      ..updateTokensDataResponse = const ChangeList(
        items: <Change>[],
        total: 0,
        nextAnchor: 7,
      );

    final container = ProviderContainer.test(
      overrides: [
        appStateServiceProvider.overrideWithValue(appState),
        indexerTokensWorkerProvider.overrideWithValue(worker),
        databaseServiceProvider.overrideWithValue(databaseService),
      ],
    );
    addTearDown(container.dispose);
    await _seedAddressPlaylist(database, 'einstein-rosen.eth');

    final notifier = container.read(tokensSyncCoordinatorProvider.notifier);
    await notifier.syncAddresses(const <String>['einstein-rosen.eth']);

    expect(worker.lastRequestedTokenIds, isNull);
    expect(appState.anchors['einstein-rosen.eth'], equals(7));
  });

  test(
    'syncAddresses keeps running and stores error when getManualTokens fails',
    () async {
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);
      final databaseService = DatabaseService(database);
      final appState = TestAppStateService();
      const tokenCid = 'eip155:1:erc721:0xabc:9';
      final worker = FakeIndexerTokensWorker()
        ..updateTokensDataResponse = ChangeList(
          items: <Change>[
            _buildChange(id: 2, tokenId: 9, tokenCid: tokenCid),
          ],
          total: 1,
          nextAnchor: 12,
        )
        ..manualTokenError = Exception('token IDs fetch failed');

      final container = ProviderContainer.test(
        overrides: [
          appStateServiceProvider.overrideWithValue(appState),
          indexerTokensWorkerProvider.overrideWithValue(worker),
          databaseServiceProvider.overrideWithValue(databaseService),
        ],
      );
      addTearDown(container.dispose);
      await _seedAddressPlaylist(database, 'einstein-rosen.eth');

      final notifier = container.read(tokensSyncCoordinatorProvider.notifier);
      await notifier.syncAddresses(const <String>['einstein-rosen.eth']);

      final state = container.read(tokensSyncCoordinatorProvider);
      expect(state.errorMessage, contains('token IDs fetch failed'));
      expect(appState.anchors.containsKey('einstein-rosen.eth'), isFalse);
    },
  );
}
