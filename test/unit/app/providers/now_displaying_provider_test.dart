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
          // Ensure cache is ready (empty) when _computeForDevice runs so missing = [dp1Item]
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
  });
}

/// DatabaseService that returns no cached items and records upsertPlaylistItemsEnriched
/// and getPlaylistItemsByIds arguments for tests.
class _RecordingDatabaseService extends DatabaseService {
  _RecordingDatabaseService(super.db);

  final enrichmentDone = Completer<void>();

  List<PlaylistItem>? savedEnriched;

  final List<List<String>> getPlaylistItemsByIdsCalls = [];

  @override
  Future<List<PlaylistItem>> getPlaylistItemsByIds(List<String> ids) async {
    getPlaylistItemsByIdsCalls.add(List<String>.from(ids));
    return [];
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
