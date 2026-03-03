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
  });

  /// Matching channels.
  final List<Channel> channels;

  /// Matching playlists.
  final List<Playlist> playlists;

  /// Matching works.
  final List<PlaylistItem> works;

  /// Whether there are any results.
  bool get isEmpty => channels.isEmpty && playlists.isEmpty && works.isEmpty;

  /// Total number of results.
  int get totalCount => channels.length + playlists.length + works.length;
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
    );
  }

  try {
    final databaseService = ref.watch(databaseServiceProvider);
    final results = await Future.wait([
      databaseService.searchChannelsByTitle(query),
      databaseService.searchPlaylistsByTitle(query),
      databaseService.searchItemsByTitle(query, limit: 40),
    ]);

    final matchingChannels = results[0] as List<Channel>;
    final matchingPlaylists = results[1] as List<Playlist>;
    final matchingWorks = results[2] as List<PlaylistItem>;

    return SearchResults(
      channels: matchingChannels,
      playlists: matchingPlaylists,
      works: matchingWorks,
    );
  } catch (e, stack) {
    log.severe('Search failed', e, stack);
    rethrow;
  }
});
