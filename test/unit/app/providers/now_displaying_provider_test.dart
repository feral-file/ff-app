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

// Shared override used by stream-driven tests that bypass FF1WifiControl.
// ignore: specify_nonobvious_property_types
final streamBackedCurrentPlayerStatusOverride = ff1CurrentPlayerStatusProvider
    .overrideWith((ref) {
      final async = ref.watch(ff1PlayerStatusStreamProvider);
      return async.when(
        data: (status) => status,
        loading: () => null,
        error: (_, _) => null,
      );
    });

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
      'shows loading until async window cache read completes',
      () async {
        const device = FF1Device(
          name: 'FF1',
          remoteId: 'r1',
          deviceId: 'device_1',
          topicId: 'topic_1',
        );

        const dp1Item = DP1PlaylistItem(
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
              (ref) =>
                  Stream.value(const FF1ConnectionStatus(isConnected: true)),
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
          isA<LoadingNowDisplaying>(),
          reason:
              '_recompute sets Loading before _computeStatus; '
              '_computeForDevice awaits the DB window read before state = '
              'success',
        );

        await Future<void>.delayed(const Duration(milliseconds: 120));
        expect(
          container.read(nowDisplayingProvider),
          isA<NowDisplayingSuccess>(),
        );
      },
    );

    test('initial no-device state does not flash loading', () async {
      final container = ProviderContainer.test(
        overrides: [
          databaseServiceProvider.overrideWith((ref) => recordingDb),
          indexerServiceProvider.overrideWithValue(FakeIndexerService()),
          activeFF1BluetoothDeviceProvider.overrideWithValue(
            const AsyncData(null),
          ),
          ff1WifiControlProvider.overrideWithValue(FakeWifiControl()),
        ],
      );
      addTearDown(container.dispose);

      final emitted = <NowDisplayingStatus>[];
      final subscription = container.listen<NowDisplayingStatus>(
        nowDisplayingProvider,
        (_, next) => emitted.add(next),
      );
      addTearDown(subscription.close);

      container.read(nowDisplayingProvider);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(emitted.whereType<LoadingNowDisplaying>(), isEmpty);
      expect(container.read(nowDisplayingProvider), isA<NoDevicePaired>());
    });

    test('initial disconnected device state does not flash loading', () async {
      const device = FF1Device(
        name: 'FF1',
        remoteId: 'r1',
        deviceId: 'device_1',
        topicId: 'topic_1',
      );

      final container = ProviderContainer.test(
        overrides: [
          databaseServiceProvider.overrideWith((ref) => recordingDb),
          indexerServiceProvider.overrideWithValue(FakeIndexerService()),
          activeFF1BluetoothDeviceProvider.overrideWithValue(
            const AsyncData(device),
          ),
          ff1WifiControlProvider.overrideWithValue(FakeWifiControl()),
          ff1ConnectionStatusStreamProvider.overrideWith(
            (ref) =>
                Stream.value(const FF1ConnectionStatus(isConnected: false)),
          ),
          ff1DeviceConnectedProvider.overrideWithValue(false),
        ],
      );
      addTearDown(container.dispose);

      final emitted = <NowDisplayingStatus>[];
      final subscription = container.listen<NowDisplayingStatus>(
        nowDisplayingProvider,
        (_, next) => emitted.add(next),
      );
      addTearDown(subscription.close);

      container.read(nowDisplayingProvider);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(emitted.whereType<LoadingNowDisplaying>(), isEmpty);
      expect(
        container.read(nowDisplayingProvider),
        isA<DeviceDisconnected>(),
      );
    });

    test(
      'same playlist and item ids only index change skips extra DB cache read',
      () async {
        const device = FF1Device(
          name: 'FF1',
          remoteId: 'r1',
          deviceId: 'device_1',
          topicId: 'topic_1',
        );

        final dp1Items = [
          const DP1PlaylistItem(id: 'item_0', duration: 60, title: 'A'),
          const DP1PlaylistItem(id: 'item_1', duration: 60, title: 'B'),
        ];

        final statusIndex0 = FF1PlayerStatus(
          playlistId: 'pl_1',
          currentWorkIndex: 0,
          items: dp1Items,
        );
        final statusIndex1 = FF1PlayerStatus(
          playlistId: 'pl_1',
          currentWorkIndex: 1,
          items: dp1Items,
        );

        final playerStatusController = StreamController<FF1PlayerStatus>(
          sync: true,
        );
        addTearDown(playerStatusController.close);

        final container = ProviderContainer.test(
          overrides: [
            databaseServiceProvider.overrideWith((ref) => recordingDb),
            indexerServiceProvider.overrideWithValue(FakeIndexerService()),
            activeFF1BluetoothDeviceProvider.overrideWithValue(
              const AsyncData(device),
            ),
            ff1WifiControlProvider.overrideWithValue(FakeWifiControl()),
            ff1PlayerStatusStreamProvider.overrideWith(
              (ref) => playerStatusController.stream,
            ),
            streamBackedCurrentPlayerStatusOverride,
            ff1ConnectionStatusStreamProvider.overrideWith(
              (ref) =>
                  Stream.value(const FF1ConnectionStatus(isConnected: true)),
            ),
            ff1DeviceConnectedProvider.overrideWithValue(true),
          ],
        );
        addTearDown(container.dispose);

        container
          ..listen<AsyncValue<FF1PlayerStatus>>(
            ff1PlayerStatusStreamProvider,
            (_, _) {},
          )
          ..read(nowDisplayingProvider);

        await Future<void>.delayed(Duration.zero);
        playerStatusController.add(statusIndex0);
        await Future<void>.delayed(const Duration(milliseconds: 120));
        final callsAfterFirstPlayerAndCache =
            recordingDb.getPlaylistItemsByIdsCalls.length;

        playerStatusController.add(statusIndex1);
        await Future<void>.delayed(const Duration(milliseconds: 80));

        expect(
          recordingDb.getPlaylistItemsByIdsCalls.length,
          callsAfterFirstPlayerAndCache,
          reason:
              'Index-only player update should fast-path (no extra '
              'getPlaylistItemsByIds)',
        );
        final state = container.read(nowDisplayingProvider);
        expect(state, isA<NowDisplayingSuccess>());
        final object =
            (state as NowDisplayingSuccess).object as DP1NowDisplayingObject;
        expect(object.index, 1);
        expect(object.currentItem.id, 'item_1');
      },
    );

    test(
      'transient null after fast-path index update preserves latest index',
      () async {
        const device = FF1Device(
          name: 'FF1',
          remoteId: 'r1',
          deviceId: 'device_1',
          topicId: 'topic_1',
        );

        final dp1Items = [
          const DP1PlaylistItem(id: 'item_0', duration: 60, title: 'A'),
          const DP1PlaylistItem(id: 'item_1', duration: 60, title: 'B'),
        ];

        final statusIndex0 = FF1PlayerStatus(
          playlistId: 'pl_1',
          currentWorkIndex: 0,
          items: dp1Items,
        );
        final statusIndex1 = FF1PlayerStatus(
          playlistId: 'pl_1',
          currentWorkIndex: 1,
          items: dp1Items,
        );

        final playerStatusController = StreamController<FF1PlayerStatus>(
          sync: true,
        );
        addTearDown(playerStatusController.close);

        final container = ProviderContainer.test(
          overrides: [
            databaseServiceProvider.overrideWith((ref) => recordingDb),
            indexerServiceProvider.overrideWithValue(FakeIndexerService()),
            activeFF1BluetoothDeviceProvider.overrideWithValue(
              const AsyncData(device),
            ),
            ff1WifiControlProvider.overrideWithValue(FakeWifiControl()),
            ff1PlayerStatusStreamProvider.overrideWith(
              (ref) => playerStatusController.stream,
            ),
            streamBackedCurrentPlayerStatusOverride,
            ff1ConnectionStatusStreamProvider.overrideWith(
              (ref) =>
                  Stream.value(const FF1ConnectionStatus(isConnected: true)),
            ),
            ff1DeviceConnectedProvider.overrideWithValue(true),
          ],
        );
        addTearDown(container.dispose);

        container
          ..listen<AsyncValue<FF1PlayerStatus>>(
            ff1PlayerStatusStreamProvider,
            (_, _) {},
          )
          ..read(nowDisplayingProvider);

        await Future<void>.delayed(Duration.zero);
        playerStatusController.add(statusIndex0);
        await Future<void>.delayed(const Duration(milliseconds: 120));

        final state0 = container.read(nowDisplayingProvider);
        expect(state0, isA<NowDisplayingSuccess>());
        final object0 =
            (state0 as NowDisplayingSuccess).object as DP1NowDisplayingObject;
        expect(object0.index, 0);

        playerStatusController.add(statusIndex1);
        await Future<void>.delayed(const Duration(milliseconds: 80));

        final state1 = container.read(nowDisplayingProvider);
        expect(state1, isA<NowDisplayingSuccess>());
        final object1 =
            (state1 as NowDisplayingSuccess).object as DP1NowDisplayingObject;
        expect(object1.index, 1);

        // Simulate a reconnect/resubscribe blip: stream error maps to null
        // player status. The provider should keep the latest index from the
        // fast-path update.
        playerStatusController.addError(StateError('transient reconnect'));
        await Future<void>.delayed(const Duration(milliseconds: 80));

        final stateAfterNull = container.read(nowDisplayingProvider);
        expect(stateAfterNull, isA<NowDisplayingSuccess>());
        final objectAfterNull =
            (stateAfterNull as NowDisplayingSuccess).object
                as DP1NowDisplayingObject;
        expect(objectAfterNull.index, 1);
      },
    );

    test(
      'reconnect round-trip with same playlist does not flash loading',
      () async {
        const device = FF1Device(
          name: 'FF1',
          remoteId: 'r1',
          deviceId: 'device_1',
          topicId: 'topic_1',
        );

        final status = FF1PlayerStatus(
          playlistId: 'pl_1',
          currentWorkIndex: 0,
          items: const [
            DP1PlaylistItem(id: 'item_0', duration: 60, title: 'A'),
          ],
        );

        final playerStatusController = StreamController<FF1PlayerStatus>(
          sync: true,
        );
        final connectionStatusController =
            StreamController<FF1ConnectionStatus>(sync: true);
        addTearDown(playerStatusController.close);
        addTearDown(connectionStatusController.close);

        final container = ProviderContainer.test(
          overrides: [
            databaseServiceProvider.overrideWith((ref) => recordingDb),
            indexerServiceProvider.overrideWithValue(FakeIndexerService()),
            activeFF1BluetoothDeviceProvider.overrideWithValue(
              const AsyncData(device),
            ),
            ff1WifiControlProvider.overrideWithValue(FakeWifiControl()),
            ff1PlayerStatusStreamProvider.overrideWith(
              (ref) => playerStatusController.stream,
            ),
            streamBackedCurrentPlayerStatusOverride,
            ff1ConnectionStatusStreamProvider.overrideWith(
              (ref) => connectionStatusController.stream,
            ),
          ],
        );
        addTearDown(container.dispose);

        final emitted = <NowDisplayingStatus>[];
        final subscription = container.listen<NowDisplayingStatus>(
          nowDisplayingProvider,
          (_, next) => emitted.add(next),
        );
        addTearDown(subscription.close);

        container
          ..listen<AsyncValue<FF1PlayerStatus>>(
            ff1PlayerStatusStreamProvider,
            (_, _) {},
          )
          ..listen<AsyncValue<FF1ConnectionStatus>>(
            ff1ConnectionStatusStreamProvider,
            (_, _) {},
          )
          ..read(nowDisplayingProvider);

        await Future<void>.delayed(Duration.zero);
        connectionStatusController.add(
          const FF1ConnectionStatus(isConnected: true),
        );
        playerStatusController.add(status);
        await Future<void>.delayed(const Duration(milliseconds: 120));

        emitted.clear();

        connectionStatusController.add(
          const FF1ConnectionStatus(isConnected: false),
        );
        await Future<void>.delayed(const Duration(milliseconds: 80));
        connectionStatusController.add(
          const FF1ConnectionStatus(isConnected: true),
        );
        await Future<void>.delayed(const Duration(milliseconds: 80));

        expect(emitted.whereType<LoadingNowDisplaying>(), isEmpty);
        expect(emitted.whereType<DeviceDisconnected>(), isNotEmpty);
        expect(
          container.read(nowDisplayingProvider),
          isA<NowDisplayingSuccess>(),
        );
      },
    );

    test(
      'active device switch does not reuse stale success snapshot',
      () async {
        const deviceA = FF1Device(
          name: 'FF1-A',
          remoteId: 'r1',
          deviceId: 'device_a',
          topicId: 'topic_a',
        );
        const deviceB = FF1Device(
          name: 'FF1-B',
          remoteId: 'r2',
          deviceId: 'device_b',
          topicId: 'topic_b',
        );

        final statusA = FF1PlayerStatus(
          playlistId: 'pl_a',
          currentWorkIndex: 0,
          items: const [
            DP1PlaylistItem(id: 'item_a0', duration: 60, title: 'A'),
          ],
        );

        final activeDeviceController = StreamController<FF1Device?>(
          sync: true,
        );
        addTearDown(activeDeviceController.close);
        final wifiControl = FakeWifiControl();

        final container = ProviderContainer.test(
          overrides: [
            databaseServiceProvider.overrideWith((ref) => recordingDb),
            indexerServiceProvider.overrideWithValue(FakeIndexerService()),
            activeFF1BluetoothDeviceProvider.overrideWith(
              (ref) => activeDeviceController.stream,
            ),
            ff1WifiControlProvider.overrideWithValue(wifiControl),
          ],
        );
        addTearDown(container.dispose);

        container
          ..listen<AsyncValue<FF1Device?>>(
            activeFF1BluetoothDeviceProvider,
            (_, _) {},
          )
          ..listen<AsyncValue<FF1PlayerStatus>>(
            ff1PlayerStatusStreamProvider,
            (_, _) {},
          )
          ..listen<AsyncValue<FF1ConnectionStatus>>(
            ff1ConnectionStatusStreamProvider,
            (_, _) {},
          )
          ..read(nowDisplayingProvider);

        await Future<void>.delayed(Duration.zero);
        activeDeviceController.add(deviceA);
        await container
            .read(ff1WifiConnectionProvider.notifier)
            .connect(
              device: deviceA,
              userId: 'user-a',
              apiKey: 'key-a',
            );
        wifiControl
          ..emitConnectionStatus(isConnected: true)
          ..emitPlayerStatus(statusA);
        await Future<void>.delayed(const Duration(milliseconds: 120));

        expect(
          container.read(nowDisplayingProvider),
          isA<NowDisplayingSuccess>(),
        );

        activeDeviceController.add(deviceB);
        await container
            .read(ff1WifiConnectionProvider.notifier)
            .connect(
              device: deviceB,
              userId: 'user-b',
              apiKey: 'key-b',
            );
        wifiControl.emitConnectionStatus(isConnected: true);
        await Future<void>.delayed(const Duration(milliseconds: 80));

        expect(
          container
              .read(ff1PlayerStatusStreamProvider)
              .asData
              ?.value
              .playlistId,
          statusA.playlistId,
        );
        expect(container.read(ff1CurrentPlayerStatusProvider), isNull);

        final state = container.read(nowDisplayingProvider);
        expect(state, isA<LoadingNowDisplaying>());
        expect(
          (state as LoadingNowDisplaying).device?.deviceId,
          deviceB.deviceId,
        );
      },
    );

    test(
      'same playlist identity but index shifts visible window triggers extra '
      'DB read',
      () async {
        const device = FF1Device(
          name: 'FF1',
          remoteId: 'r1',
          deviceId: 'device_1',
          topicId: 'topic_1',
        );

        const n = 200;
        final dp1Items = List<DP1PlaylistItem>.generate(
          n,
          (i) => DP1PlaylistItem(
            id: 'item_$i',
            duration: 60,
            title: 'T$i',
          ),
        );

        final statusIndex0 = FF1PlayerStatus(
          playlistId: 'pl_1',
          currentWorkIndex: 0,
          items: dp1Items,
        );
        final statusIndex100 = FF1PlayerStatus(
          playlistId: 'pl_1',
          currentWorkIndex: 100,
          items: dp1Items,
        );

        final playerStatusController = StreamController<FF1PlayerStatus>(
          sync: true,
        );
        addTearDown(playerStatusController.close);

        final container = ProviderContainer.test(
          overrides: [
            databaseServiceProvider.overrideWith((ref) => recordingDb),
            indexerServiceProvider.overrideWithValue(FakeIndexerService()),
            activeFF1BluetoothDeviceProvider.overrideWithValue(
              const AsyncData(device),
            ),
            ff1WifiControlProvider.overrideWithValue(FakeWifiControl()),
            ff1PlayerStatusStreamProvider.overrideWith(
              (ref) => playerStatusController.stream,
            ),
            streamBackedCurrentPlayerStatusOverride,
            ff1ConnectionStatusStreamProvider.overrideWith(
              (ref) =>
                  Stream.value(const FF1ConnectionStatus(isConnected: true)),
            ),
            ff1DeviceConnectedProvider.overrideWithValue(true),
          ],
        );
        addTearDown(container.dispose);

        container
          ..listen<AsyncValue<FF1PlayerStatus>>(
            ff1PlayerStatusStreamProvider,
            (_, _) {},
          )
          ..read(nowDisplayingProvider);

        await Future<void>.delayed(Duration.zero);
        playerStatusController.add(statusIndex0);
        await Future<void>.delayed(const Duration(milliseconds: 150));
        final callsAfterFirstWindow =
            recordingDb.getPlaylistItemsByIdsCalls.length;
        expect(callsAfterFirstWindow, greaterThanOrEqualTo(1));

        playerStatusController.add(statusIndex100);
        await Future<void>.delayed(const Duration(milliseconds: 150));

        expect(
          recordingDb.getPlaylistItemsByIdsCalls.length,
          greaterThan(callsAfterFirstWindow),
          reason:
              'When currentWorkIndex moves the visible window, cache/enrich '
              'must run for the new slice (no fast-path)',
        );
      },
    );

    test(
      'same playlist window shift updates current item '
      'before slow cache completes',
      () async {
        const device = FF1Device(
          name: 'FF1',
          remoteId: 'r1',
          deviceId: 'device_1',
          topicId: 'topic_1',
        );

        const n = 200;
        final dp1Items = List<DP1PlaylistItem>.generate(
          n,
          (i) => DP1PlaylistItem(
            id: 'item_$i',
            duration: 60,
            title: 'T$i',
          ),
        );

        final statusIndex0 = FF1PlayerStatus(
          playlistId: 'pl_1',
          currentWorkIndex: 0,
          items: dp1Items,
        );
        final statusIndex100 = FF1PlayerStatus(
          playlistId: 'pl_1',
          currentWorkIndex: 100,
          items: dp1Items,
        );

        final playerStatusController = StreamController<FF1PlayerStatus>(
          sync: true,
        );
        addTearDown(playerStatusController.close);

        final slowDb = _RecordingDatabaseService(
          db,
          cacheDelay: const Duration(milliseconds: 250),
        );

        final container = ProviderContainer.test(
          overrides: [
            databaseServiceProvider.overrideWith((ref) => slowDb),
            indexerServiceProvider.overrideWithValue(FakeIndexerService()),
            activeFF1BluetoothDeviceProvider.overrideWithValue(
              const AsyncData(device),
            ),
            ff1WifiControlProvider.overrideWithValue(FakeWifiControl()),
            ff1PlayerStatusStreamProvider.overrideWith(
              (ref) => playerStatusController.stream,
            ),
            streamBackedCurrentPlayerStatusOverride,
            ff1ConnectionStatusStreamProvider.overrideWith(
              (ref) =>
                  Stream.value(const FF1ConnectionStatus(isConnected: true)),
            ),
            ff1DeviceConnectedProvider.overrideWithValue(true),
          ],
        );
        addTearDown(container.dispose);

        final emitted = <NowDisplayingStatus>[];
        final subscription = container.listen<NowDisplayingStatus>(
          nowDisplayingProvider,
          (_, next) => emitted.add(next),
        );
        addTearDown(subscription.close);

        container
          ..listen<AsyncValue<FF1PlayerStatus>>(
            ff1PlayerStatusStreamProvider,
            (_, _) {},
          )
          ..read(nowDisplayingProvider);

        await Future<void>.delayed(Duration.zero);
        playerStatusController.add(statusIndex0);
        await Future<void>.delayed(const Duration(milliseconds: 300));

        emitted.clear();
        final callsAfterFirstWindow = slowDb.getPlaylistItemsByIdsCalls.length;

        playerStatusController.add(statusIndex100);
        await Future<void>.delayed(const Duration(milliseconds: 40));

        final stateWhileSlow = container.read(nowDisplayingProvider);
        expect(stateWhileSlow, isA<NowDisplayingSuccess>());
        final objectWhileSlow =
            (stateWhileSlow as NowDisplayingSuccess).object
                as DP1NowDisplayingObject;
        expect(objectWhileSlow.currentItem.id, 'item_100');
        expect(emitted.whereType<LoadingNowDisplaying>(), isEmpty);
        expect(
          slowDb.getPlaylistItemsByIdsCalls.length,
          greaterThan(callsAfterFirstWindow),
        );

        await Future<void>.delayed(const Duration(milliseconds: 260));
        final finalState = container.read(nowDisplayingProvider);
        expect(finalState, isA<NowDisplayingSuccess>());
        final finalObject =
            (finalState as NowDisplayingSuccess).object
                as DP1NowDisplayingObject;
        expect(finalObject.currentItem.id, 'item_100');
      },
    );

    test(
      'newer same playlist window shift preempts older slow cache pass',
      () async {
        const device = FF1Device(
          name: 'FF1',
          remoteId: 'r1',
          deviceId: 'device_1',
          topicId: 'topic_1',
        );

        const n = 200;
        final dp1Items = List<DP1PlaylistItem>.generate(
          n,
          (i) => DP1PlaylistItem(
            id: 'item_$i',
            duration: 60,
            title: 'T$i',
          ),
        );

        final statusIndex100 = FF1PlayerStatus(
          playlistId: 'pl_1',
          currentWorkIndex: 100,
          items: dp1Items,
        );
        final statusIndex150 = FF1PlayerStatus(
          playlistId: 'pl_1',
          currentWorkIndex: 150,
          items: dp1Items,
        );
        final statusIndex175 = FF1PlayerStatus(
          playlistId: 'pl_1',
          currentWorkIndex: 175,
          items: dp1Items,
        );

        final playerStatusController = StreamController<FF1PlayerStatus>(
          sync: true,
        );
        addTearDown(playerStatusController.close);

        final slowDb = _RecordingDatabaseService(
          db,
          cacheDelay: const Duration(milliseconds: 250),
        );

        final container = ProviderContainer.test(
          overrides: [
            databaseServiceProvider.overrideWith((ref) => slowDb),
            indexerServiceProvider.overrideWithValue(FakeIndexerService()),
            activeFF1BluetoothDeviceProvider.overrideWithValue(
              const AsyncData(device),
            ),
            ff1WifiControlProvider.overrideWithValue(FakeWifiControl()),
            ff1PlayerStatusStreamProvider.overrideWith(
              (ref) => playerStatusController.stream,
            ),
            streamBackedCurrentPlayerStatusOverride,
            ff1ConnectionStatusStreamProvider.overrideWith(
              (ref) =>
                  Stream.value(const FF1ConnectionStatus(isConnected: true)),
            ),
            ff1DeviceConnectedProvider.overrideWithValue(true),
          ],
        );
        addTearDown(container.dispose);

        final emitted = <NowDisplayingStatus>[];
        final subscription = container.listen<NowDisplayingStatus>(
          nowDisplayingProvider,
          (_, next) => emitted.add(next),
        );
        addTearDown(subscription.close);

        container
          ..listen<AsyncValue<FF1PlayerStatus>>(
            ff1PlayerStatusStreamProvider,
            (_, _) {},
          )
          ..read(nowDisplayingProvider);

        await Future<void>.delayed(Duration.zero);
        playerStatusController.add(statusIndex100);
        await Future<void>.delayed(const Duration(milliseconds: 300));

        emitted.clear();
        playerStatusController.add(statusIndex150);
        await Future<void>.delayed(const Duration(milliseconds: 40));
        expect(
          (container.read(nowDisplayingProvider) as NowDisplayingSuccess).object
              as DP1NowDisplayingObject,
          isNotNull,
        );
        expect(
          ((container.read(nowDisplayingProvider) as NowDisplayingSuccess)
                      .object
                  as DP1NowDisplayingObject)
              .currentItem
              .id,
          'item_150',
        );

        playerStatusController.add(statusIndex175);
        await Future<void>.delayed(const Duration(milliseconds: 40));

        final stateWhilePreempting = container.read(nowDisplayingProvider);
        expect(stateWhilePreempting, isA<NowDisplayingSuccess>());
        final objectWhilePreempting =
            (stateWhilePreempting as NowDisplayingSuccess).object
                as DP1NowDisplayingObject;
        expect(
          objectWhilePreempting,
          isNotNull,
        );
        expect(
          objectWhilePreempting.currentItem.id,
          'item_175',
          reason:
              'The newer same-playlist update must publish immediately, '
              'without waiting for the older slow cache pass to complete',
        );
        expect(emitted.whereType<LoadingNowDisplaying>(), isEmpty);

        await Future<void>.delayed(const Duration(milliseconds: 260));
        final finalState = container.read(nowDisplayingProvider);
        expect(finalState, isA<NowDisplayingSuccess>());
        expect(
          ((finalState as NowDisplayingSuccess).object
                  as DP1NowDisplayingObject)
              .currentItem
              .id,
          'item_175',
        );
      },
    );

    test(
      'same playlist window shift survives transient null while cache is slow',
      () async {
        const device = FF1Device(
          name: 'FF1',
          remoteId: 'r1',
          deviceId: 'device_1',
          topicId: 'topic_1',
        );

        const n = 200;
        final dp1Items = List<DP1PlaylistItem>.generate(
          n,
          (i) => DP1PlaylistItem(
            id: 'item_$i',
            duration: 60,
            title: 'T$i',
          ),
        );
        final token150 = AssetToken(
          id: 150,
          cid: 'eip155:1:erc721:0xabc:150',
          chain: 'eip155:1',
          standard: 'ERC-721',
          contractAddress: '0xabc',
          tokenNumber: '150',
          display: TokenMetadata(
            name: 'Enriched 150',
            imageUrl: 'https://example.com/150.jpg',
          ),
        );
        dp1Items[150] = DP1PlaylistItem(
          id: 'item_150',
          duration: 60,
          title: 'T150',
          provenance: DP1Provenance(
            type: DP1ProvenanceType.onChain,
            contract: DP1Contract(
              chain: DP1ProvenanceChain.evm,
              standard: DP1ProvenanceStandard.erc721,
              address: '0xabc',
              tokenId: '150',
            ),
          ),
        );
        final indexer = FakeIndexerService(tokensByCid: [token150]);

        final statusIndex100 = FF1PlayerStatus(
          playlistId: 'pl_1',
          currentWorkIndex: 100,
          items: dp1Items,
        );
        final statusIndex150 = FF1PlayerStatus(
          playlistId: 'pl_1',
          currentWorkIndex: 150,
          items: dp1Items,
        );

        final playerStatusController = StreamController<FF1PlayerStatus>(
          sync: true,
        );
        addTearDown(playerStatusController.close);

        final slowDb = _RecordingDatabaseService(
          db,
          cacheDelay: const Duration(milliseconds: 250),
        );

        final container = ProviderContainer.test(
          overrides: [
            databaseServiceProvider.overrideWith((ref) => slowDb),
            indexerServiceProvider.overrideWithValue(indexer),
            activeFF1BluetoothDeviceProvider.overrideWithValue(
              const AsyncData(device),
            ),
            ff1WifiControlProvider.overrideWithValue(FakeWifiControl()),
            ff1PlayerStatusStreamProvider.overrideWith(
              (ref) => playerStatusController.stream,
            ),
            streamBackedCurrentPlayerStatusOverride,
            ff1ConnectionStatusStreamProvider.overrideWith(
              (ref) =>
                  Stream.value(const FF1ConnectionStatus(isConnected: true)),
            ),
            ff1DeviceConnectedProvider.overrideWithValue(true),
          ],
        );
        addTearDown(container.dispose);

        final emitted = <NowDisplayingStatus>[];
        final subscription = container.listen<NowDisplayingStatus>(
          nowDisplayingProvider,
          (_, next) => emitted.add(next),
        );
        addTearDown(subscription.close);

        container
          ..listen<AsyncValue<FF1PlayerStatus>>(
            ff1PlayerStatusStreamProvider,
            (_, _) {},
          )
          ..read(nowDisplayingProvider);

        await Future<void>.delayed(Duration.zero);
        playerStatusController.add(statusIndex100);
        await Future<void>.delayed(const Duration(milliseconds: 300));

        emitted.clear();
        playerStatusController.add(statusIndex150);
        await Future<void>.delayed(const Duration(milliseconds: 40));

        final stateDuringShift = container.read(nowDisplayingProvider);
        expect(stateDuringShift, isA<NowDisplayingSuccess>());
        final objectDuringShift =
            (stateDuringShift as NowDisplayingSuccess).object
                as DP1NowDisplayingObject;
        expect(
          objectDuringShift.currentItem.id,
          'item_150',
        );

        playerStatusController.addError(StateError('transient reconnect'));
        await Future<void>.delayed(const Duration(milliseconds: 40));

        final stateAfterNull = container.read(nowDisplayingProvider);
        expect(stateAfterNull, isA<NowDisplayingSuccess>());
        final objectAfterNull =
            (stateAfterNull as NowDisplayingSuccess).object
                as DP1NowDisplayingObject;
        expect(
          objectAfterNull.currentItem.id,
          'item_150',
          reason:
              'Transient null must keep the just-published fallback window '
              'instead of rewinding to the older success snapshot',
        );
        expect(emitted.whereType<LoadingNowDisplaying>(), isEmpty);
        expect(
          slowDb.getPlaylistItemsByIdsCalls,
          isNotEmpty,
          reason:
              'The window cache read should still run for the shifted slice',
        );
        expect(
          indexer.lastTokenCids,
          isNotNull,
          reason:
              'The shifted window should request the token CID for the '
              'enriched item',
        );
        expect(
          indexer.lastTokenCids,
          contains('eip155:1:erc721:0xabc:150'),
        );
        await slowDb.enrichmentDone.future.timeout(
          const Duration(seconds: 5),
          onTimeout: () => throw TimeoutException(
            'Enrichment did not finish after the transient null gap; '
            'savedEnriched=${slowDb.savedEnriched}',
          ),
        );
        expect(slowDb.savedEnriched, isNotNull);
        expect(
          slowDb.savedEnriched!.any(
            (item) =>
                item.id == 'item_150' &&
                item.thumbnailUrl == 'https://example.com/150.jpg',
          ),
          isTrue,
          reason:
              'The background enrichment pass should still complete and '
              'persist the token-backed thumbnail even if the stream briefly '
              'goes null',
        );
      },
    );

    test(
      'pause toggle with same playlist identity skips extra DB cache read',
      () async {
        const device = FF1Device(
          name: 'FF1',
          remoteId: 'r1',
          deviceId: 'device_1',
          topicId: 'topic_1',
        );

        const dp1Item = DP1PlaylistItem(
          id: 'item_0',
          duration: 60,
          title: 'A',
        );

        final statusPlaying = FF1PlayerStatus(
          playlistId: 'pl_1',
          currentWorkIndex: 0,
          items: [dp1Item],
          isPaused: false,
        );
        final statusPaused = FF1PlayerStatus(
          playlistId: 'pl_1',
          currentWorkIndex: 0,
          items: [dp1Item],
          isPaused: true,
        );

        final playerStatusController = StreamController<FF1PlayerStatus>(
          sync: true,
        );
        addTearDown(playerStatusController.close);

        final container = ProviderContainer.test(
          overrides: [
            databaseServiceProvider.overrideWith((ref) => recordingDb),
            indexerServiceProvider.overrideWithValue(FakeIndexerService()),
            activeFF1BluetoothDeviceProvider.overrideWithValue(
              const AsyncData(device),
            ),
            ff1WifiControlProvider.overrideWithValue(FakeWifiControl()),
            ff1PlayerStatusStreamProvider.overrideWith(
              (ref) => playerStatusController.stream,
            ),
            streamBackedCurrentPlayerStatusOverride,
            ff1ConnectionStatusStreamProvider.overrideWith(
              (ref) =>
                  Stream.value(const FF1ConnectionStatus(isConnected: true)),
            ),
            ff1DeviceConnectedProvider.overrideWithValue(true),
          ],
        );
        addTearDown(container.dispose);

        container
          ..listen<AsyncValue<FF1PlayerStatus>>(
            ff1PlayerStatusStreamProvider,
            (_, _) {},
          )
          ..read(nowDisplayingProvider);

        await Future<void>.delayed(Duration.zero);
        playerStatusController.add(statusPlaying);
        await Future<void>.delayed(const Duration(milliseconds: 120));
        final callsAfterFirstPlayerAndCache =
            recordingDb.getPlaylistItemsByIdsCalls.length;

        playerStatusController.add(statusPaused);
        await Future<void>.delayed(const Duration(milliseconds: 80));

        expect(
          recordingDb.getPlaylistItemsByIdsCalls.length,
          callsAfterFirstPlayerAndCache,
          reason:
              'Pause-only update should fast-path (no extra '
              'getPlaylistItemsByIds)',
        );
      },
    );

    test(
      'expanded scroll range with same playlist identity triggers full DB '
      'window read',
      () async {
        const device = FF1Device(
          name: 'FF1',
          remoteId: 'r1',
          deviceId: 'device_1',
          topicId: 'topic_1',
        );

        const n = 200;
        final dp1Items = List<DP1PlaylistItem>.generate(
          n,
          (i) => DP1PlaylistItem(
            id: 'item_$i',
            duration: 60,
            title: 'T$i',
          ),
        );

        final status = FF1PlayerStatus(
          playlistId: 'pl_1',
          currentWorkIndex: 100,
          items: dp1Items,
        );

        final container = ProviderContainer.test(
          overrides: [
            databaseServiceProvider.overrideWith((ref) => recordingDb),
            indexerServiceProvider.overrideWithValue(FakeIndexerService()),
            activeFF1BluetoothDeviceProvider.overrideWithValue(
              const AsyncData(device),
            ),
            ff1WifiControlProvider.overrideWithValue(FakeWifiControl()),
            ff1PlayerStatusStreamProvider.overrideWith(
              (ref) => Stream.value(status),
            ),
            streamBackedCurrentPlayerStatusOverride,
            ff1ConnectionStatusStreamProvider.overrideWith(
              (ref) =>
                  Stream.value(const FF1ConnectionStatus(isConnected: true)),
            ),
            ff1DeviceConnectedProvider.overrideWithValue(true),
          ],
        );
        addTearDown(container.dispose);

        container
          ..listen<AsyncValue<FF1PlayerStatus>>(
            ff1PlayerStatusStreamProvider,
            (_, _) {},
          )
          ..read(nowDisplayingProvider);

        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(const Duration(milliseconds: 150));

        final callsAfterInitial = recordingDb.getPlaylistItemsByIdsCalls.length;
        expect(
          callsAfterInitial,
          greaterThanOrEqualTo(1),
          reason:
              'Initial compute should read the window from DB at least once',
        );

        container
            .read(nowDisplayingRequestedRangeProvider.notifier)
            .expandTo(0, n);
        await Future<void>.delayed(const Duration(milliseconds: 150));

        expect(
          recordingDb.getPlaylistItemsByIdsCalls.length,
          greaterThan(callsAfterInitial),
          reason:
              'requestedRange recompute must not use the identity fast-path; '
              'a wider scroll range needs another getPlaylistItemsByIds',
        );
      },
    );

    test(
      'expanded scroll range updates current item before slow cache completes',
      () async {
        const device = FF1Device(
          name: 'FF1',
          remoteId: 'r1',
          deviceId: 'device_1',
          topicId: 'topic_1',
        );

        const n = 200;
        final dp1Items = List<DP1PlaylistItem>.generate(
          n,
          (i) => DP1PlaylistItem(
            id: 'item_$i',
            duration: 60,
            title: 'T$i',
          ),
        );

        final status = FF1PlayerStatus(
          playlistId: 'pl_1',
          currentWorkIndex: 100,
          items: dp1Items,
        );

        final slowDb = _RecordingDatabaseService(
          db,
          cacheDelay: const Duration(milliseconds: 250),
        );

        final container = ProviderContainer.test(
          overrides: [
            databaseServiceProvider.overrideWith((ref) => slowDb),
            indexerServiceProvider.overrideWithValue(FakeIndexerService()),
            activeFF1BluetoothDeviceProvider.overrideWithValue(
              const AsyncData(device),
            ),
            ff1WifiControlProvider.overrideWithValue(FakeWifiControl()),
            ff1PlayerStatusStreamProvider.overrideWith(
              (ref) => Stream.value(status),
            ),
            streamBackedCurrentPlayerStatusOverride,
            ff1ConnectionStatusStreamProvider.overrideWith(
              (ref) =>
                  Stream.value(const FF1ConnectionStatus(isConnected: true)),
            ),
            ff1DeviceConnectedProvider.overrideWithValue(true),
          ],
        );
        addTearDown(container.dispose);

        final emitted = <NowDisplayingStatus>[];
        final subscription = container.listen<NowDisplayingStatus>(
          nowDisplayingProvider,
          (_, next) => emitted.add(next),
        );
        addTearDown(subscription.close);

        container
          ..listen<AsyncValue<FF1PlayerStatus>>(
            ff1PlayerStatusStreamProvider,
            (_, _) {},
          )
          ..read(nowDisplayingProvider);

        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(const Duration(milliseconds: 300));

        emitted.clear();
        final callsBeforeExpand = slowDb.getPlaylistItemsByIdsCalls.length;

        container
            .read(nowDisplayingRequestedRangeProvider.notifier)
            .expandTo(0, n);
        await Future<void>.delayed(const Duration(milliseconds: 40));

        final stateWhileSlow = container.read(nowDisplayingProvider);
        expect(stateWhileSlow, isA<NowDisplayingSuccess>());
        final objectWhileSlow =
            (stateWhileSlow as NowDisplayingSuccess).object
                as DP1NowDisplayingObject;
        expect(objectWhileSlow.currentItem.id, 'item_100');
        expect(
          emitted.whereType<NowDisplayingSuccess>(),
          isNotEmpty,
          reason:
              'Scroll expansion should publish a new success state immediately '
              'instead of leaving the old state visible until cache completes',
        );
        expect(emitted.whereType<LoadingNowDisplaying>(), isEmpty);
        expect(
          slowDb.getPlaylistItemsByIdsCalls.length,
          greaterThan(callsBeforeExpand),
        );

        await Future<void>.delayed(const Duration(milliseconds: 260));
        final finalState = container.read(nowDisplayingProvider);
        expect(finalState, isA<NowDisplayingSuccess>());
        final finalObject =
            (finalState as NowDisplayingSuccess).object
                as DP1NowDisplayingObject;
        expect(finalObject.currentItem.id, 'item_100');
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
              (ref) =>
                  Stream.value(const FF1ConnectionStatus(isConnected: true)),
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
      },
    );

    test(
      'slow DB cache read does not trigger duplicate indexer enrichment calls',
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

        final recordingSlow = _RecordingDatabaseService(
          db,
          cacheDelay: const Duration(milliseconds: 80),
        );

        final countingIndexer = _CountingIndexerService(tokensByCid: [token]);

        final container = ProviderContainer.test(
          overrides: [
            databaseServiceProvider.overrideWith((ref) => recordingSlow),
            indexerServiceProvider.overrideWithValue(countingIndexer),
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
        await Future<void>.delayed(const Duration(milliseconds: 250));

        expect(
          countingIndexer.getManualTokensCalls,
          1,
          reason:
              'A single recompute should await the cache read and then enrich '
              'once; cache completion must not force a second enrichment pass.',
        );
      },
    );

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
            streamBackedCurrentPlayerStatusOverride,
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

    test(
      'early token check prevents stale recompute from setting loading '
      'after newer recompute starts',
      () async {
        const device = FF1Device(
          name: 'FF1',
          remoteId: 'r1',
          deviceId: 'device_1',
          topicId: 'topic_1',
        );

        // Slow indexer to ensure first recompute is still computing when
        // second recompute (triggered by statusB) starts and completes.
        final indexer = _FirstCallSlowIndexer(
          delay: const Duration(milliseconds: 300),
          tokensByCid: [],
        );

        final statusA = FF1PlayerStatus(
          playlistId: 'pl_1',
          currentWorkIndex: 0,
          items: [
            const DP1PlaylistItem(id: 'item_a', duration: 60, title: 'A'),
          ],
        );
        final statusB = FF1PlayerStatus(
          playlistId: 'pl_1',
          currentWorkIndex: 0,
          items: [
            const DP1PlaylistItem(id: 'item_b', duration: 60, title: 'B'),
          ],
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
            streamBackedCurrentPlayerStatusOverride,
            ff1ConnectionStatusStreamProvider.overrideWith(
              (ref) =>
                  Stream.value(const FF1ConnectionStatus(isConnected: true)),
            ),
            ff1DeviceConnectedProvider.overrideWithValue(true),
          ],
        );
        addTearDown(container.dispose);

        // Ensure StreamProvider subscribes first, then read notifier.
        // This triggers:
        // 1. build() -> microtask (_recompute for initial state)
        // 2. Stream emits statusA after ~20ms -> microtask (_recompute for
        //    statusA)
        // 3. Stream emits statusB after ~40ms -> microtask (_recompute for
        //    statusB, tokens slow)
        container
          ..listen<AsyncValue<FF1PlayerStatus>>(
            ff1PlayerStatusStreamProvider,
            (_, _) {},
          )
          ..read(nowDisplayingProvider);

        // Drain first microtask (initial build recompute)
        await Future<void>.delayed(Duration.zero);
        // statusA stream event arrives + triggers microtask
        await Future<void>.delayed(const Duration(milliseconds: 30));
        // statusB stream event arrives + triggers microtask (indexer now slow
        // on token fetch)
        await Future<void>.delayed(const Duration(milliseconds: 30));

        // At this point, statusB recompute is in flight (awaiting indexer);
        // statusA recompute is also running in background (still computing).
        // Verify we're not in a corrupt state with loading from stale statusA
        // token check early prevents stale token++ from overwriting statusB.
        var state = container.read(nowDisplayingProvider);
        expect(
          state,
          anyOf(
            isA<LoadingNowDisplaying>(),
            isA<NowDisplayingSuccess>(), // statusB may have already completed
          ),
          reason:
              'Should be loading or success from statusB; stale token check '
              'on microtask entry prevents statusA late assign',
        );

        // Wait for both recomputes to settle (first slow one, then statusB)
        await Future<void>.delayed(const Duration(milliseconds: 350));

        // Final state must be from statusB (item_b), not corrupted by late
        // state assign from statusA.
        state = container.read(nowDisplayingProvider);
        expect(state, isA<NowDisplayingSuccess>());
        final object =
            (state as NowDisplayingSuccess).object as DP1NowDisplayingObject;
        expect(
          object.currentItem.id,
          'item_b',
          reason:
              'Newer statusB must win; stale statusA recompute must not '
              'overwrite final state because token check discards late '
              'microtask entries',
        );
      },
    );

    test(
      'newer player status during slow DB cache does not publish stale success',
      () async {
        const device = FF1Device(
          name: 'FF1',
          remoteId: 'r1',
          deviceId: 'device_1',
          topicId: 'topic_1',
        );

        final dp1Items = [
          const DP1PlaylistItem(id: 'item_0', duration: 60, title: 'A'),
          const DP1PlaylistItem(id: 'item_1', duration: 60, title: 'B'),
        ];

        final statusIndex0 = FF1PlayerStatus(
          playlistId: 'pl_1',
          currentWorkIndex: 0,
          items: dp1Items,
        );
        final statusIndex1 = FF1PlayerStatus(
          playlistId: 'pl_1',
          currentWorkIndex: 1,
          items: dp1Items,
        );

        final recordingSlow = _RecordingDatabaseService(
          db,
          cacheDelay: const Duration(milliseconds: 200),
        );

        final playerStatusController = StreamController<FF1PlayerStatus>(
          sync: true,
        );
        addTearDown(playerStatusController.close);

        final container = ProviderContainer.test(
          overrides: [
            databaseServiceProvider.overrideWith((ref) => recordingSlow),
            indexerServiceProvider.overrideWithValue(FakeIndexerService()),
            activeFF1BluetoothDeviceProvider.overrideWithValue(
              const AsyncData(device),
            ),
            ff1WifiControlProvider.overrideWithValue(FakeWifiControl()),
            ff1PlayerStatusStreamProvider.overrideWith(
              (ref) => playerStatusController.stream,
            ),
            streamBackedCurrentPlayerStatusOverride,
            ff1ConnectionStatusStreamProvider.overrideWith(
              (ref) =>
                  Stream.value(const FF1ConnectionStatus(isConnected: true)),
            ),
            ff1DeviceConnectedProvider.overrideWithValue(true),
          ],
        );
        addTearDown(container.dispose);

        container
          ..listen<AsyncValue<FF1PlayerStatus>>(
            ff1PlayerStatusStreamProvider,
            (_, _) {},
          )
          ..read(nowDisplayingProvider);

        await Future<void>.delayed(Duration.zero);
        playerStatusController.add(statusIndex0);
        await Future<void>.delayed(const Duration(milliseconds: 30));
        playerStatusController.add(statusIndex1);
        await Future<void>.delayed(const Duration(milliseconds: 400));

        final state = container.read(nowDisplayingProvider);
        expect(state, isA<NowDisplayingSuccess>());
        final object =
            (state as NowDisplayingSuccess).object as DP1NowDisplayingObject;
        expect(
          object.index,
          1,
          reason:
              'Recompute epoch must discard slow cache result from older index',
        );
        expect(object.currentItem.id, 'item_1');
      },
    );

    test(
      'playing list identity change clears expanded requested range',
      () async {
        const device = FF1Device(
          name: 'FF1',
          remoteId: 'r1',
          deviceId: 'device_1',
          topicId: 'topic_1',
        );

        final itemsPl1 = [
          const DP1PlaylistItem(id: 'a0', duration: 60, title: 'A'),
        ];
        final itemsPl2 = [
          const DP1PlaylistItem(id: 'b0', duration: 60, title: 'B'),
        ];

        final statusPl1 = FF1PlayerStatus(
          playlistId: 'pl_1',
          currentWorkIndex: 0,
          items: itemsPl1,
        );
        final statusPl2 = FF1PlayerStatus(
          playlistId: 'pl_2',
          currentWorkIndex: 0,
          items: itemsPl2,
        );

        final playerStatusController = StreamController<FF1PlayerStatus>(
          sync: true,
        );
        addTearDown(playerStatusController.close);

        final container = ProviderContainer.test(
          overrides: [
            databaseServiceProvider.overrideWith((ref) => recordingDb),
            indexerServiceProvider.overrideWithValue(FakeIndexerService()),
            activeFF1BluetoothDeviceProvider.overrideWithValue(
              const AsyncData(device),
            ),
            ff1WifiControlProvider.overrideWithValue(FakeWifiControl()),
            ff1PlayerStatusStreamProvider.overrideWith(
              (ref) => playerStatusController.stream,
            ),
            streamBackedCurrentPlayerStatusOverride,
            ff1ConnectionStatusStreamProvider.overrideWith(
              (ref) =>
                  Stream.value(const FF1ConnectionStatus(isConnected: true)),
            ),
            ff1DeviceConnectedProvider.overrideWithValue(true),
          ],
        );
        addTearDown(container.dispose);

        container
          ..listen<AsyncValue<FF1PlayerStatus>>(
            ff1PlayerStatusStreamProvider,
            (_, _) {},
          )
          ..read(nowDisplayingProvider);

        await Future<void>.delayed(Duration.zero);
        playerStatusController.add(statusPl1);
        await Future<void>.delayed(const Duration(milliseconds: 120));

        container
            .read(nowDisplayingRequestedRangeProvider.notifier)
            .expandTo(
              0,
              500,
            );
        expect(
          container.read(nowDisplayingRequestedRangeProvider),
          isNotNull,
        );

        playerStatusController.add(statusPl2);
        await Future<void>.delayed(const Duration(milliseconds: 80));

        expect(
          container.read(nowDisplayingRequestedRangeProvider),
          isNull,
          reason:
              'NowDisplayingRequestedRangeNotifier clears expansion on list '
              'identity change',
        );
      },
    );

    test(
      'playing list identity change clears requested range even if items are '
      'null in between',
      () async {
        const device = FF1Device(
          name: 'FF1',
          remoteId: 'r1',
          deviceId: 'device_1',
          topicId: 'topic_1',
        );

        final itemsPl1 = [
          const DP1PlaylistItem(id: 'a0', duration: 60, title: 'A'),
        ];
        final itemsPl2 = [
          const DP1PlaylistItem(id: 'b0', duration: 60, title: 'B'),
        ];

        final statusPl1 = FF1PlayerStatus(
          playlistId: 'pl_1',
          currentWorkIndex: 0,
          items: itemsPl1,
        );
        final statusPl2Loading = FF1PlayerStatus(
          playlistId: 'pl_2',
          currentWorkIndex: 0,
        );
        final statusPl2 = FF1PlayerStatus(
          playlistId: 'pl_2',
          currentWorkIndex: 0,
          items: itemsPl2,
        );

        final playerStatusController = StreamController<FF1PlayerStatus>(
          sync: true,
        );
        addTearDown(playerStatusController.close);

        final container = ProviderContainer.test(
          overrides: [
            databaseServiceProvider.overrideWith((ref) => recordingDb),
            indexerServiceProvider.overrideWithValue(FakeIndexerService()),
            activeFF1BluetoothDeviceProvider.overrideWithValue(
              const AsyncData(device),
            ),
            ff1WifiControlProvider.overrideWithValue(FakeWifiControl()),
            ff1PlayerStatusStreamProvider.overrideWith(
              (ref) => playerStatusController.stream,
            ),
            streamBackedCurrentPlayerStatusOverride,
            ff1ConnectionStatusStreamProvider.overrideWith(
              (ref) =>
                  Stream.value(const FF1ConnectionStatus(isConnected: true)),
            ),
            ff1DeviceConnectedProvider.overrideWithValue(true),
          ],
        );
        addTearDown(container.dispose);

        container
          ..listen<AsyncValue<FF1PlayerStatus>>(
            ff1PlayerStatusStreamProvider,
            (_, _) {},
          )
          ..read(nowDisplayingProvider);

        await Future<void>.delayed(Duration.zero);
        playerStatusController.add(statusPl1);
        await Future<void>.delayed(const Duration(milliseconds: 120));

        container
            .read(nowDisplayingRequestedRangeProvider.notifier)
            .expandTo(
              0,
              500,
            );
        expect(container.read(nowDisplayingRequestedRangeProvider), isNotNull);

        // New playlist announced but items not yet available: don't clear yet.
        playerStatusController.add(statusPl2Loading);
        await Future<void>.delayed(const Duration(milliseconds: 80));
        expect(container.read(nowDisplayingRequestedRangeProvider), isNotNull);

        // Once the new item list is confirmed, clear the widened range.
        playerStatusController.add(statusPl2);
        await Future<void>.delayed(const Duration(milliseconds: 80));
        expect(container.read(nowDisplayingRequestedRangeProvider), isNull);
      },
    );

    test(
      'active device switch clears requested range even when playlist identity '
      'stays the same',
      () async {
        const deviceA = FF1Device(
          name: 'FF1-A',
          remoteId: 'r1',
          deviceId: 'device_a',
          topicId: 'topic_a',
        );
        const deviceB = FF1Device(
          name: 'FF1-B',
          remoteId: 'r2',
          deviceId: 'device_b',
          topicId: 'topic_b',
        );

        final items = [
          const DP1PlaylistItem(id: 'a0', duration: 60, title: 'A'),
        ];

        final status = FF1PlayerStatus(
          playlistId: 'pl_same',
          currentWorkIndex: 0,
          items: items,
        );

        final playerStatusController = StreamController<FF1PlayerStatus>(
          sync: true,
        );
        addTearDown(playerStatusController.close);
        final activeDeviceController = StreamController<FF1Device?>(
          sync: true,
        );
        addTearDown(activeDeviceController.close);

        final container = ProviderContainer.test(
          overrides: [
            databaseServiceProvider.overrideWith((ref) => recordingDb),
            indexerServiceProvider.overrideWithValue(FakeIndexerService()),
            activeFF1BluetoothDeviceProvider.overrideWith(
              (ref) => activeDeviceController.stream,
            ),
            ff1WifiControlProvider.overrideWithValue(FakeWifiControl()),
            ff1PlayerStatusStreamProvider.overrideWith(
              (ref) => playerStatusController.stream,
            ),
            streamBackedCurrentPlayerStatusOverride,
            ff1ConnectionStatusStreamProvider.overrideWith(
              (ref) =>
                  Stream.value(const FF1ConnectionStatus(isConnected: true)),
            ),
            ff1DeviceConnectedProvider.overrideWithValue(true),
          ],
        );
        addTearDown(container.dispose);

        container
          ..listen<AsyncValue<FF1Device?>>(
            activeFF1BluetoothDeviceProvider,
            (_, _) {},
          )
          ..listen<AsyncValue<FF1PlayerStatus>>(
            ff1PlayerStatusStreamProvider,
            (_, _) {},
          )
          ..read(nowDisplayingProvider);

        await Future<void>.delayed(Duration.zero);
        activeDeviceController.add(deviceA);
        playerStatusController.add(status);
        await Future<void>.delayed(const Duration(milliseconds: 120));

        container
            .read(nowDisplayingRequestedRangeProvider.notifier)
            .expandTo(0, 500);
        expect(container.read(nowDisplayingRequestedRangeProvider), isNotNull);

        activeDeviceController.add(deviceB);
        playerStatusController.add(status);
        await Future<void>.delayed(const Duration(milliseconds: 120));

        expect(
          container.read(nowDisplayingRequestedRangeProvider),
          isNull,
          reason:
              'Requested scroll range must reset when the active device '
              'changes, even if the playlist identity and items are reused',
        );
      },
    );

    test(
      'transient null player status does not clear requested range or flash '
      'loading',
      () async {
        const device = FF1Device(
          name: 'FF1',
          remoteId: 'r1',
          deviceId: 'device_1',
          topicId: 'topic_1',
        );

        final itemsPl1 = [
          const DP1PlaylistItem(id: 'a0', duration: 60, title: 'A'),
        ];

        final statusPl1 = FF1PlayerStatus(
          playlistId: 'pl_1',
          currentWorkIndex: 0,
          items: itemsPl1,
        );

        final playerStatusController = StreamController<FF1PlayerStatus>(
          sync: true,
        );
        addTearDown(playerStatusController.close);

        final container = ProviderContainer.test(
          overrides: [
            databaseServiceProvider.overrideWith((ref) => recordingDb),
            indexerServiceProvider.overrideWithValue(FakeIndexerService()),
            activeFF1BluetoothDeviceProvider.overrideWithValue(
              const AsyncData(device),
            ),
            ff1WifiControlProvider.overrideWithValue(FakeWifiControl()),
            ff1PlayerStatusStreamProvider.overrideWith(
              (ref) => playerStatusController.stream,
            ),
            streamBackedCurrentPlayerStatusOverride,
            ff1ConnectionStatusStreamProvider.overrideWith(
              (ref) =>
                  Stream.value(const FF1ConnectionStatus(isConnected: true)),
            ),
            ff1DeviceConnectedProvider.overrideWithValue(true),
          ],
        );
        addTearDown(container.dispose);

        final emitted = <NowDisplayingStatus>[];
        final subscription = container.listen<NowDisplayingStatus>(
          nowDisplayingProvider,
          (_, next) => emitted.add(next),
        );
        addTearDown(subscription.close);

        container
          ..listen<AsyncValue<FF1PlayerStatus>>(
            ff1PlayerStatusStreamProvider,
            (_, _) {},
          )
          ..read(nowDisplayingProvider);

        await Future<void>.delayed(Duration.zero);
        playerStatusController.add(statusPl1);
        await Future<void>.delayed(const Duration(milliseconds: 120));

        container
            .read(nowDisplayingRequestedRangeProvider.notifier)
            .expandTo(
              0,
              500,
            );

        expect(
          container.read(nowDisplayingProvider),
          isA<NowDisplayingSuccess>(),
        );
        expect(container.read(nowDisplayingRequestedRangeProvider), isNotNull);

        // Start tracking after we have a stable success state.
        emitted.clear();

        // Simulate a reconnect/resubscribe blip: stream error maps to null
        // status, then the same status arrives again.
        playerStatusController.addError(StateError('transient reconnect'));
        await Future<void>.delayed(const Duration(milliseconds: 80));

        expect(
          emitted.whereType<LoadingNowDisplaying>(),
          isEmpty,
          reason:
              'Transient status null (loading/error) must not flash loading '
              'for the same playing list',
        );
        expect(
          container.read(nowDisplayingProvider),
          isA<NowDisplayingSuccess>(),
          reason:
              'Transient status null must keep the last computed '
              'now-displaying state',
        );
        expect(
          container.read(nowDisplayingRequestedRangeProvider),
          isNotNull,
          reason:
              'Transient status null must not clear the expanded requested '
              'range',
        );

        playerStatusController.add(statusPl1);
        await Future<void>.delayed(const Duration(milliseconds: 80));

        expect(
          container.read(nowDisplayingProvider),
          isA<NowDisplayingSuccess>(),
        );
        expect(container.read(nowDisplayingRequestedRangeProvider), isNotNull);
      },
    );

    test(
      'same playlist items-null refetch gap does not flash loading',
      () async {
        const device = FF1Device(
          name: 'FF1',
          remoteId: 'r1',
          deviceId: 'device_1',
          topicId: 'topic_1',
        );

        final statusReady = FF1PlayerStatus(
          playlistId: 'pl_1',
          currentWorkIndex: 0,
          items: const [
            DP1PlaylistItem(id: 'item_0', duration: 60, title: 'A'),
          ],
        );
        final statusFetching = FF1PlayerStatus(
          playlistId: 'pl_1',
          currentWorkIndex: 0,
        );

        final playerStatusController = StreamController<FF1PlayerStatus>(
          sync: true,
        );
        addTearDown(playerStatusController.close);

        final container = ProviderContainer.test(
          overrides: [
            databaseServiceProvider.overrideWith((ref) => recordingDb),
            indexerServiceProvider.overrideWithValue(FakeIndexerService()),
            activeFF1BluetoothDeviceProvider.overrideWithValue(
              const AsyncData(device),
            ),
            ff1WifiControlProvider.overrideWithValue(FakeWifiControl()),
            ff1PlayerStatusStreamProvider.overrideWith(
              (ref) => playerStatusController.stream,
            ),
            streamBackedCurrentPlayerStatusOverride,
            ff1ConnectionStatusStreamProvider.overrideWith(
              (ref) =>
                  Stream.value(const FF1ConnectionStatus(isConnected: true)),
            ),
            ff1DeviceConnectedProvider.overrideWithValue(true),
          ],
        );
        addTearDown(container.dispose);

        final emitted = <NowDisplayingStatus>[];
        final subscription = container.listen<NowDisplayingStatus>(
          nowDisplayingProvider,
          (_, next) => emitted.add(next),
        );
        addTearDown(subscription.close);

        container
          ..listen<AsyncValue<FF1PlayerStatus>>(
            ff1PlayerStatusStreamProvider,
            (_, _) {},
          )
          ..read(nowDisplayingProvider);

        await Future<void>.delayed(Duration.zero);
        playerStatusController.add(statusReady);
        await Future<void>.delayed(const Duration(milliseconds: 120));

        emitted.clear();

        playerStatusController.add(statusFetching);
        await Future<void>.delayed(const Duration(milliseconds: 80));
        playerStatusController.add(statusReady);
        await Future<void>.delayed(const Duration(milliseconds: 80));

        expect(emitted.whereType<LoadingNowDisplaying>(), isEmpty);
        expect(
          container.read(nowDisplayingProvider),
          isA<NowDisplayingSuccess>(),
        );
      },
    );
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

class _CountingIndexerService extends FakeIndexerService {
  _CountingIndexerService({
    required super.tokensByCid,
  });

  int getManualTokensCalls = 0;

  @override
  Future<List<AssetToken>> getManualTokens({
    List<int>? tokenIds,
    List<String>? owners,
    List<String>? tokenCids,
    int? limit,
    int? offset,
  }) async {
    getManualTokensCalls++;
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
  // Reason: DatabaseService's positional parameter name is `_db`
  // (library-private), so this test-only subclass cannot use a super-parameter.
  // ignore: use_super_parameters
  _RecordingDatabaseService(
    AppDatabase db, {
    this.cacheDelay = Duration.zero,
    this.cachedItemsById = const {},
  }) : super(db);

  /// When non-zero, delays cache response (simulates slow
  /// getPlaylistItemsByIds).
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
