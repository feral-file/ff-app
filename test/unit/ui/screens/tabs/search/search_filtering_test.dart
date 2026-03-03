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
      const results = SearchResults(channels: [], playlists: [], works: []);
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
          PlaylistItem(id: 'wk_1', kind: PlaylistItemKind.dp1Item),
        ],
      );

      expect(
        availableTypesFromResults(results),
        [
          SearchFilterType.playlists,
          SearchFilterType.channels,
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
        PlaylistItem(id: 'wk_1', kind: PlaylistItemKind.dp1Item),
      ],
    );

    test('keeps only channels for channels type', () {
      final filtered = filterResultsByType(base, SearchFilterType.channels);
      expect(filtered.channels, isNotEmpty);
      expect(filtered.playlists, isEmpty);
      expect(filtered.works, isEmpty);
    });

    test('keeps only playlists for playlists type', () {
      final filtered = filterResultsByType(base, SearchFilterType.playlists);
      expect(filtered.channels, isEmpty);
      expect(filtered.playlists, isNotEmpty);
      expect(filtered.works, isEmpty);
    });

    test('keeps only works for works type', () {
      final filtered = filterResultsByType(base, SearchFilterType.works);
      expect(filtered.channels, isEmpty);
      expect(filtered.playlists, isEmpty);
      expect(filtered.works, isNotEmpty);
    });
  });
}
