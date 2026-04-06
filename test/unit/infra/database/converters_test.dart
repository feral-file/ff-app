import 'package:app/domain/models/channel.dart';
import 'package:app/domain/models/dp1/dp1_manifest.dart';
import 'package:app/domain/models/playlist.dart';
import 'package:app/domain/models/playlist_item.dart';
import 'package:app/infra/database/app_database.dart';
import 'package:app/infra/database/converters.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DatabaseConverters', () {
    group('Channel conversions', () {
      test('channelToCompanion creates correct companion', () {
        final channel = Channel(
          id: 'ch_test',
          name: 'Test Channel',
          type: ChannelType.dp1,
          description: 'A test channel',
          baseUrl: 'https://example.com',
          slug: 'test-channel',
          curator: 'Test Curator',
          coverImageUrl: 'https://example.com/cover.jpg',
          createdAt: DateTime(2024),
          updatedAt: DateTime(2024, 1, 2),
          sortOrder: 1,
        );

        final companion = DatabaseConverters.channelToCompanion(channel);

        expect(companion.id.value, 'ch_test');
        expect(companion.type.value, 0); // DP1
        expect(companion.title.value, 'Test Channel');
        expect(companion.summary.value, 'A test channel');
        expect(companion.baseUrl.value, 'https://example.com');
        expect(companion.slug.value, 'test-channel');
        expect(companion.curator.value, 'Test Curator');
        expect(companion.sortOrder.value, 1);
      });

      test('channelDataToDomain converts correctly', () {
        final data = ChannelData(
          id: 'ch_test',
          type: 0,
          title: 'Test Channel',
          summary: 'A test channel',
          baseUrl: 'https://example.com',
          slug: 'test-channel',
          curator: 'Test Curator',
          coverImageUri: 'https://example.com/cover.jpg',
          createdAtUs: BigInt.from(DateTime(2024).microsecondsSinceEpoch),
          updatedAtUs: BigInt.from(DateTime(2024, 1, 2).microsecondsSinceEpoch),
          sortOrder: 1,
        );

        final channel = DatabaseConverters.channelDataToDomain(data);

        expect(channel.id, 'ch_test');
        expect(channel.type, ChannelType.dp1);
        expect(channel.name, 'Test Channel');
        expect(channel.description, 'A test channel');
        expect(channel.baseUrl, 'https://example.com');
        expect(channel.slug, 'test-channel');
        expect(channel.curator, 'Test Curator');
        expect(channel.sortOrder, 1);
      });
    });

    group('Playlist conversions', () {
      test('playlistToCompanion creates correct companion', () {
        final playlist = Playlist(
          id: 'pl_test',
          name: 'Test Playlist',
          type: PlaylistType.dp1,
          channelId: 'ch_test',
          baseUrl: 'https://example.com',
          dpVersion: '1.0',
          slug: 'test-playlist',
          itemCount: 5,
          createdAt: DateTime(2024),
          updatedAt: DateTime(2024, 1, 2),
        );

        final companion = DatabaseConverters.playlistToCompanion(playlist);

        expect(companion.id.value, 'pl_test');
        expect(companion.type.value, 0); // DP1
        expect(companion.title.value, 'Test Playlist');
        expect(companion.channelId.value, 'ch_test');
        expect(companion.baseUrl.value, 'https://example.com');
        expect(companion.sortMode.value, 0); // Position
        expect(companion.itemCount.value, 5);
      });

      test('playlistDataToDomain converts correctly', () {
        final data = PlaylistData(
          id: 'pl_test',
          type: 0,
          title: 'Test Playlist',
          channelId: 'ch_test',
          baseUrl: 'https://example.com',
          dpVersion: '1.0',
          slug: 'test-playlist',
          sortMode: 0,
          itemCount: 5,
          signatures: '[]',
          createdAtUs: BigInt.from(DateTime(2024).microsecondsSinceEpoch),
          updatedAtUs: BigInt.from(DateTime(2024, 1, 2).microsecondsSinceEpoch),
        );

        final playlist = DatabaseConverters.playlistDataToDomain(data);

        expect(playlist.id, 'pl_test');
        expect(playlist.type, PlaylistType.dp1);
        expect(playlist.name, 'Test Playlist');
        expect(playlist.channelId, 'ch_test');
        expect(playlist.sortMode, PlaylistSortMode.position);
        expect(playlist.itemCount, 5);
      });
    });

    group('PlaylistItem conversions', () {
      test('playlistItemToCompanion creates correct companion', () {
        final item = PlaylistItem(
          id: 'item_test',
          kind: PlaylistItemKind.indexerToken,
          title: 'Test Item',
          artists: [const DP1Artist(name: 'Test Artist', id: 'artist_1')],
          thumbnailUrl: 'https://example.com/thumb.jpg',
          duration: 120,
          updatedAt: DateTime(2024),
        );

        final companion = DatabaseConverters.playlistItemToCompanion(item);

        expect(companion.id.value, 'item_test');
        expect(companion.kind.value, 1); // IndexerToken
        expect(companion.title.value, 'Test Item');
        expect(companion.thumbnailUri.value, 'https://example.com/thumb.jpg');
        expect(companion.durationSec.value, 120);
      });

      test('itemDataToDomain converts correctly', () {
        final data = ItemData(
          id: 'item_test',
          kind: 1,
          title: 'Test Item',
          thumbnailUri: 'https://example.com/thumb.jpg',
          durationSec: 120,
          enrichmentStatus: 0,
          updatedAtUs: BigInt.from(DateTime(2024).microsecondsSinceEpoch),
        );

        final item = DatabaseConverters.itemDataToDomain(data);

        expect(item.id, 'item_test');
        expect(item.kind, PlaylistItemKind.indexerToken);
        expect(item.title, 'Test Item');
        expect(item.thumbnailUrl, 'https://example.com/thumb.jpg');
        expect(item.duration, 120);
      });
    });

    group('PlaylistEntry creation', () {
      test('createPlaylistEntry creates correct companion', () {
        final entry = DatabaseConverters.createPlaylistEntry(
          playlistId: 'pl_test',
          itemId: 'wk_test',
          position: 1,
          sortKeyUs: 123456789,
        );

        expect(entry.playlistId.value, 'pl_test');
        expect(entry.itemId.value, 'wk_test');
        expect(entry.position.value, 1);
        expect(entry.sortKeyUs.value, BigInt.from(123456789));
      });
    });
  });
}
