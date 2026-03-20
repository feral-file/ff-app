import 'package:app/domain/extensions/playlist_item_ext.dart';
import 'package:app/domain/models/channel.dart';
import 'package:app/domain/models/playlist.dart';
import 'package:app/domain/models/playlist_item.dart';
import 'package:app/infra/database/database_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';

/// Search results container.
class SearchResults {
  /// Creates SearchResults.
  const SearchResults({
    required this.channels,
    required this.playlists,
    required this.works,
    required this.artistMatchedWorkIds,
  });

  /// Matching channels.
  final List<Channel> channels;

  /// Matching playlists.
  final List<Playlist> playlists;

  /// Matching works.
  final List<PlaylistItem> works;

  /// Work ids whose artist names match the query.
  final Set<String> artistMatchedWorkIds;

  /// Matching works where artist names match the query.
  List<PlaylistItem> get artistWorks => works
      .where((work) => artistMatchedWorkIds.contains(work.id))
      .toList(growable: false);

  /// Whether there are any results.
  bool get isEmpty => channels.isEmpty && playlists.isEmpty && works.isEmpty;

  /// Total number of results.
  int get totalCount => channels.length + playlists.length + works.length;
}

/// Search result kind for suggestion/list navigation.
enum SearchResultKind {
  /// Search result is a channel.
  channel,

  /// Search result is a playlist.
  playlist,

  /// Search result is a work/item.
  work,
}

/// Lightweight result item surfaced by suggestion/provider responses.
class SearchSuggestion {
  /// Creates a [SearchSuggestion].
  const SearchSuggestion({
    required this.id,
    required this.title,
    required this.kind,
    this.subtitle,
  });

  /// Destination model id.
  final String id;

  /// Main display title.
  final String title;

  /// Result kind used for routing.
  final SearchResultKind kind;

  /// Optional metadata shown under the title.
  final String? subtitle;
}

/// Notifier for search query state.
class SearchQueryNotifier extends Notifier<String> {
  @override
  String build() => '';

  /// Update the search query.
  void setQuery(String query) {
    state = query;
  }

  /// Clear the search query.
  void clear() {
    state = '';
  }
}

/// Search query state provider.
final searchQueryProvider = NotifierProvider<SearchQueryNotifier, String>(
  SearchQueryNotifier.new,
);

/// Notifier for live search input state.
class SearchInputQueryNotifier extends Notifier<String> {
  @override
  String build() => '';

  /// Update the raw search input.
  void setQuery(String query) {
    state = query;
  }

  /// Clear the raw search input.
  void clear() {
    state = '';
  }
}

/// Search input provider used for live suggestions.
final searchInputQueryProvider =
    NotifierProvider<SearchInputQueryNotifier, String>(
      SearchInputQueryNotifier.new,
    );

/// Suggestion results provider using debounced input query.
final FutureProvider<List<SearchSuggestion>> searchSuggestionsProvider =
    FutureProvider.autoDispose<List<SearchSuggestion>>((
      ref,
    ) async {
      final query = ref.watch(searchInputQueryProvider).trim();
      final log = Logger('SearchSuggestionsProvider');

      if (query.length < 2) {
        return const <SearchSuggestion>[];
      }

      // Lightweight debounce to avoid querying local DB on every keystroke.
      await Future<void>.delayed(const Duration(milliseconds: 180));

      // Ignore stale queries after debounce.
      if (query != ref.read(searchInputQueryProvider).trim()) {
        return const <SearchSuggestion>[];
      }

      try {
        final databaseService = ref.watch(databaseServiceProvider);
        final result = await Future.wait([
          databaseService.searchChannels(query, limit: 4),
          databaseService.searchPlaylists(query, limit: 4),
          databaseService.searchItems(query, limit: 6),
        ]);

        final channels = result[0] as List<Channel>;
        final playlists = result[1] as List<Playlist>;
        final works = result[2] as List<PlaylistItem>;

        final suggestions = <SearchSuggestion>[];
        for (final item in channels) {
          suggestions.add(
            SearchSuggestion(
              id: item.id,
              title: item.name,
              subtitle: 'Channel',
              kind: SearchResultKind.channel,
            ),
          );
        }

        for (final item in playlists) {
          suggestions.add(
            SearchSuggestion(
              id: item.id,
              title: item.name,
              subtitle: 'Playlist',
              kind: SearchResultKind.playlist,
            ),
          );
        }

        for (final item in works) {
          final artistName = item.artistName;
          suggestions.add(
            SearchSuggestion(
              id: item.id,
              title: item.title ?? '',
              subtitle: artistName.isEmpty ? 'Work' : 'Work · $artistName',
              kind: SearchResultKind.work,
            ),
          );
        }

        return suggestions;
      } catch (e, stack) {
        log.severe('Search suggestions failed', e, stack);
        rethrow;
      }
    });

/// Search results provider.
/// Automatically searches when query changes.
final searchResultsProvider = FutureProvider<SearchResults>((ref) async {
  final query = ref.watch(searchQueryProvider);
  final log = Logger('SearchProvider');

  if (query.isEmpty) {
    return const SearchResults(
      channels: [],
      playlists: [],
      works: [],
      artistMatchedWorkIds: <String>{},
    );
  }

  try {
    final databaseService = ref.watch(databaseServiceProvider);
    final baseResults = await Future.wait([
      databaseService.searchChannels(query),
      databaseService.searchPlaylists(query),
      databaseService.searchItems(query, limit: 40),
    ]);

    final matchingChannels = baseResults[0] as List<Channel>;
    final matchingPlaylists = baseResults[1] as List<Playlist>;
    final matchingWorks = baseResults[2] as List<PlaylistItem>;
    final matchingWorkIds = matchingWorks.map((work) => work.id).toSet();
    final matchingArtistWorkIds = await databaseService
        .searchArtistMatchedItemIds(
          query,
          candidateIds: matchingWorkIds,
          limit: matchingWorkIds.length,
        );

    return SearchResults(
      channels: matchingChannels,
      playlists: matchingPlaylists,
      works: matchingWorks,
      artistMatchedWorkIds: matchingArtistWorkIds,
    );
  } catch (e, stack) {
    log.severe('Search failed', e, stack);
    rethrow;
  }
});
