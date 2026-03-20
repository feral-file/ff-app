import 'dart:async';

import 'package:app/app/providers/channel_detail_provider.dart';
import 'package:app/app/providers/database_service_provider.dart';
import 'package:app/app/providers/seed_database_ready_provider.dart';
import 'package:app/domain/models/channel.dart';
import 'package:app/domain/models/playlist.dart';
import 'package:app/infra/database/app_database.dart';
import 'package:app/infra/database/database_service.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// [isSeedDatabaseReadyProvider] override so [databaseServiceProvider] uses the
/// test [DatabaseService] (not the empty in-memory stub).
class _AlwaysReadySeedNotifier extends SeedDatabaseReadyNotifier {
  @override
  bool build() => true;
}

/// Counts [watchChannelById] calls to prove StreamProvider rebuild re-attaches.
class _CountingDatabaseService extends DatabaseService {
  _CountingDatabaseService(super.db);

  int watchChannelByIdCallCount = 0;

  @override
  Stream<Channel?> watchChannelById(String id) {
    watchChannelByIdCallCount++;
    return super.watchChannelById(id);
  }
}

class _RebindTickNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void bump() => state++;
}

final _rebindTickProvider = NotifierProvider<_RebindTickNotifier, int>(
  _RebindTickNotifier.new,
);

