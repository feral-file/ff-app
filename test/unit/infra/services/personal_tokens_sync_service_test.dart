import 'dart:async';

import 'package:app/domain/constants/indexer_constants.dart';
import 'package:app/domain/models/models.dart';
import 'package:app/domain/utils/address_deduplication.dart';
import 'package:app/infra/config/app_state_service.dart';
import 'package:app/infra/database/app_database.dart';
import 'package:app/infra/database/database_service.dart';
import 'package:app/infra/graphql/indexer_client.dart';
import 'package:app/infra/services/indexer_service.dart';
import 'package:app/infra/services/personal_tokens_sync_service.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeAppStateService implements AppStateService {
  final Map<String, int?> personalTokensOffsets = {};

  @override
  Future<int?> getPersonalTokensListFetchOffset(String address) async {
    return personalTokensOffsets[address.toNormalizedAddress()];
  }

  @override
  Future<void> setPersonalTokensListFetchOffset({
    required String address,
    required int? nextFetchOffset,
  }) async {
    final key = address.toNormalizedAddress();
    if (nextFetchOffset == null) {
      personalTokensOffsets.remove(key);
    } else {
      personalTokensOffsets[key] = nextFetchOffset;
    }
  }

  @override
  Future<void> clearAllPersonalTokensListFetchOffsets() async {
    personalTokensOffsets.clear();
  }

  @override
  Stream<AddressIndexingProcessStatus?> watchAddressIndexingStatus(
    String address,
  ) => Stream.value(null);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _RecordingIndexerService extends IndexerService {
  _RecordingIndexerService()
    : super(client: IndexerClient(endpoint: 'https://example.invalid'));

  final List<String> requestedAddresses = <String>[];
  final List<int?> fetchOffsets = <int?>[];

  /// When non-empty, returns successive pages (cursor tests). Otherwise empty.
  List<TokensPage> responseSequence = const [];
  int _responseIndex = 0;
  Future<void> Function(int fetchCount)? beforeFetchPageReturn;

  final List<int?> fetchLimits = <int?>[];

  @override
  Future<TokensPage> fetchTokensPageByAddresses({
    required List<String> addresses,
    int? limit,
    int? offset,
  }) async {
    requestedAddresses.addAll(addresses);
    fetchOffsets.add(offset);
    fetchLimits.add(limit);
    final hook = beforeFetchPageReturn;
    if (hook != null) {
      await hook(fetchOffsets.length);
    }
    final hasMore =
        responseSequence.isNotEmpty && _responseIndex < responseSequence.length;
    if (hasMore) {
      return responseSequence[_responseIndex++];
    }
    return const TokensPage(tokens: []);
  }

  void resetForNextRun() {
    _responseIndex = 0;
    fetchOffsets.clear();
    fetchLimits.clear();
    requestedAddresses.clear();
  }
}

