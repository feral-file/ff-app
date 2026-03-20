import 'package:app/app/providers/search_provider.dart';
import 'package:app/domain/models/channel.dart';
import 'package:app/domain/models/playlist.dart';
import 'package:app/domain/models/playlist_item.dart';
import 'package:app/ui/screens/tabs/search/search_filter_models.dart';
import 'package:app/ui/screens/tabs/search/search_filtering.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('availableTypesFromResults', () {
    test('returns empty when results are empty', () {
      const results = SearchResults(
        channels: [],
        playlists: [],
        works: [],
        artistMatchedWorkIds: <String>{},
      );
      expect(availableTypesFromResults(results), isEmpty);
    });

    test('returns types in old-app order: playlists, channels, works', () {
      const results = SearchResults(
        playlists: [
          Playlist(id: 'pl_1', name: 'P', type: PlaylistType.dp1),
        ],
        channels: [
          Channel(id: 'ch_1', name: 'C', type: ChannelType.dp1),
        ],
        works: [
          PlaylistItem(id: 'wk_artist_1', kind: PlaylistItemKind.dp1Item),
          PlaylistItem(id: 'wk_1', kind: PlaylistItemKind.dp1Item),
        ],
        artistMatchedWorkIds: {'wk_artist_1'},
      );

      expect(
        availableTypesFromResults(results),
        [
          SearchFilterType.playlists,
          SearchFilterType.channels,
          SearchFilterType.artists,
          SearchFilterType.works,
        ],
      );
    });
  });

  group('selectInitialType', () {
    test('returns null when available is empty', () {
      expect(
        selectInitialType(
          available: const [],
          current: SearchFilterType.works,
        ),
        isNull,
      );
    });

    test('keeps current when it is available', () {
      expect(
        selectInitialType(
          available: const [
            SearchFilterType.playlists,
            SearchFilterType.channels,
          ],
          current: SearchFilterType.channels,
        ),
        SearchFilterType.channels,
      );
    });

    test('falls back to first available when current is not available', () {
      expect(
        selectInitialType(
          available: const [
            SearchFilterType.playlists,
            SearchFilterType.channels,
          ],
          current: SearchFilterType.works,
        ),
        SearchFilterType.playlists,
      );
    });
  });

  group('filterResultsByType', () {
    const base = SearchResults(
      playlists: [
        Playlist(id: 'pl_1', name: 'P', type: PlaylistType.dp1),
      ],
      channels: [
        Channel(id: 'ch_1', name: 'C', type: ChannelType.dp1),
      ],
      works: [
        PlaylistItem(id: 'wk_artist_1', kind: PlaylistItemKind.dp1Item),
        PlaylistItem(id: 'wk_1', kind: PlaylistItemKind.dp1Item),
      ],
      artistMatchedWorkIds: {'wk_artist_1'},
    );

    test('keeps only channels for channels type', () {
      final filtered = filterResultsByType(base, SearchFilterType.channels);
      expect(filtered.channels, isNotEmpty);
      expect(filtered.playlists, isEmpty);
      expect(filtered.artistWorks, isEmpty);
      expect(filtered.works, isEmpty);
    });

    test('keeps only playlists for playlists type', () {
      final filtered = filterResultsByType(base, SearchFilterType.playlists);
      expect(filtered.channels, isEmpty);
      expect(filtered.playlists, isNotEmpty);
      expect(filtered.artistWorks, isEmpty);
      expect(filtered.works, isEmpty);
    });

    test('keeps only artist-matched works for artists type', () {
      final filtered = filterResultsByType(base, SearchFilterType.artists);
      expect(filtered.channels, isEmpty);
      expect(filtered.playlists, isEmpty);
      expect(filtered.artistWorks, isNotEmpty);
      expect(filtered.works, isNotEmpty);
    });

    test('keeps only works for works type', () {
      final filtered = filterResultsByType(base, SearchFilterType.works);
      expect(filtered.channels, isEmpty);
      expect(filtered.playlists, isEmpty);
      expect(filtered.artistWorks, isEmpty);
      expect(filtered.works, isNotEmpty);
    });
  });

  group('sortSearchResults', () {
    final channelA = Channel(
      id: 'ch_a',
      name: 'Gamma',
      type: ChannelType.dp1,
      createdAt: DateTime(2024),
      updatedAt: DateTime(2024, 1, 2),
    );

    final channelB = Channel(
      id: 'ch_b',
      name: 'Alpha',
      type: ChannelType.dp1,
      createdAt: DateTime(2024, 1, 3),
    );

    final playlistA = Playlist(
      id: 'pl_a',
      name: 'Zeta',
      type: PlaylistType.dp1,
      createdAt: DateTime(2024),
    );

    final playlistB = Playlist(
      id: 'pl_b',
      name: 'Beta',
      type: PlaylistType.dp1,
      createdAt: DateTime(2024, 1, 5),
      updatedAt: DateTime(2024, 1, 4),
    );

    final workA = PlaylistItem(
      id: 'wk_a',
      kind: PlaylistItemKind.dp1Item,
      title: 'banana',
      updatedAt: DateTime(2024, 1, 2),
    );

    final workB = PlaylistItem(
      id: 'wk_b',
      kind: PlaylistItemKind.dp1Item,
      title: 'Apple',
      updatedAt: DateTime(2024, 1, 5),
    );

    final unsorted = SearchResults(
      channels: [channelA, channelB],
      playlists: [playlistA, playlistB],
      works: [workA, workB],
      artistMatchedWorkIds: const <String>{},
    );

    test('keeps relevance order unchanged', () {
      final sorted = sortSearchResults(unsorted, SearchSortOrder.relevance);

      expect(sorted.channels.map((c) => c.id), ['ch_a', 'ch_b']);
      expect(sorted.playlists.map((p) => p.id), ['pl_a', 'pl_b']);
      expect(sorted.works.map((w) => w.id), ['wk_a', 'wk_b']);
    });

    test('sorts all result groups A to Z', () {
      final sorted = sortSearchResults(unsorted, SearchSortOrder.aToZ);

      expect(sorted.channels.map((c) => c.id), ['ch_b', 'ch_a']);
      expect(sorted.playlists.map((p) => p.id), ['pl_b', 'pl_a']);
      expect(sorted.works.map((w) => w.id), ['wk_b', 'wk_a']);
    });

    test('sorts all result groups by recent first', () {
      final sorted = sortSearchResults(unsorted, SearchSortOrder.recent);

      expect(sorted.channels.map((c) => c.id), ['ch_b', 'ch_a']);
      expect(sorted.playlists.map((p) => p.id), ['pl_b', 'pl_a']);
      expect(sorted.works.map((w) => w.id), ['wk_b', 'wk_a']);
    });
  });

  group('filterSearchResults', () {
    final now = DateTime(2024, 2);

    final base = SearchResults(
      channels: [
        Channel(
          id: 'ch_dp1',
          name: 'DP1 Channel',
          type: ChannelType.dp1,
          createdAt: DateTime(2023, 12, 12),
          updatedAt: DateTime(2024, 1, 20),
        ),
        Channel(
          id: 'ch_local',
          name: 'Personal Channel',
          type: ChannelType.localVirtual,
          createdAt: DateTime(2023, 11),
        ),
      ],
      playlists: [
        Playlist(
          id: 'pl_dp1',
          name: 'DP1 Playlist',
          type: PlaylistType.dp1,
          createdAt: DateTime(2023, 12),
          updatedAt: DateTime(2024, 1, 5),
        ),
        Playlist(
          id: 'pl_personal',
          name: 'Personal Playlist',
          type: PlaylistType.addressBased,
          createdAt: DateTime(2023, 11),
        ),
      ],
      works: [
        PlaylistItem(
          id: 'wk_dp1',
          kind: PlaylistItemKind.dp1Item,
          title: 'Work One',
          updatedAt: DateTime(2024, 1, 24),
        ),
        PlaylistItem(
          id: 'wk_dp2',
          kind: PlaylistItemKind.indexerToken,
          title: 'Work Two',
          updatedAt: DateTime(2023, 10),
        ),
      ],
      artistMatchedWorkIds: {'wk_dp1'},
    );

    test('filters to only DP1 source for channels and playlists', () {
      final filtered = filterSearchResults(
        base,
        sourceFilter: SearchSourceFilter.dp1,
      );

      expect(filtered.channels.map((c) => c.id), ['ch_dp1']);
      expect(filtered.playlists.map((p) => p.id), ['pl_dp1']);
      expect(filtered.works.map((w) => w.id), ['wk_dp1', 'wk_dp2']);
    });

    test('filters to only personal source for channels and playlists', () {
      final filtered = filterSearchResults(
        base,
        sourceFilter: SearchSourceFilter.personal,
      );

      expect(filtered.channels.map((c) => c.id), ['ch_local']);
      expect(filtered.playlists.map((p) => p.id), ['pl_personal']);
      expect(filtered.works, isEmpty);
    });

    test('filters by date buckets deterministically', () {
      final recent = SearchResults(
        channels: [
          Channel(
            id: 'ch_recent',
            name: 'Recent',
            type: ChannelType.dp1,
            updatedAt: DateTime(2024, 1, 30),
          ),
          Channel(
            id: 'ch_old',
            name: 'Old',
            type: ChannelType.dp1,
            updatedAt: DateTime(2022, 12),
          ),
        ],
        playlists: [
          Playlist(
            id: 'pl_recent',
            name: 'Recent',
            type: PlaylistType.dp1,
            updatedAt: DateTime(2024, 1, 26),
          ),
          Playlist(
            id: 'pl_old',
            name: 'Old',
            type: PlaylistType.dp1,
            updatedAt: DateTime(2022, 12, 2),
          ),
        ],
        works: [
          PlaylistItem(
            id: 'wk_recent',
            kind: PlaylistItemKind.dp1Item,
            title: 'Recent',
            updatedAt: DateTime(2024, 1, 27),
          ),
          PlaylistItem(
            id: 'wk_very_old',
            kind: PlaylistItemKind.dp1Item,
            title: 'Very Old',
            updatedAt: DateTime(2022, 11),
          ),
        ],
        artistMatchedWorkIds: {'wk_recent'},
      );

      final lastWeek = filterSearchResults(
        recent,
        dateFilter: SearchDateFilter.lastWeek,
        now: () => now,
      );

      expect(lastWeek.channels.map((c) => c.id), ['ch_recent']);
      expect(lastWeek.playlists.map((p) => p.id), ['pl_recent']);
      expect(lastWeek.works.map((w) => w.id), ['wk_recent']);

      final older = filterSearchResults(
        recent,
        dateFilter: SearchDateFilter.older,
        now: () => now,
      );

      expect(older.channels.map((c) => c.id), ['ch_old']);
      expect(older.playlists.map((p) => p.id), ['pl_old']);
      expect(older.works.map((w) => w.id), ['wk_very_old']);
    });

    test('applies source and date filters together', () {
      final reference = DateTime(2024, 2);

      final mixed = SearchResults(
        channels: [
          Channel(
            id: 'ch_recent_dp1',
            name: 'Recent DP1',
            type: ChannelType.dp1,
            updatedAt: DateTime(2024, 1, 30),
          ),
          Channel(
            id: 'ch_recent_personal',
            name: 'Recent Personal',
            type: ChannelType.localVirtual,
            updatedAt: DateTime(2024, 1, 30),
          ),
          Channel(
            id: 'ch_old_dp1',
            name: 'Old DP1',
            type: ChannelType.dp1,
            updatedAt: DateTime(2023),
          ),
        ],
        playlists: [
          Playlist(
            id: 'pl_recent_dp1',
            name: 'Recent DP1',
            type: PlaylistType.dp1,
            updatedAt: DateTime(2024, 1, 30),
          ),
          Playlist(
            id: 'pl_recent_personal',
            name: 'Recent Personal',
            type: PlaylistType.addressBased,
            updatedAt: DateTime(2024, 1, 30),
          ),
          Playlist(
            id: 'pl_old_dp1',
            name: 'Old DP1',
            type: PlaylistType.dp1,
            updatedAt: DateTime(2023),
          ),
        ],
        works: [
          PlaylistItem(
            id: 'wk_recent_dp1',
            kind: PlaylistItemKind.dp1Item,
            title: 'Recent DP1 Work',
            updatedAt: DateTime(2024, 1, 30),
          ),
          PlaylistItem(
            id: 'wk_recent_local',
            kind: PlaylistItemKind.indexerToken,
            title: 'Recent Local Work',
            updatedAt: DateTime(2024, 1, 30),
          ),
        ],
        artistMatchedWorkIds: {'wk_recent_dp1'},
      );

      final filtered = filterSearchResults(
        mixed,
        sourceFilter: SearchSourceFilter.dp1,
        dateFilter: SearchDateFilter.lastWeek,
        now: () => reference,
      );

      expect(filtered.channels.map((c) => c.id), ['ch_recent_dp1']);
      expect(filtered.playlists.map((p) => p.id), ['pl_recent_dp1']);
      expect(filtered.works.map((w) => w.id), [
        'wk_recent_dp1',
        'wk_recent_local',
      ]);
    });
  });
}