void main() {
  test('channelPlaylistsFromIdsProvider preserves publisher_id, created_at order',
      () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final dbService = DatabaseService(db);

    await dbService.ingestPublisher(id: 10, name: 'Pub A');
    await dbService.ingestPublisher(id: 20, name: 'Pub B');
    await dbService.ingestChannel(const Channel(
      id: 'ch_a',
      name: 'Channel A',
      type: ChannelType.dp1,
      publisherId: 10,
    ));
    await dbService.ingestChannel(const Channel(
      id: 'ch_b',
      name: 'Channel B',
      type: ChannelType.dp1,
      publisherId: 20,
    ));

    final t0 = DateTime.fromMillisecondsSinceEpoch(1000);
    final t1 = DateTime.fromMillisecondsSinceEpoch(2000);
    final t2 = DateTime.fromMillisecondsSinceEpoch(3000);
    await dbService.ingestPlaylist(Playlist(
      id: 'pl_b1',
      name: 'B first',
      type: PlaylistType.dp1,
      channelId: 'ch_b',
      createdAt: t1,
      itemCount: 1,
    ));
    await dbService.ingestPlaylist(Playlist(
      id: 'pl_a1',
      name: 'A first',
      type: PlaylistType.dp1,
      channelId: 'ch_a',
      createdAt: t2,
      itemCount: 1,
    ));
    await dbService.ingestPlaylist(Playlist(
      id: 'pl_a2',
      name: 'A second',
      type: PlaylistType.dp1,
      channelId: 'ch_a',
      createdAt: t0,
      itemCount: 1,
    ));

    final container = ProviderContainer.test(
      overrides: [
        databaseServiceProvider.overrideWith((ref) => dbService),
      ],
    );
    addTearDown(container.dispose);

    final completer = Completer<List<Playlist>>();
    final sub = container.listen<AsyncValue<List<Playlist>>>(
      channelPlaylistsFromIdsProvider('ch_a,ch_b'),
      (_, next) {
        next.whenData((value) {
          if (value.length >= 3 && !completer.isCompleted) {
            completer.complete(value);
          }
        });
      },
      fireImmediately: true,
    );
    addTearDown(sub.close);

    final playlists = await completer.future;
    expect(playlists.length, 3);
    expect(playlists.map((p) => p.id).toList(), ['pl_a2', 'pl_a1', 'pl_b1']);
  });

  test('channelDetailsProvider combines channel and channel playlists', () async {
    // Unit test: verifies channel detail stream combines channel row and playlist rows.
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final dbService = DatabaseService(db);
    final container = ProviderContainer.test(
      overrides: [
        databaseServiceProvider.overrideWith((ref) => dbService),
      ],
    );
    addTearDown(container.dispose);

    final completer = Completer<ChannelDetails>();
    final sub = container.listen<AsyncValue<ChannelDetails>>(
      channelDetailsProvider('ch_1'),
      (_, next) {
        next.whenData((value) {
          if (value.channel?.id == 'ch_1' && !completer.isCompleted) {
            completer.complete(value);
          }
        });
      },
      fireImmediately: true,
    );
    addTearDown(sub.close);

    await dbService.ingestChannel(
      const Channel(id: 'ch_1', name: 'Channel 1', type: ChannelType.dp1),
    );
    await dbService.ingestPlaylist(
      const Playlist(
        id: 'pl_1',
        name: 'Playlist 1',
        type: PlaylistType.dp1,
        channelId: 'ch_1',
        itemCount: 1,
      ),
    );

    final details = await completer.future;
    expect(details.channel?.id, 'ch_1');
    expect(details.playlists.map((p) => p.id), contains('pl_1'));
  });

  test('channelDetailsProvider includes empty address playlists', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final dbService = DatabaseService(db);
    final container = ProviderContainer.test(
      overrides: [
        databaseServiceProvider.overrideWith((ref) => dbService),
      ],
    );
    addTearDown(container.dispose);

    final completer = Completer<ChannelDetails>();
    final sub = container.listen<AsyncValue<ChannelDetails>>(
      channelDetailsProvider('ch_me'),
      (_, next) {
        next.whenData((value) {
          if (value.channel?.id == 'ch_me' && !completer.isCompleted) {
            completer.complete(value);
          }
        });
      },
      fireImmediately: true,
    );
    addTearDown(sub.close);

    await dbService.ingestChannel(const Channel(
      id: 'ch_me',
      name: 'Me',
      type: ChannelType.localVirtual,
    ));
    await dbService.ingestPlaylist(const Playlist(
      id: 'pl_empty_addr',
      name: 'Empty address',
      type: PlaylistType.addressBased,
      channelId: 'ch_me',
    ));

    final details = await completer.future;
    expect(details.channel?.id, 'ch_me');
    expect(details.playlists.length, 1);
    expect(details.playlists.single.id, 'pl_empty_addr');
    expect(details.playlists.single.itemCount, 0);
  });

  test('channelPlaylistsFromIdsProvider filters out playlists without works',
      () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final dbService = DatabaseService(db);

    await dbService.ingestPublisher(id: 10, name: 'Pub');
    await dbService.ingestChannel(const Channel(
      id: 'ch_me',
      name: 'Me',
      type: ChannelType.localVirtual,
      publisherId: 10,
    ));

    await dbService.ingestPlaylist(const Playlist(
      id: 'favorite',
      name: 'Favorites',
      type: PlaylistType.favorite,
      channelId: 'ch_me',
    ));
    await dbService.ingestPlaylist(const Playlist(
      id: 'pl_with_works',
      name: 'With works',
      type: PlaylistType.addressBased,
      channelId: 'ch_me',
      itemCount: 2,
    ));

    final container = ProviderContainer.test(
      overrides: [
        databaseServiceProvider.overrideWith((ref) => dbService),
      ],
    );
    addTearDown(container.dispose);

    final completer = Completer<List<Playlist>>();
    final sub = container.listen<AsyncValue<List<Playlist>>>(
      channelPlaylistsFromIdsProvider('ch_me'),
      (_, next) {
        next.whenData((value) {
          if (!completer.isCompleted) completer.complete(value);
        });
      },
      fireImmediately: true,
    );
    addTearDown(sub.close);

    final playlists = await completer.future;
    expect(playlists.length, 1);
    expect(playlists.single.id, 'pl_with_works');
  });

  test('channelPlaylistsFromIdsProvider includes empty address playlists', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final dbService = DatabaseService(db);

    await dbService.ingestPublisher(id: 10, name: 'Pub');
    await dbService.ingestChannel(const Channel(
      id: 'ch_me',
      name: 'Me',
      type: ChannelType.localVirtual,
      publisherId: 10,
    ));

    await dbService.ingestPlaylist(const Playlist(
      id: 'pl_empty_addr',
      name: 'Empty address',
      type: PlaylistType.addressBased,
      channelId: 'ch_me',
    ));

    final container = ProviderContainer.test(
      overrides: [
        databaseServiceProvider.overrideWith((ref) => dbService),
      ],
    );
    addTearDown(container.dispose);

    final completer = Completer<List<Playlist>>();
    final sub = container.listen<AsyncValue<List<Playlist>>>(
      channelPlaylistsFromIdsProvider('ch_me'),
      (_, next) {
        next.whenData((value) {
          if (!completer.isCompleted) completer.complete(value);
        });
      },
      fireImmediately: true,
    );
    addTearDown(sub.close);

    final playlists = await completer.future;
    expect(playlists.length, 1);
    expect(playlists.single.id, 'pl_empty_addr');
    expect(playlists.single.itemCount, 0);
  });

  test(
    'channelDetailsProvider re-subscribes when databaseServiceProvider '
    'returns a new instance (watch dependency)',
    () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);

      await DatabaseService(db).ingestPublisher(id: 1, name: 'Pub');
      await DatabaseService(db).ingestChannel(const Channel(
        id: 'c1',
        name: 'Channel One',
        type: ChannelType.dp1,
        publisherId: 1,
      ));

      var databaseServiceBuildCount = 0;
      final container = ProviderContainer(
        overrides: [
          isSeedDatabaseReadyProvider.overrideWith(_AlwaysReadySeedNotifier.new),
          databaseServiceProvider.overrideWith((ref) {
            ref.watch(_rebindTickProvider);
            databaseServiceBuildCount++;
            return _CountingDatabaseService(db);
          }),
        ],
      );
      addTearDown(container.dispose);

      final sub = container.listen<AsyncValue<ChannelDetails>>(
        channelDetailsProvider('c1'),
        (_, __) {},
        fireImmediately: true,
      );
      addTearDown(sub.close);

      await Future<void>.delayed(Duration.zero);
      expect(databaseServiceBuildCount, greaterThanOrEqualTo(1));

      final firstCounting =
          container.read(databaseServiceProvider) as _CountingDatabaseService;
      expect(firstCounting.watchChannelByIdCallCount, greaterThanOrEqualTo(1));

      container.read(_rebindTickProvider.notifier).bump();

      await Future<void>.delayed(const Duration(milliseconds: 100));

      expect(databaseServiceBuildCount, greaterThanOrEqualTo(2));

      final secondCounting =
          container.read(databaseServiceProvider) as _CountingDatabaseService;
      expect(
        secondCounting.watchChannelByIdCallCount,
        greaterThanOrEqualTo(1),
        reason: 'new DatabaseService instance should attach a fresh watch',
      );
      expect(
        identical(firstCounting, secondCounting),
        isFalse,
        reason: 'rebind must use a new service instance so dependents update',
      );
    },
  );
}
