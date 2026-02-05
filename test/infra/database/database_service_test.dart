import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/domain/models/channel.dart';
import 'package:app/domain/models/dp1/dp1_playlist.dart';
import 'package:app/domain/models/dp1/dp1_playlist_item.dart';
import 'package:app/domain/models/playlist.dart';
import 'package:app/domain/models/playlist_item.dart';
import 'package:app/infra/database/app_database.dart';
import 'package:app/infra/database/database_service.dart';

void main() {
  group('DatabaseService', () {
    late AppDatabase db;
    late DatabaseService service;

    setUp(() {
      // Create an in-memory database for testing
      db = AppDatabase.forTesting(NativeDatabase.memory());
      service = DatabaseService(db);
    });

    tearDown(() async {
      await db.close();
    });

    group('Channel operations', () {
      test('ingestChannel inserts channel', () async {
        final channel = Channel(
          id: 'ch_test',
          name: 'Test Channel',
          type: ChannelType.dp1,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        await service.ingestChannel(channel);

        final retrieved = await service.getChannelById('ch_test');
        expect(retrieved, isNotNull);
        expect(retrieved!.id, 'ch_test');
        expect(retrieved.name, 'Test Channel');
      });

      test('ingestChannels batch inserts channels', () async {
        final channels = [
          Channel(
            id: 'ch_1',
            name: 'Channel 1',
            type: ChannelType.dp1,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
          Channel(
            id: 'ch_2',
            name: 'Channel 2',
            type: ChannelType.localVirtual,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        ];

        await service.ingestChannels(channels);

        final retrieved = await service.getChannels();
        expect(retrieved.length, 2);
        expect(retrieved[0].id, 'ch_1');
        expect(retrieved[1].id, 'ch_2');
      });
    });

    group('Playlist operations', () {
      test('ingestPlaylist inserts playlist', () async {
        final playlist = Playlist(
          id: 'pl_test',
          name: 'Test Playlist',
          type: PlaylistType.dp1,
          sortMode: PlaylistSortMode.position,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        await service.ingestPlaylist(playlist);

        final retrieved = await service.getPlaylistById('pl_test');
        expect(retrieved, isNotNull);
        expect(retrieved!.id, 'pl_test');
        expect(retrieved.name, 'Test Playlist');
      });

      test('getPlaylistsByChannel returns correct playlists', () async {
        final playlists = [
          Playlist(
            id: 'pl_1',
            name: 'Playlist 1',
            type: PlaylistType.dp1,
            channelId: 'ch_test',
            sortMode: PlaylistSortMode.position,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
          Playlist(
            id: 'pl_2',
            name: 'Playlist 2',
            type: PlaylistType.dp1,
            channelId: 'ch_test',
            sortMode: PlaylistSortMode.position,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
          Playlist(
            id: 'pl_3',
            name: 'Playlist 3',
            type: PlaylistType.dp1,
            channelId: 'ch_other',
            sortMode: PlaylistSortMode.position,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        ];

        await service.ingestPlaylists(playlists);

        final retrieved = await service.getPlaylistsByChannel('ch_test');
        expect(retrieved.length, 2);
        expect(retrieved[0].channelId, 'ch_test');
        expect(retrieved[1].channelId, 'ch_test');
      });

      test('getAddressPlaylists returns only address-based playlists',
          () async {
        final playlists = [
          Playlist(
            id: 'pl_dp1',
            name: 'DP1 Playlist',
            type: PlaylistType.dp1,
            sortMode: PlaylistSortMode.position,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
          Playlist(
            id: 'pl_addr',
            name: 'Address Playlist',
            type: PlaylistType.addressBased,
            ownerAddress: '0xABCD',
            sortMode: PlaylistSortMode.provenance,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        ];

        await service.ingestPlaylists(playlists);

        final retrieved = await service.getAddressPlaylists();
        expect(retrieved.length, 1);
        expect(retrieved[0].type, PlaylistType.addressBased);
        expect(retrieved[0].ownerAddress, '0xABCD');
      });
    });

    group('PlaylistItem operations', () {
      test('ingestPlaylistItem inserts item', () async {
        final item = PlaylistItem(
          id: 'item_test',
          kind: PlaylistItemKind.indexerToken,
          title: 'Test Item',
          updatedAt: DateTime.now(),
        );

        await service.ingestPlaylistItem(item);

        final retrieved = await service.getPlaylistItemById('item_test');
        expect(retrieved, isNotNull);
        expect(retrieved!.id, 'item_test');
        expect(retrieved.title, 'Test Item');
      });

      test('getPlaylistItems returns items in order', () async {
        // Create playlist
        final playlist = Playlist(
          id: 'pl_test',
          name: 'Test Playlist',
          type: PlaylistType.dp1,
          sortMode: PlaylistSortMode.position,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        await service.ingestPlaylist(playlist);

        // Create items
        final items = [
          PlaylistItem(
            id: 'item_1',
            kind: PlaylistItemKind.indexerToken,
            title: 'Item 1',
            updatedAt: DateTime.now(),
          ),
          PlaylistItem(
            id: 'item_2',
            kind: PlaylistItemKind.indexerToken,
            title: 'Item 2',
            updatedAt: DateTime.now(),
          ),
          PlaylistItem(
            id: 'item_3',
            kind: PlaylistItemKind.indexerToken,
            title: 'Item 3',
            updatedAt: DateTime.now(),
          ),
        ];
        await service.ingestPlaylistItems(items);

        // Create entries with positions
        final nowUs = BigInt.from(DateTime.now().microsecondsSinceEpoch);
        await db.upsertPlaylistEntries([
          PlaylistEntriesCompanion.insert(
            playlistId: 'pl_test',
            itemId: 'item_2',
            position: const Value(0),
            sortKeyUs: BigInt.zero,
            updatedAtUs: nowUs,
          ),
          PlaylistEntriesCompanion.insert(
            playlistId: 'pl_test',
            itemId: 'item_1',
            position: const Value(1),
            sortKeyUs: BigInt.zero,
            updatedAtUs: nowUs,
          ),
          PlaylistEntriesCompanion.insert(
            playlistId: 'pl_test',
            itemId: 'item_3',
            position: const Value(2),
            sortKeyUs: BigInt.zero,
            updatedAtUs: nowUs,
          ),
        ]);

        await db.updatePlaylistItemCount('pl_test');

        final retrieved = await service.getPlaylistItems('pl_test');
        expect(retrieved.length, 3);
        expect(retrieved[0].id, 'item_2');
        expect(retrieved[1].id, 'item_1');
        expect(retrieved[2].id, 'item_3');
      });

      test('deletePlaylistItem removes item and entries', () async {
        final item = PlaylistItem(
          id: 'item_test',
          kind: PlaylistItemKind.indexerToken,
          title: 'Test Item',
          updatedAt: DateTime.now(),
        );
        await service.ingestPlaylistItem(item);

        await service.deletePlaylistItem('item_test');

        final retrieved = await service.getPlaylistItemById('item_test');
        expect(retrieved, isNull);
      });
    });

    group('DP1 Playlist ingestion', () {
      test('ingestDP1Playlist creates playlist with items', () async {
        final dp1Playlist = DP1Playlist(
          dpVersion: '1.0.0',
          id: 'pl_test',
          slug: 'test',
          title: 'Test Playlist',
          created: DateTime.now(),
          signature: '',
          items: [
            DP1PlaylistItem(id: 'item_1', duration: 0, title: 'Item 1'),
            DP1PlaylistItem(id: 'item_2', duration: 0, title: 'Item 2'),
          ],
        );

        await service.ingestDP1Playlist(
          playlist: dp1Playlist,
          baseUrl: 'https://example.com',
          tokens: null,
        );

        final retrievedPlaylist = await service.getPlaylistById('pl_test');
        expect(retrievedPlaylist, isNotNull);
        expect(retrievedPlaylist!.itemCount, 2);

        final retrievedItems = await service.getPlaylistItems('pl_test');
        expect(retrievedItems.length, 2);
        expect(retrievedItems[0].id, 'item_1');
        expect(retrievedItems[1].id, 'item_2');
      });
    });

    group('clearAll', () {
      test('removes all data', () async {
        // Insert some data
        await service.ingestChannel(
          Channel(
            id: 'ch_test',
            name: 'Test',
            type: ChannelType.dp1,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        );

        await service.clearAll();

        final channels = await service.getChannels();
        expect(channels, isEmpty);
      });
    });
  });
}
