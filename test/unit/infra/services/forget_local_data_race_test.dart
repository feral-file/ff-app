import 'dart:async';

import 'package:app/app/providers/indexer_provider.dart';
import 'package:app/app/providers/indexer_tokens_provider.dart';
import 'package:app/domain/models/indexer/asset_token.dart';
import 'package:app/domain/models/indexer/changes/change.dart';
import 'package:app/domain/models/playlist.dart';
import 'package:app/infra/config/app_state_service.dart';
import 'package:app/infra/database/app_database.dart';
import 'package:app/infra/database/database_provider.dart';
import 'package:app/infra/database/database_service.dart';
import 'package:app/infra/graphql/indexer_client.dart';
import 'package:app/infra/indexer/isolate/indexer_tokens_worker.dart';
import 'package:app/infra/indexer/isolate/worker_messages.dart';
import 'package:app/infra/indexer/isolate/worker_tasks.dart';
import 'package:app/infra/services/local_data_cleanup_service.dart';
import 'package:app/infra/services/indexer_service.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeIndexerClient extends IndexerClient {
  _FakeIndexerClient() : super(endpoint: 'https://example.invalid');
}

class _DelayedIndexerService extends IndexerService {
  _DelayedIndexerService({
    required this.address,
    required this.delay,
  }) : super(client: _FakeIndexerClient());

  final String address;
  final Duration delay;

  @override
  Future<List<AssetToken>> fetchTokensByTokenIds({
    required List<int> tokenIds,
    List<String> owners = const [],
    int? limit,
    int? offset,
  }) async {
    await Future<void>.delayed(delay);
    return tokenIds
        .map(
          (id) => AssetToken(
            id: id,
            cid: 'eip155:1:0xcontract:$id',
            chain: 'eip155:1',
            standard: 'erc721',
            contractAddress: '0xcontract',
            tokenNumber: '$id',
            currentOwner: address.toUpperCase(),
          ),
        )
        .toList(growable: false);
  }
}

class _ControlledIndexerTokensWorker extends IndexerTokensWorker {
  _ControlledIndexerTokensWorker()
    : super(endpoint: 'https://example.invalid', apiKey: '');

  final StreamController<TokensWorkerMessage> _controller =
      StreamController<TokensWorkerMessage>.broadcast();

  @override
  Stream<TokensWorkerMessage> get messages => _controller.stream;

  @override
  Future<void> get ready async {}

  @override
  Future<void> start() async {}

  @override
  Future<void> stop() async {
    // Keep stream open intentionally so queued messages can still be delivered,
    // reproducing the race where in-flight writes outlive reset.
  }

  @override
  void updateTokensInIsolate({
    required String uuid,
    required List<AddressAnchor> addressAnchors,
  }) {
    final address = addressAnchors.first.address;
    final now = DateTime.now().toUtc();
    final changes = ChangeList(
      items: <Change>[
        Change(
          id: 1,
          subjectType: SubjectType.token,
          subjectId: '1',
          changedAt: now,
          createdAt: now,
          updatedAt: now,
          meta: <String, dynamic>{
            'chain': 'eip155:1',
            'standard': 'erc721',
            'contract': '0xcontract',
            'token_number': '1',
            'token_id': 1,
            'to': address,
          },
        ),
        Change(
          id: 2,
          subjectType: SubjectType.token,
          subjectId: '2',
          changedAt: now,
          createdAt: now,
          updatedAt: now,
          meta: <String, dynamic>{
            'chain': 'eip155:1',
            'standard': 'erc721',
            'contract': '0xcontract',
            'token_number': '2',
            'token_id': 2,
            'to': address,
          },
        ),
        Change(
          id: 3,
          subjectType: SubjectType.token,
          subjectId: '3',
          changedAt: now,
          createdAt: now,
          updatedAt: now,
          meta: <String, dynamic>{
            'chain': 'eip155:1',
            'standard': 'erc721',
            'contract': '0xcontract',
            'token_number': '3',
            'token_id': 3,
            'to': address,
          },
        ),
        Change(
          id: 4,
          subjectType: SubjectType.token,
          subjectId: '4',
          changedAt: now,
          createdAt: now,
          updatedAt: now,
          meta: <String, dynamic>{
            'chain': 'eip155:1',
            'standard': 'erc721',
            'contract': '0xcontract',
            'token_number': '4',
            'token_id': 4,
            'to': address,
          },
        ),
      ],
      total: 4,
      nextAnchor: 4,
    );

    _controller.add(UpdateTokensData(uuid, changes, <String>[address]));
    Future<void>.delayed(const Duration(milliseconds: 5), () {
      _controller.add(UpdateTokensSuccess(uuid));
    });
  }

