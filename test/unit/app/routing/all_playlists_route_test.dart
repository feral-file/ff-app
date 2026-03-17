import 'package:app/app/routing/all_playlists_route.dart';
import 'package:app/domain/models/channel.dart';
import 'package:app/domain/models/playlist.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('buildAllPlaylistsQuery / parseAllPlaylistsQuery round-trip', () {
    test('empty params round-trip', () {
      final query = buildAllPlaylistsQuery();
      expect(query, '');
      final parsed = parseAllPlaylistsQuery(null);
      expect(parsed.channelTypes, isNull);
      expect(parsed.channelIds, isNull);
      expect(parsed.playlistTypes, isNull);
    });

    test('channelTypes round-trip', () {
      final query = buildAllPlaylistsQuery(
        channelTypes: [ChannelType.dp1, ChannelType.localVirtual],
      );
      expect(query, contains('channelTypes='));
      final uri = Uri.parse('http://x/$query');
      final parsed = parseAllPlaylistsQuery(uri.queryParameters);
      expect(parsed.channelTypes, [ChannelType.dp1, ChannelType.localVirtual]);
    });

    test('channelIds round-trip', () {
      final query = buildAllPlaylistsQuery(
        channelIds: ['ch_1', 'ch_2'],
      );
      expect(query, contains('channelIds='));
      final uri = Uri.parse('http://x/$query');
      final parsed = parseAllPlaylistsQuery(uri.queryParameters);
      expect(parsed.channelIds, ['ch_1', 'ch_2']);
    });

    test('playlistTypes round-trip', () {
      final query = buildAllPlaylistsQuery(
        playlistTypes: [PlaylistType.dp1, PlaylistType.favorite],
      );
      expect(query, contains('playlistTypes='));
      final uri = Uri.parse('http://x/$query');
      final parsed = parseAllPlaylistsQuery(uri.queryParameters);
      expect(parsed.playlistTypes, [PlaylistType.dp1, PlaylistType.favorite]);
    });

    test('legacy channelId fallback', () {
      final parsed = parseAllPlaylistsQuery({'channelId': 'ch_single'});
      expect(parsed.channelIds, ['ch_single']);
    });

    test('full round-trip', () {
      final query = buildAllPlaylistsQuery(
        channelTypes: [ChannelType.localVirtual],
        channelIds: ['ch_me'],
        playlistTypes: [PlaylistType.addressBased],
      );
      final uri = Uri.parse('http://x/$query');
      final parsed = parseAllPlaylistsQuery(uri.queryParameters);
      expect(parsed.channelTypes, [ChannelType.localVirtual]);
      expect(parsed.channelIds, ['ch_me']);
      expect(parsed.playlistTypes, [PlaylistType.addressBased]);
    });
  });

  group('deriveAllPlaylistsMetadata', () {
    test('channel-scoped address only', () {
      final params = (
        channelTypes: null,
        channelIds: ['ch_1'],
        playlistTypes: [PlaylistType.addressBased],
      );
      final m = deriveAllPlaylistsMetadata(params);
      expect(m.title, 'Address');
      expect(m.description, isNotNull);
      expect(m.iconAsset, 'assets/images/icon_account.svg');
    });

    test('channel-scoped playlists', () {
      final params = (
        channelTypes: null,
        channelIds: ['ch_1'],
        playlistTypes: [PlaylistType.dp1, PlaylistType.favorite],
      );
      final m = deriveAllPlaylistsMetadata(params);
      expect(m.title, 'Playlists');
      expect(m.description, 'All playlists in this channel.');
      expect(m.iconAsset, 'assets/images/list.svg');
    });

    test('channelTypes localVirtual only', () {
      final params = (
        channelTypes: [ChannelType.localVirtual],
        channelIds: null,
        playlistTypes: null,
      );
      final m = deriveAllPlaylistsMetadata(params);
      expect(m.title, 'Me');
      expect(m.iconAsset, 'assets/images/icon_account.svg');
    });

    test('channelTypes dp1 only', () {
      final params = (
        channelTypes: [ChannelType.dp1],
        channelIds: null,
        playlistTypes: null,
      );
      final m = deriveAllPlaylistsMetadata(params);
      expect(m.title, 'Curated');
      expect(m.iconAsset, 'assets/images/D.svg');
    });

    test('empty params returns null metadata', () {
      final params = (
        channelTypes: null,
        channelIds: null,
        playlistTypes: null,
      );
      final m = deriveAllPlaylistsMetadata(params);
      expect(m.title, isNull);
      expect(m.description, isNull);
      expect(m.iconAsset, isNull);
    });
  });
}
