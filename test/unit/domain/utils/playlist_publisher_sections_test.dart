import 'package:app/domain/models/channel.dart';
import 'package:app/domain/models/playlist.dart';
import 'package:app/domain/utils/playlist_publisher_sections.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('groupPlaylistsByPublisherSections', () {
    final chA = Channel(
      id: 'ch_a',
      name: 'Channel A',
      type: ChannelType.dp1,
      publisherId: 1,
    );
    final chB = Channel(
      id: 'ch_b',
      name: 'Channel B',
      type: ChannelType.dp1,
      publisherId: 2,
    );
    final chNoPub = Channel(
      id: 'ch_nopub',
      name: 'Solo channel',
      type: ChannelType.dp1,
    );

    test('groups by publisher id', () {
      final playlists = [
        const Playlist(
          id: 'p1',
          name: 'P1',
          type: PlaylistType.dp1,
          channelId: 'ch_a',
        ),
        const Playlist(
          id: 'p2',
          name: 'P2',
          type: PlaylistType.dp1,
          channelId: 'ch_b',
        ),
      ];
      final sections = groupPlaylistsByPublisherSections(
        playlists: playlists,
        channelById: {'ch_a': chA, 'ch_b': chB},
        publisherIdToName: {1: 'Publisher One', 2: 'Publisher Two'},
      );
      expect(sections.length, 2);
      expect(sections[0].title, 'Publisher One');
      expect(sections[0].playlists.map((p) => p.id), ['p1']);
      expect(sections[1].title, 'Publisher Two');
      expect(sections[1].playlists.map((p) => p.id), ['p2']);
    });

    test('merges same publisher into one section', () {
      final playlists = [
        const Playlist(
          id: 'p1',
          name: 'P1',
          type: PlaylistType.dp1,
          channelId: 'ch_a',
        ),
        const Playlist(
          id: 'p2',
          name: 'P2',
          type: PlaylistType.dp1,
          channelId: 'ch_b',
        ),
      ];
      final sections = groupPlaylistsByPublisherSections(
        playlists: playlists,
        channelById: {
          'ch_a': chA,
          'ch_b': chA.copyWith(id: 'ch_b'),
        },
        publisherIdToName: {1: 'Same Pub'},
      );
      expect(sections.length, 1);
      expect(sections[0].title, 'Same Pub');
      expect(sections[0].playlists.length, 2);
    });

    test('uses channel name when publisher is null', () {
      final playlists = [
        const Playlist(
          id: 'p1',
          name: 'P1',
          type: PlaylistType.dp1,
          channelId: 'ch_nopub',
        ),
      ];
      final sections = groupPlaylistsByPublisherSections(
        playlists: playlists,
        channelById: {'ch_nopub': chNoPub},
        publisherIdToName: {},
      );
      expect(sections.single.title, 'Solo channel');
    });

    test('My Collection channel id without row uses My Collection title', () {
      final playlists = [
        const Playlist(
          id: 'p1',
          name: 'P1',
          type: PlaylistType.favorite,
          channelId: 'my_collection',
        ),
      ];
      final sections = groupPlaylistsByPublisherSections(
        playlists: playlists,
        channelById: {},
        publisherIdToName: {},
      );
      expect(sections.single.title, 'My Collection');
    });
  });

  group('shouldUsePublisherGroupedLayout', () {
    test('false when channel-scoped', () {
      expect(
        shouldUsePublisherGroupedLayout(
          isChannelScoped: true,
          seedDatabaseReady: true,
          channelAndPublisherLookupsReady: true,
          sectionCount: 3,
        ),
        isFalse,
      );
    });

    test('false when seed database not ready', () {
      expect(
        shouldUsePublisherGroupedLayout(
          isChannelScoped: false,
          seedDatabaseReady: false,
          channelAndPublisherLookupsReady: true,
          sectionCount: 3,
        ),
        isFalse,
      );
    });

    test('false when lookups not ready', () {
      expect(
        shouldUsePublisherGroupedLayout(
          isChannelScoped: false,
          seedDatabaseReady: true,
          channelAndPublisherLookupsReady: false,
          sectionCount: 3,
        ),
        isFalse,
      );
    });

    test('false when only one section', () {
      expect(
        shouldUsePublisherGroupedLayout(
          isChannelScoped: false,
          seedDatabaseReady: true,
          channelAndPublisherLookupsReady: true,
          sectionCount: 1,
        ),
        isFalse,
      );
    });

    test('true when multiple sections and lookups ready', () {
      expect(
        shouldUsePublisherGroupedLayout(
          isChannelScoped: false,
          seedDatabaseReady: true,
          channelAndPublisherLookupsReady: true,
          sectionCount: 2,
        ),
        isTrue,
      );
    });
  });
}