  @override
  void reindexAddressesList({
    required String uuid,
    required List<String> addresses,
  }) {}

  @override
  void notifyChannelIngested({required String uuid}) {}
}

class _TestAppStateService implements AppStateService {
  final Map<String, int> _anchors = <String, int>{};

  @override
  Future<int?> getAddressAnchor(String address) async {
    return _anchors[address.toUpperCase()];
  }

  @override
  Future<void> setAddressAnchor({
    required String address,
    required int anchor,
  }) async {
    _anchors[address.toUpperCase()] = anchor;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

void main() {
  group('Forget local data race with personal playlist sync', () {
    late AppDatabase db;
    late DatabaseService dbService;
    late ProviderContainer container;
    late _ControlledIndexerTokensWorker worker;
    const address = '0x99fc8ad516fbcc9ba3123d56e63a35d05aa9efb8';

    setUp(() async {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      dbService = DatabaseService(db);
      worker = _ControlledIndexerTokensWorker();

      final now = DateTime.now().toUtc();
      await dbService.ingestPlaylist(
        Playlist(
          id: 'addr:ETH:$address',
          name: address,
          type: PlaylistType.addressBased,
          ownerAddress: address,
          sortMode: PlaylistSortMode.provenance,
          createdAt: now,
          updatedAt: now,
        ),
      );

      container = ProviderContainer.test(
        overrides: [
          appStateServiceProvider.overrideWithValue(_TestAppStateService()),
          databaseServiceProvider.overrideWithValue(dbService),
          indexerServiceProvider.overrideWithValue(
            _DelayedIndexerService(
              address: address,
              delay: const Duration(milliseconds: 80),
            ),
          ),
          indexerTokensWorkerProvider.overrideWithValue(worker),
        ],
      );
    });

    tearDown(() async {
      container.dispose();
      await db.close();
    });

    Future<int> personalEntryCount() async {
      final row = await db.customSelect(
        '''
            SELECT COUNT(*) AS count
            FROM playlist_entries pe
            JOIN playlists p ON p.id = pe.playlist_id
            WHERE p.type = 1
            ''',
      ).getSingle();
      return row.read<int>('count');
    }

    test(
      'naive reset can leave late-arriving personal playlist rows',
      () async {
        final notifier = container.read(tokensSyncCoordinatorProvider.notifier);
        final syncFuture = notifier.syncAddresses(const <String>[address]);
        await Future<void>.delayed(const Duration(milliseconds: 10));

        final service = LocalDataCleanupService(
          stopWorkersGracefully: worker.stop,
          checkpointDatabase: dbService.checkpoint,
          truncateDatabase: dbService.clearAll,
          clearObjectBoxData: () async {},
          clearCachedImages: () async {},
          getPersonalAddresses: () async => const <String>[],
          restorePersonalAddressPlaylists: (_) async {},
          refetchFromBeginning: (_) async {},
          pauseFeedWork: () {},
          pauseTokenPolling: () {},
          enablePostDrainSweep: false,
        );

        unawaited(
          Future<void>.delayed(const Duration(milliseconds: 40), () async {
            final now = DateTime.now().toUtc();
            await dbService.ingestPlaylist(
              Playlist(
                id: 'addr:ETH:$address',
                name: address,
                type: PlaylistType.addressBased,
                ownerAddress: address,
                sortMode: PlaylistSortMode.provenance,
                createdAt: now,
                updatedAt: now,
              ),
            );
          }),
        );

        await service.clearLocalData();
        await Future<void>.delayed(const Duration(milliseconds: 120));
        await syncFuture.catchError((_) {});

        expect(await personalEntryCount(), equals(4));
      },
    );

    test('drain-aware reset prevents late personal playlist writes', () async {
      final notifier = container.read(tokensSyncCoordinatorProvider.notifier);
      final syncFuture = notifier.syncAddresses(const <String>[address]);
      await Future<void>.delayed(const Duration(milliseconds: 10));

      final service = LocalDataCleanupService(
        stopWorkersGracefully: notifier.stopAndDrainForReset,
        checkpointDatabase: dbService.checkpoint,
        truncateDatabase: dbService.clearAll,
        clearObjectBoxData: () async {},
        clearCachedImages: () async {},
        getPersonalAddresses: () async => const <String>[],
        restorePersonalAddressPlaylists: (_) async {},
        refetchFromBeginning: (_) async {},
        pauseFeedWork: () {},
        pauseTokenPolling: notifier.pausePolling,
        postDrainSettleDuration: const Duration(milliseconds: 100),
      );

      unawaited(
        Future<void>.delayed(const Duration(milliseconds: 40), () async {
          final now = DateTime.now().toUtc();
          await dbService.ingestPlaylist(
            Playlist(
              id: 'addr:ETH:$address',
              name: address,
              type: PlaylistType.addressBased,
              ownerAddress: address,
              sortMode: PlaylistSortMode.provenance,
              createdAt: now,
              updatedAt: now,
            ),
          );
        }),
      );

      await service.clearLocalData();
      await Future<void>.delayed(const Duration(milliseconds: 120));
      await syncFuture;

      expect(await personalEntryCount(), equals(0));
    });

    test('post-drain sweep clears late recreated personal rows', () async {
      final notifier = container.read(tokensSyncCoordinatorProvider.notifier);
      final syncFuture = notifier.syncAddresses(const <String>[address]);
      await Future<void>.delayed(const Duration(milliseconds: 10));

      final service = LocalDataCleanupService(
        stopWorkersGracefully: notifier.stopAndDrainForReset,
        checkpointDatabase: dbService.checkpoint,
        truncateDatabase: dbService.clearAll,
        clearObjectBoxData: () async {},
        clearCachedImages: () async {},
        getPersonalAddresses: () async => const <String>[],
        restorePersonalAddressPlaylists: (_) async {},
        refetchFromBeginning: (_) async {},
        pauseFeedWork: () {},
        pauseTokenPolling: notifier.pausePolling,
        postDrainSettleDuration: const Duration(milliseconds: 120),
      );

      unawaited(
        Future<void>.delayed(const Duration(milliseconds: 40), () async {
          final now = DateTime.now().toUtc();
          await dbService.ingestPlaylist(
            Playlist(
              id: 'addr:ETH:$address',
              name: address,
              type: PlaylistType.addressBased,
              ownerAddress: address,
              sortMode: PlaylistSortMode.provenance,
              createdAt: now,
              updatedAt: now,
            ),
          );
          await dbService.ingestTokensForAddress(
            address: address,
            tokens: <AssetToken>[
              AssetToken(
                id: 999,
                cid: 'eip155:1:erc721:0xcontract:999',
                chain: 'eip155:1',
                standard: 'erc721',
                contractAddress: '0xcontract',
                tokenNumber: '999',
                currentOwner: address.toUpperCase(),
              ),
            ],
          );
        }),
      );

      await service.clearLocalData();
      await Future<void>.delayed(const Duration(milliseconds: 160));
      await syncFuture;

      expect(await personalEntryCount(), equals(0));
    });
  });
}
