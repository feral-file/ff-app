import 'dart:async';

import 'package:app/app/providers/database_service_provider.dart';
import 'package:app/app/providers/ff1_bluetooth_device_providers.dart';
import 'package:app/app/providers/ff1_wifi_providers.dart';
import 'package:app/app/providers/now_displaying_provider.dart';
import 'package:app/app/providers/services_provider.dart';
import 'package:app/domain/models/dp1/dp1_playlist_item.dart';
import 'package:app/domain/models/dp1/dp1_provenance.dart';
import 'package:app/domain/models/ff1_device.dart';
import 'package:app/domain/models/indexer/asset_token.dart';
import 'package:app/domain/models/now_displaying_object.dart';
import 'package:app/domain/models/playlist_item.dart';
import 'package:app/infra/database/app_database.dart';
import 'package:app/infra/database/database_service.dart';
import 'package:app/infra/ff1/wifi_protocol/ff1_wifi_messages.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'provider_test_helpers.dart';

void main() {
  group('NowDisplayingNotifier enrichment', () {
    late AppDatabase db;
    late _RecordingDatabaseService recordingDb;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      recordingDb = _RecordingDatabaseService(db);
    });

    tearDown(() async {
      await db.close();
    });

    test('enriches missing items and persists only those with token', () async {
      const deviceId = 'device_1';
      const device = FF1Device(
        name: 'FF1',
        remoteId: 'r1',
        deviceId: deviceId,
        topicId: 'topic_1',
      );

      // DP1 item with cid that we will match with a token
      final dp1Item = DP1PlaylistItem(
        id: 'item_1',
        duration: 60,
        title: 'Work',
        provenance: DP1Provenance(
          type: DP1ProvenanceType.onChain,
          contract: DP1Contract(
            chain: DP1ProvenanceChain.evm,
            standard: DP1ProvenanceStandard.erc721,
            address: '0xabc',
            tokenId: '1',
          ),
        ),
      );

      const cid = 'eip155:1:erc721:0xabc:1';
      final token = AssetToken(
        id: 1,
        cid: cid,
        chain: 'eip155:1',
        standard: 'ERC-721',
        contractAddress: '0xabc',
        tokenNumber: '1',
        display: TokenMetadata(
          name: 'Token Title',
          imageUrl: 'https://example.com/thumb.jpg',
        ),
      );

      final status = FF1PlayerStatus(
        playlistId: 'pl_1',
        currentWorkIndex: 0,
        items: [dp1Item],
      );

      final container = ProviderContainer.test(
        overrides: [
          databaseServiceProvider.overrideWith((ref) => recordingDb),
          indexerServiceProvider.overrideWithValue(
            FakeIndexerService(tokensByCid: [token]),
          ),
          activeFF1BluetoothDeviceProvider.overrideWithValue(
            const AsyncData(device),
          ),
          ff1WifiControlProvider.overrideWithValue(FakeWifiControl()),
          ff1PlayerStatusStreamProvider.overrideWith(
            (ref) => Stream.value(status),
          ),
          ff1CurrentPlayerStatusProvider.overrideWithValue(status),
          ff1ConnectionStatusStreamProvider.overrideWith(
            (ref) => Stream.value(const FF1ConnectionStatus(isConnected: true)),
          ),
          ff1DeviceConnectedProvider.overrideWithValue(true),
          // Ensure cache is ready (empty) when _computeForDevice runs
          // so missing = [dp1Item]
          nowDisplayingCachedPlaylistItemsProvider.overrideWith(
            (ref) => Future.value(<PlaylistItem>[]),
          ),
        ],
      );
      addTearDown(container.dispose);

      // Trigger notifier build; listeners will schedule _recompute on microtask
      container.read(nowDisplayingProvider);
      // Drain microtask queue so _recompute runs
      await Future<void>.delayed(Duration.zero);

      final state = container.read(nowDisplayingProvider);
      expect(
        state,
        isA<NowDisplayingSuccess>(),
        reason:
            'Expected NowDisplayingSuccess so _computeForDevice ran with '
            'device+connected+status; got $state',
      );

      await recordingDb.enrichmentDone.future.timeout(
        const Duration(seconds: 5),
        onTimeout: () => throw TimeoutException(
          'Enrichment did not call upsertPlaylistItemsEnriched; '
          'savedEnriched=${recordingDb.savedEnriched}',
        ),
      );

      expect(recordingDb.savedEnriched, isNotNull);
      expect(recordingDb.savedEnriched!.length, 1);
      final saved = recordingDb.savedEnriched!.single;
      expect(saved.id, 'item_1');
      expect(saved.thumbnailUrl, isNotNull);
    });

    test(
      'keeps initial status until async window cache read completes',
      () async {
        const device = FF1Device(
          name: 'FF1',
          remoteId: 'r1',
          deviceId: 'device_1',
          topicId: 'topic_1',
        );

        final dp1Item = DP1PlaylistItem(
          id: 'item_1',
          duration: 60,
          title: 'Work',
        );

        final status = FF1PlayerStatus(
          playlistId: 'pl_1',
          currentWorkIndex: 0,
          items: [dp1Item],
        );

        final recordingSlow = _RecordingDatabaseService(
          db,
          cacheDelay: const Duration(milliseconds: 80),
        );

        final container = ProviderContainer.test(
          overrides: [
            databaseServiceProvider.overrideWith((ref) => recordingSlow),
            indexerServiceProvider.overrideWithValue(FakeIndexerService()),
            activeFF1BluetoothDeviceProvider.overrideWithValue(
              const AsyncData(device),
            ),
            ff1WifiControlProvider.overrideWithValue(FakeWifiControl()),
            ff1PlayerStatusStreamProvider.overrideWith(
              (ref) => Stream.value(status),
            ),
            ff1CurrentPlayerStatusProvider.overrideWithValue(status),
            ff1ConnectionStatusStreamProvider.overrideWith(
              (ref) => Stream.value(const FF1ConnectionStatus(isConnected: true)),
            ),
            ff1DeviceConnectedProvider.overrideWithValue(true),
          ],
        );
        addTearDown(container.dispose);

        container.read(nowDisplayingProvider);
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(const Duration(milliseconds: 40));

        expect(
          container.read(nowDisplayingProvider),
          isA<InitialNowDisplayingStatus>(),
          reason:
              '_computeForDevice awaits nowDisplayingCachedPlaylistItemsProvider.'
              'future before state = success',
        );

        await Future<void>.delayed(const Duration(milliseconds: 120));
        expect(container.read(nowDisplayingProvider), isA<NowDisplayingSuccess>());
      },
    );

    test(
      'does not call indexer when slow DB cache already has window items',
      () async {
      const deviceId = 'device_1';
      const device = FF1Device(
        name: 'FF1',
        remoteId: 'r1',
        deviceId: deviceId,
        topicId: 'topic_1',
      );

      final dp1Item = DP1PlaylistItem(
        id: 'item_1',
        duration: 60,
        title: 'Work',
        provenance: DP1Provenance(
          type: DP1ProvenanceType.onChain,
          contract: DP1Contract(
            chain: DP1ProvenanceChain.evm,
            standard: DP1ProvenanceStandard.erc721,
            address: '0xabc',
            tokenId: '1',
          ),
        ),
      );

      const cid = 'eip155:1:erc721:0xabc:1';
      final token = AssetToken(
        id: 1,
        cid: cid,
        chain: 'eip155:1',
        standard: 'ERC-721',
        contractAddress: '0xabc',
        tokenNumber: '1',
        display: TokenMetadata(
          name: 'Token Title',
          imageUrl: 'https://example.com/thumb.jpg',
        ),
      );

      final status = FF1PlayerStatus(
        playlistId: 'pl_1',
        currentWorkIndex: 0,
        items: [dp1Item],
      );

      const cached = PlaylistItem(
        id: 'item_1',
        kind: PlaylistItemKind.indexerToken,
        title: 'Already in DB',
      );
      final recordingSlow = _RecordingDatabaseService(
        db,
        cacheDelay: const Duration(milliseconds: 30),
        cachedItemsById: {'item_1': cached},
      );

      final fakeIndexer = FakeIndexerService(tokensByCid: [token]);

      final container = ProviderContainer.test(
        overrides: [
          databaseServiceProvider.overrideWith((ref) => recordingSlow),
          indexerServiceProvider.overrideWithValue(fakeIndexer),
          activeFF1BluetoothDeviceProvider.overrideWithValue(
            const AsyncData(device),
          ),
          ff1WifiControlProvider.overrideWithValue(FakeWifiControl()),
          ff1PlayerStatusStreamProvider.overrideWith(
            (ref) => Stream.value(status),
          ),
          ff1CurrentPlayerStatusProvider.overrideWithValue(status),
          ff1ConnectionStatusStreamProvider.overrideWith(
            (ref) => Stream.value(const FF1ConnectionStatus(isConnected: true)),
          ),
          ff1DeviceConnectedProvider.overrideWithValue(true),
        ],
      );
      addTearDown(container.dispose);

      container.read(nowDisplayingProvider);
      await Future<void>.delayed(Duration.zero);
      // Wait past slow cache + async recompute; indexer must stay unused.
      await Future<void>.delayed(const Duration(milliseconds: 100));

      expect(
        fakeIndexer.lastTokenCids,
        isNull,
        reason:
            'getManualTokens must not run when items are already cached '
            '(even if getPlaylistItemsByIds completes after a delay)',
      );
    });

    test(
      'discards stale recompute when player status updates during slow enrich',
      () async {
        const device = FF1Device(
          name: 'FF1',
          remoteId: 'r1',
          deviceId: 'device_1',
          topicId: 'topic_1',
        );

        DP1PlaylistItem dp1WithCid(String id, String tokenNum) =>
            DP1PlaylistItem(
              id: id,
              duration: 60,
              title: 'Work',
              provenance: DP1Provenance(
                type: DP1ProvenanceType.onChain,
                contract: DP1Contract(
                  chain: DP1ProvenanceChain.evm,
                  standard: DP1ProvenanceStandard.erc721,
                  address: '0xabc',
                  tokenId: tokenNum,
                ),
              ),
            );

        final tokenA = AssetToken(
          id: 1,
          cid: 'eip155:1:erc721:0xabc:1',
          chain: 'eip155:1',
          standard: 'ERC-721',
          contractAddress: '0xabc',
          tokenNumber: '1',
          display: TokenMetadata(name: 'A'),
        );
        final tokenB = AssetToken(
          id: 2,
          cid: 'eip155:1:erc721:0xabc:2',
          chain: 'eip155:1',
          standard: 'ERC-721',
          contractAddress: '0xabc',
          tokenNumber: '2',
          display: TokenMetadata(name: 'B'),
        );

        final indexer = _FirstCallSlowIndexer(
          delay: const Duration(milliseconds: 250),
          tokensByCid: [tokenA, tokenB],
        );

        final statusA = FF1PlayerStatus(
          playlistId: 'pl_1',
          currentWorkIndex: 0,
          items: [dp1WithCid('item_a', '1')],
        );
        final statusB = FF1PlayerStatus(
          playlistId: 'pl_1',
          currentWorkIndex: 0,
          items: [dp1WithCid('item_b', '2')],
        );

        final container = ProviderContainer.test(
          overrides: [
            databaseServiceProvider.overrideWith((ref) => recordingDb),
            indexerServiceProvider.overrideWithValue(indexer),
            activeFF1BluetoothDeviceProvider.overrideWithValue(
              const AsyncData(device),
            ),
            ff1PlayerStatusStreamProvider.overrideWith(
              (ref) => Stream<FF1PlayerStatus>.periodic(
                const Duration(milliseconds: 20),
                (count) => count == 0 ? statusA : statusB,
              ).take(2),
            ),
            ff1ConnectionStatusStreamProvider.overrideWith(
              (ref) =>
                  Stream.value(const FF1ConnectionStatus(isConnected: true)),
            ),
            ff1DeviceConnectedProvider.overrideWithValue(true),
          ],
        );
        addTearDown(container.dispose);

        // Ensure StreamProvider subscribes before periodic emits (tests only).
        container
          ..listen<AsyncValue<FF1PlayerStatus>>(
            ff1PlayerStatusStreamProvider,
            (_, _) {},
          )
          ..read(nowDisplayingProvider);
        await Future<void>.delayed(const Duration(milliseconds: 400));

        final state = container.read(nowDisplayingProvider);
        expect(state, isA<NowDisplayingSuccess>());
        final object =
            (state as NowDisplayingSuccess).object as DP1NowDisplayingObject;
        expect(
          object.currentItem.id,
          'item_b',
          reason:
              'Later player status must win; first slow enrich must not '
              'overwrite state after a newer recompute',
        );
      },
    );

    test(
      'loads cache and enriches only items in window around current index',
      () async {
        const deviceId = 'device_1';
        const halfSize = 50;
        const currentIndex = 100;
        const totalItems = 200;
        const device = FF1Device(
          name: 'FF1',
          remoteId: 'r1',
          deviceId: deviceId,
          topicId: 'topic_1',
        );

        final items = List.generate(
          totalItems,
          (i) => DP1PlaylistItem(
            id: 'item_$i',
            duration: 60,
            title: 'Work $i',
          ),
        );

        final status = FF1PlayerStatus(
          playlistId: 'pl_1',
          currentWorkIndex: currentIndex,
          items: items,
        );

        final container = ProviderContainer.test(
          overrides: [
            databaseServiceProvider.overrideWith((ref) => recordingDb),
            indexerServiceProvider.overrideWithValue(
              FakeIndexerService(),
            ),
            activeFF1BluetoothDeviceProvider.overrideWithValue(
              const AsyncData(device),
            ),
            ff1WifiControlProvider.overrideWithValue(FakeWifiControl()),
            ff1PlayerStatusStreamProvider.overrideWith(
              (ref) => Stream.value(status),
            ),
            ff1CurrentPlayerStatusProvider.overrideWithValue(status),
            ff1ConnectionStatusStreamProvider.overrideWith(
              (ref) =>
                  Stream.value(const FF1ConnectionStatus(isConnected: true)),
            ),
            ff1DeviceConnectedProvider.overrideWithValue(true),
          ],
        );
        addTearDown(container.dispose);

        container.read(nowDisplayingProvider);
        await Future<void>.delayed(Duration.zero);

        final state = container.read(nowDisplayingProvider);
        expect(state, isA<NowDisplayingSuccess>());

        final success = state as NowDisplayingSuccess;
        final object = success.object as DP1NowDisplayingObject;

        expect(object.items.length, totalItems);
        expect(object.index, currentIndex);
        expect(object.currentItem.id, 'item_$currentIndex');

        final expectedStart = (currentIndex - halfSize).clamp(0, totalItems);
        final expectedEnd = (currentIndex + halfSize + 1).clamp(0, totalItems);
        final expectedWindowSize = expectedEnd - expectedStart;

        expect(
          recordingDb.getPlaylistItemsByIdsCalls,
          hasLength(1),
          reason: 'getPlaylistItemsByIds should be called once with window IDs',
        );
        final idsPassed = recordingDb.getPlaylistItemsByIdsCalls.single;
        expect(
          idsPassed.length,
          expectedWindowSize,
          reason: 'Only window IDs should be requested, not all $totalItems',
        );
        for (var i = 0; i < idsPassed.length; i++) {
          expect(idsPassed[i], 'item_${expectedStart + i}');
        }
      },
    );

    test('full list has correct length and currentItem is in window', () async {
      const totalItems = 10;
      const currentIndex = 3;
      const device = FF1Device(
        name: 'FF1',
        remoteId: 'r1',
        deviceId: 'device_1',
        topicId: 'topic_1',
      );

      final items = List.generate(
        totalItems,
        (i) => DP1PlaylistItem(
          id: 'item_$i',
          duration: 60,
          title: 'Title $i',
        ),
      );

      final status = FF1PlayerStatus(
        playlistId: 'pl_1',
        currentWorkIndex: currentIndex,
        items: items,
      );

      final container = ProviderContainer.test(
        overrides: [
          databaseServiceProvider.overrideWith((ref) => recordingDb),
          indexerServiceProvider.overrideWithValue(
            FakeIndexerService(),
          ),
          activeFF1BluetoothDeviceProvider.overrideWithValue(
            const AsyncData(device),
          ),
          ff1WifiControlProvider.overrideWithValue(FakeWifiControl()),
          ff1PlayerStatusStreamProvider.overrideWith(
            (ref) => Stream.value(status),
          ),
          ff1CurrentPlayerStatusProvider.overrideWithValue(status),
          ff1ConnectionStatusStreamProvider.overrideWith(
            (ref) => Stream.value(const FF1ConnectionStatus(isConnected: true)),
          ),
          ff1DeviceConnectedProvider.overrideWithValue(true),
        ],
      );
      addTearDown(container.dispose);

      container.read(nowDisplayingProvider);
      await Future<void>.delayed(Duration.zero);

      final state = container.read(nowDisplayingProvider);
      expect(state, isA<NowDisplayingSuccess>());

      final success = state as NowDisplayingSuccess;
      final object = success.object as DP1NowDisplayingObject;

      expect(object.items.length, status.items!.length);
      expect(object.currentItem.id, 'item_$currentIndex');
      expect(object.currentItem.title, 'Title $currentIndex');
    });

    test('fallback items without token are still saved to cache', () async {
      const deviceId = 'device_1';
      const device = FF1Device(
        name: 'FF1',
        remoteId: 'r1',
        deviceId: deviceId,
        topicId: 'topic_1',
      );

      // DP1 item with cid but NO token will be returned (fallback scenario)
      final dp1Item = DP1PlaylistItem(
        id: 'item_no_token',
        duration: 60,
        title: 'Work Without Token',
        provenance: DP1Provenance(
          type: DP1ProvenanceType.onChain,
          contract: DP1Contract(
            chain: DP1ProvenanceChain.evm,
            standard: DP1ProvenanceStandard.erc721,
            address: '0xabc',
            tokenId: '999',
          ),
        ),
      );

      final status = FF1PlayerStatus(
        playlistId: 'playlist_1',
        currentWorkIndex: 0,
        items: [dp1Item],
      );

      final container = ProviderContainer(
        overrides: [
          databaseServiceProvider.overrideWith((ref) => recordingDb),
          indexerServiceProvider.overrideWithValue(
            FakeIndexerService(), // Returns empty token list (no token found)
          ),
          activeFF1BluetoothDeviceProvider.overrideWithValue(
            const AsyncData(device),
          ),
          ff1WifiControlProvider.overrideWithValue(FakeWifiControl()),
          ff1PlayerStatusStreamProvider.overrideWith(
            (ref) => Stream.value(status),
          ),
          ff1CurrentPlayerStatusProvider.overrideWithValue(status),
          ff1ConnectionStatusStreamProvider.overrideWith(
            (ref) => Stream.value(const FF1ConnectionStatus(isConnected: true)),
          ),
          ff1DeviceConnectedProvider.overrideWithValue(true),
        ],
      );
      addTearDown(container.dispose);

      container.read(nowDisplayingProvider);
      await Future<void>.delayed(Duration.zero);

      // Verify enrichment was attempted and item saved (even without token)
      expect(recordingDb.savedEnriched, isNotNull);
      expect(recordingDb.savedEnriched!.length, 1);
      expect(recordingDb.savedEnriched!.first.id, 'item_no_token');
      // Without token, no thumbnail
      expect(recordingDb.savedEnriched!.first.thumbnailUrl, isNull);
    });
  });
}