void main() {
  // Covers: indexer page size, nextOffset chaining, persisted offset vs
  // playlist itemCount (indexer_constants + rule 50).

  test('sync uses lowercased 0x address format for indexer fetch', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final databaseService = DatabaseService(database);
    const playlistOwner = '0X99FC8AD516FBCC9BA3123D56E63A35D05AA9EFB8';

    await databaseService.ingestPlaylist(
      const Playlist(
        id: 'addr:eth:0x99fc8ad516fbcc9ba3123d56e63a35d05aa9efb8',
        name: 'Personal',
        type: PlaylistType.addressBased,
        channelId: Channel.myCollectionId,
        ownerAddress: playlistOwner,
        ownerChain: 'eth',
      ),
    );

    final indexer = _RecordingIndexerService();
    final service = PersonalTokensSyncService(
      indexerService: indexer,
      databaseService: databaseService,
      appStateService: _FakeAppStateService(),
    );

    await service.syncAddresses(addresses: const <String>[playlistOwner]);

    expect(
      indexer.requestedAddresses,
      equals(const <String>['0x99fc8ad516fbcc9ba3123d56e63a35d05aa9efb8']),
    );
    expect(indexer.fetchLimits, equals(<int?>[indexerTokensPageSize]));
  });

  test('sync advances offset via nextOffset cursor', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final databaseService = DatabaseService(database);
    const playlistOwner = '0X99FC8AD516FBCC9BA3123D56E63A35D05AA9EFB8';

    await databaseService.ingestPlaylist(
      const Playlist(
        id: 'addr:eth:0x99fc8ad516fbcc9ba3123d56e63a35d05aa9efb8',
        name: 'Personal',
        type: PlaylistType.addressBased,
        channelId: Channel.myCollectionId,
        ownerAddress: playlistOwner,
        ownerChain: 'eth',
      ),
    );

    final indexer = _RecordingIndexerService()
      ..responseSequence = [
        TokensPage(
          tokens: [
            AssetToken(
              id: 1,
              cid: 'cid1',
              chain: 'eip155:1',
              standard: 'ERC-721',
              contractAddress: '0xabc',
              tokenNumber: '1',
            ),
          ],
          nextOffset: 100,
        ),
        TokensPage(
          tokens: [
            AssetToken(
              id: 2,
              cid: 'cid2',
              chain: 'eip155:1',
              standard: 'ERC-721',
              contractAddress: '0xabc',
              tokenNumber: '2',
            ),
          ],
        ),
      ];

    final service = PersonalTokensSyncService(
      indexerService: indexer,
      databaseService: databaseService,
      appStateService: _FakeAppStateService(),
    );

    await service.syncAddresses(addresses: const <String>[playlistOwner]);

    expect(indexer.fetchOffsets, equals(const <int?>[0, 100]));
    expect(indexer.requestedAddresses, hasLength(2));
    expect(
      indexer.fetchLimits,
      equals(<int?>[indexerTokensPageSize, indexerTokensPageSize]),
    );
  });

  test(
    'uses persisted list fetch offset on resume, not playlist itemCount',
    () async {
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);
      final databaseService = DatabaseService(database);
      const playlistOwner = '0x99fc8ad516fbcc9ba3123d56e63a35d05aa9efb8';

      await databaseService.ingestPlaylist(
        const Playlist(
          id: 'addr:eth:0x99fc8ad516fbcc9ba3123d56e63a35d05aa9efb8',
          name: 'Personal',
          type: PlaylistType.addressBased,
          channelId: Channel.myCollectionId,
          ownerAddress: playlistOwner,
          ownerChain: 'eth',
          itemCount: 3,
        ),
      );

      final appState = _FakeAppStateService()
        // Simulates ObjectBox after a prior run saved the indexer cursor
        // (can differ from ingested row count).
        ..personalTokensOffsets[playlistOwner.toNormalizedAddress()] = 500;

      final indexer = _RecordingIndexerService()
        ..responseSequence = [
          TokensPage(
            tokens: [
              AssetToken(
                id: 2,
                cid: 'cid2',
                chain: 'eip155:1',
                standard: 'ERC-721',
                contractAddress: '0xabc',
                tokenNumber: '2',
              ),
            ],
          ),
        ];

      await PersonalTokensSyncService(
        indexerService: indexer,
        databaseService: databaseService,
        appStateService: appState,
      ).syncAddresses(addresses: const <String>[playlistOwner]);

      expect(
        indexer.fetchOffsets,
        equals(const <int?>[500]),
        reason: 'Must use persisted 500, not itemCount 3',
      );
      expect(
        indexer.fetchLimits,
        equals(<int?>[indexerTokensPageSize]),
      );
      expect(
        appState.personalTokensOffsets[playlistOwner.toNormalizedAddress()],
        isNull,
      );
    },
  );

  test('continues after empty page when nextOffset is non-null', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final databaseService = DatabaseService(database);
    const playlistOwner = '0X99FC8AD516FBCC9BA3123D56E63A35D05AA9EFB8';

    await databaseService.ingestPlaylist(
      const Playlist(
        id: 'addr:eth:0x99fc8ad516fbcc9ba3123d56e63a35d05aa9efb8',
        name: 'Personal',
        type: PlaylistType.addressBased,
        channelId: Channel.myCollectionId,
        ownerAddress: playlistOwner,
        ownerChain: 'eth',
      ),
    );

    final indexer = _RecordingIndexerService()
      ..responseSequence = [
        const TokensPage(tokens: [], nextOffset: 42),
        TokensPage(
          tokens: [
            AssetToken(
              id: 1,
              cid: 'cid1',
              chain: 'eip155:1',
              standard: 'ERC-721',
              contractAddress: '0xabc',
              tokenNumber: '1',
            ),
          ],
        ),
      ];

    final appState = _FakeAppStateService();

    await PersonalTokensSyncService(
      indexerService: indexer,
      databaseService: databaseService,
      appStateService: appState,
    ).syncAddresses(addresses: const <String>[playlistOwner]);

    expect(indexer.fetchOffsets, equals(const <int?>[0, 42]));
    expect(indexer.requestedAddresses, hasLength(2));
    expect(
      appState.personalTokensOffsets[playlistOwner.toNormalizedAddress()],
      isNull,
    );
  });

  test(
    'preserves persisted cursor across restart when playlist is empty but '
    'resume cursor is valid',
    () async {
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);
      final databaseService = DatabaseService(database);
      const playlistOwner = '0x99fc8ad516fbcc9ba3123d56e63a35d05aa9efb8';

      await databaseService.ingestPlaylist(
        const Playlist(
          id: 'addr:eth:0x99fc8ad516fbcc9ba3123d56e63a35d05aa9efb8',
          name: 'Personal',
          type: PlaylistType.addressBased,
          channelId: Channel.myCollectionId,
          ownerAddress: playlistOwner,
          ownerChain: 'eth',
        ),
      );

      final appState = _FakeAppStateService()
        ..personalTokensOffsets[playlistOwner.toNormalizedAddress()] = 42;

      final indexer = _RecordingIndexerService()
        ..responseSequence = [
          TokensPage(
            tokens: [
              AssetToken(
                id: 1,
                cid: 'cid1',
                chain: 'eip155:1',
                standard: 'ERC-721',
                contractAddress: '0xabc',
                tokenNumber: '1',
              ),
            ],
          ),
        ];

      await PersonalTokensSyncService(
        indexerService: indexer,
        databaseService: databaseService,
        appStateService: appState,
      ).syncAddresses(addresses: const <String>[playlistOwner]);

      expect(
        indexer.fetchOffsets,
        equals(const <int?>[42]),
        reason:
            'an empty playlist is not enough to prove the persisted cursor '
            'is stale',
      );
      expect(
        appState.personalTokensOffsets[playlistOwner.toNormalizedAddress()],
        isNull,
      );
    },
  );

  test('syncAddresses runs single-flight per address', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final databaseService = DatabaseService(database);
    const playlistOwner = '0x99fc8ad516fbcc9ba3123d56e63a35d05aa9efb8';

    await databaseService.ingestPlaylist(
      const Playlist(
        id: 'addr:eth:0x99fc8ad516fbcc9ba3123d56e63a35d05aa9efb8',
        name: 'Personal',
        type: PlaylistType.addressBased,
        channelId: Channel.myCollectionId,
        ownerAddress: playlistOwner,
        ownerChain: 'eth',
      ),
    );

    final firstFetchGate = Completer<void>();
    final indexer = _RecordingIndexerService()
      ..beforeFetchPageReturn = (fetchCount) async {
        if (fetchCount == 1 && !firstFetchGate.isCompleted) {
          await firstFetchGate.future;
        }
      }
      ..responseSequence = [
        const TokensPage(tokens: [], nextOffset: 100),
        const TokensPage(tokens: []),
        const TokensPage(tokens: []),
      ];

    final appState = _FakeAppStateService();
    final service = PersonalTokensSyncService(
      indexerService: indexer,
      databaseService: databaseService,
      appStateService: appState,
    );

    final firstRun = service.syncAddresses(
      addresses: const <String>[playlistOwner],
    );
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(indexer.fetchOffsets, equals(const <int?>[0]));

    final secondRun = service.syncAddresses(
      addresses: const <String>[playlistOwner],
    );
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(
      indexer.fetchOffsets,
      equals(const <int?>[0]),
      reason: 'the second same-address run must wait for the first to finish',
    );

    firstFetchGate.complete();
    await Future.wait<void>([firstRun, secondRun]);
  });
}
