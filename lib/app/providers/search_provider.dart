import 'package:app/app/providers/mutations.dart';
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
    final lowerQuery = query.toLowerCase();

    // Search channels
    final allChannels = await databaseService.getChannels();
    final matchingChannels = allChannels.where((Channel channel) {
      return channel.name.toLowerCase().contains(lowerQuery) ||
          (channel.description?.toLowerCase().contains(lowerQuery) ?? false);
    }).toList();

    // Search playlists
    final allPlaylists = await databaseService.getAllPlaylists();
    final matchingPlaylists = allPlaylists.where((Playlist playlist) {
      return playlist.name.toLowerCase().contains(lowerQuery) ||
          (playlist.description?.toLowerCase().contains(lowerQuery) ?? false);
    }).toList();

    // Search works
    final allWorks = await databaseService.getAllItems();
    final matchingWorks = allWorks.where((PlaylistItem work) {
      return work.title?.toLowerCase().contains(lowerQuery) ??
          false ||
              (work.subtitle?.toLowerCase().contains(lowerQuery) ?? false) ||
              (work.artistName.toLowerCase().contains(lowerQuery));
    }).toList();

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

/// Mutation for tracking search operations.
final performSearchMutationProvider =
    NotifierProvider<
      MutationNotifier<SearchResults>,
      MutationState<SearchResults>
    >(
      MutationNotifier.new,
    );
