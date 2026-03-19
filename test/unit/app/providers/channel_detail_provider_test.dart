import 'dart:async';

import 'package:app/app/providers/channel_detail_provider.dart';
import 'package:app/domain/models/channel.dart';
import 'package:app/domain/models/playlist.dart';
import 'package:app/infra/database/app_database.dart';
import 'package:app/infra/database/database_provider.dart';
import 'package:app/infra/database/database_service.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

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
}