/// Delays only the first [getManualTokens] call so a later recompute can finish
/// first (used to test stale-result discard in [NowDisplayingNotifier]).
class _FirstCallSlowIndexer extends FakeIndexerService {
  _FirstCallSlowIndexer({
    required this.delay,
    super.tokensByCid,
  });

  final Duration delay;
  int _calls = 0;

  @override
  Future<List<AssetToken>> getManualTokens({
    List<int>? tokenIds,
    List<String>? owners,
    List<String>? tokenCids,
    int? limit,
    int? offset,
  }) async {
    _calls++;
    if (_calls == 1) {
      await Future<void>.delayed(delay);
    }
    return super.getManualTokens(
      tokenIds: tokenIds,
      owners: owners,
      tokenCids: tokenCids,
      limit: limit,
      offset: offset,
    );
  }
}

/// DatabaseService that returns no cached items and records
/// upsertPlaylistItemsEnriched and getPlaylistItemsByIds arguments for tests.
class _RecordingDatabaseService extends DatabaseService {
  _RecordingDatabaseService(
    AppDatabase db, {
    this.cacheDelay = Duration.zero,
    this.cachedItemsById = const {},
  }) : super(db);

  /// When non-zero, delays cache response (simulates slow getPlaylistItemsByIds).
  final Duration cacheDelay;

  final Map<String, PlaylistItem> cachedItemsById;

  final enrichmentDone = Completer<void>();

  List<PlaylistItem>? savedEnriched;

  final List<List<String>> getPlaylistItemsByIdsCalls = [];

  @override
  Future<List<PlaylistItem>> getPlaylistItemsByIds(List<String> ids) async {
    getPlaylistItemsByIdsCalls.add(List<String>.from(ids));
    if (cacheDelay > Duration.zero) {
      await Future<void>.delayed(cacheDelay);
    }
    return [
      for (final id in ids)
        if (cachedItemsById.containsKey(id)) cachedItemsById[id]!,
    ];
  }

  @override
  Future<void> upsertPlaylistItemsEnriched(
    List<PlaylistItem> items, {
    bool shouldForce = true,
  }) async {
    savedEnriched = List<PlaylistItem>.from(items);
    if (!enrichmentDone.isCompleted) {
      enrichmentDone.complete();
    }
  }
}
