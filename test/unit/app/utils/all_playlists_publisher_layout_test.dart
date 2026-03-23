import 'package:app/app/utils/all_playlists_publisher_layout.dart';
import 'package:app/domain/models/channel.dart';
import 'package:app/domain/models/playlist.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const pPub1 = Playlist(
    id: 'pl_1',
    name: 'P1',
    type: PlaylistType.dp1,
    channelId: 'ch_a',
    itemCount: 1,
  );
  const pPub2 = Playlist(
    id: 'pl_2',
    name: 'P2',
    type: PlaylistType.dp1,
    channelId: 'ch_b',
    itemCount: 1,
  );
  const pSamePub1 = Playlist(
    id: 'pl_3',
    name: 'P3',
    type: PlaylistType.dp1,
    channelId: 'ch_a',
    itemCount: 1,
  );
  const pSamePub2 = Playlist(
    id: 'pl_4',
    name: 'P4',
    type: PlaylistType.dp1,
    channelId: 'ch_b',
    itemCount: 1,
  );

  const channelA = Channel(
    id: 'ch_a',
    name: 'Channel A',
    type: ChannelType.dp1,
    publisherId: 1,
  );
  const channelBSamePub = Channel(
    id: 'ch_b',
    name: 'Channel B',
    type: ChannelType.dp1,
    publisherId: 1,
  );
  const channelB = Channel(
    id: 'ch_b',
    name: 'Channel B',
    type: ChannelType.dp1,
    publisherId: 2,
  );

  final publisherNames = {1: 'Publisher One', 2: 'Publisher Two'};
  final channelMapTwoPubs = {'ch_a': channelA, 'ch_b': channelB};
  final channelMapOnePub = {'ch_a': channelA, 'ch_b': channelBSamePub};

  group('resolveAllPlaylistsPublisherLayout', () {
    test('channel-scoped: never section headers', () {
      final r = resolveAllPlaylistsPublisherLayout(
        isChannelScoped: true,
        seedDatabaseReady: true,
        publisherAsync: AsyncData(publisherNames),
        channelAsync: AsyncData(channelMapTwoPubs),
        playlists: const [pPub1, pPub2],
      );
      expect(r.useSectionHeaders, isFalse);
      expect(r.sections, isEmpty);
    });

    test('seed not ready: flat despite lookup data', () {
      final r = resolveAllPlaylistsPublisherLayout(
        isChannelScoped: false,
        seedDatabaseReady: false,
        publisherAsync: AsyncData(publisherNames),
        channelAsync: AsyncData(channelMapTwoPubs),
        playlists: const [pPub1, pPub2],
      );
      expect(r.useSectionHeaders, isFalse);
      expect(r.sections.length, 2);
    });

    test('publisher stream loading: flat', () {
      final r = resolveAllPlaylistsPublisherLayout(
        isChannelScoped: false,
        seedDatabaseReady: true,
        publisherAsync: const AsyncLoading(),
        channelAsync: AsyncData(channelMapTwoPubs),
        playlists: const [pPub1, pPub2],
      );
      expect(r.useSectionHeaders, isFalse);
    });

    test('channel stream loading: flat', () {
      final r = resolveAllPlaylistsPublisherLayout(
        isChannelScoped: false,
        seedDatabaseReady: true,
        publisherAsync: AsyncData(publisherNames),
        channelAsync: const AsyncLoading(),
        playlists: const [pPub1, pPub2],
      );
      expect(r.useSectionHeaders, isFalse);
    });

    test('two publisher sections and ready: headers on', () {
      final r = resolveAllPlaylistsPublisherLayout(
        isChannelScoped: false,
        seedDatabaseReady: true,
        publisherAsync: AsyncData(publisherNames),
        channelAsync: AsyncData(channelMapTwoPubs),
        playlists: const [pPub1, pPub2],
      );
      expect(r.useSectionHeaders, isTrue);
      expect(r.sections.length, 2);
      expect(r.sections[0].title, 'Publisher One');
      expect(r.sections[1].title, 'Publisher Two');
    });

    test('single publisher bucket: flat', () {
      final r = resolveAllPlaylistsPublisherLayout(
        isChannelScoped: false,
        seedDatabaseReady: true,
        publisherAsync: const AsyncData({1: 'Only Pub'}),
        channelAsync: AsyncData(channelMapOnePub),
        playlists: const [pSamePub1, pSamePub2],
      );
      expect(r.useSectionHeaders, isFalse);
      expect(r.sections.length, 1);
    });
  });
}
