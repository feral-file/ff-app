import 'package:app/app/providers/search_provider.dart';
import 'package:app/domain/models/channel.dart';
import 'package:app/domain/models/playlist.dart';
import 'package:app/ui/screens/tabs/search/search_filter_models.dart';

/// Returns the list of filter types that have results.
///
/// This intentionally mirrors the old app behavior: the type selector is only
/// shown when there is at least one non-empty type.
List<SearchFilterType> availableTypesFromResults(SearchResults results) {
  final available = <SearchFilterType>[];
  // Match old app type ordering (playlists first).
  if (results.playlists.isNotEmpty) {
    available.add(SearchFilterType.playlists);
  }
  if (results.channels.isNotEmpty) {
    available.add(SearchFilterType.channels);
  }
  if (results.works.isNotEmpty) {
    available.add(SearchFilterType.works);
  }
  return available;
}

/// Selects a safe current filter type given availability.
///
/// If [current] is not present in [available], this falls back to the first
/// available type. Returns null if [available] is empty.
SearchFilterType? selectInitialType({
  required List<SearchFilterType> available,
  SearchFilterType? current,
}) {
  if (available.isEmpty) {
    return null;
  }
  if (current != null && available.contains(current)) {
    return current;
  }
  return available.first;
}

/// Returns a results payload filtered to a single [type].
SearchResults filterResultsByType(
  SearchResults results,
  SearchFilterType type,
) {
  switch (type) {
    case SearchFilterType.channels:
      return SearchResults(
        channels: results.channels,
        playlists: const [],
        works: const [],
      );
    case SearchFilterType.playlists:
      return SearchResults(
        channels: const [],
        playlists: results.playlists,
        works: const [],
      );
    case SearchFilterType.works:
      return SearchResults(
        channels: const [],
        playlists: const [],
        works: results.works,
      );
  }
}

/// Returns results sorted according to [order].
SearchResults sortSearchResults(SearchResults results, SearchSortOrder order) {
  final sortedChannels = [...results.channels];
  final sortedPlaylists = [...results.playlists];
  final sortedWorks = [...results.works];

  switch (order) {
    case SearchSortOrder.relevance:
      return results;
    case SearchSortOrder.aToZ:
      sortedChannels.sort(
        (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
      );
      sortedPlaylists.sort(
        (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
      );
      sortedWorks.sort(
        (a, b) => (a.title ?? '').toLowerCase().compareTo(
          (b.title ?? '').toLowerCase(),
        ),
      );
      return SearchResults(
        channels: sortedChannels,
        playlists: sortedPlaylists,
        works: sortedWorks,
      );
    case SearchSortOrder.recent:
      sortedChannels.sort(
        (a, b) => (b.updatedAt ?? b.createdAt ?? DateTime(0)).compareTo(
          a.updatedAt ?? a.createdAt ?? DateTime(0),
        ),
      );
      sortedPlaylists.sort(
        (a, b) => (b.updatedAt ?? b.createdAt ?? DateTime(0)).compareTo(
          a.updatedAt ?? a.createdAt ?? DateTime(0),
        ),
      );
      sortedWorks.sort(
        (a, b) =>
            (b.updatedAt ?? DateTime(0)).compareTo(a.updatedAt ?? DateTime(0)),
      );
      return SearchResults(
        channels: sortedChannels,
        playlists: sortedPlaylists,
        works: sortedWorks,
      );
  }
}

/// Returns results filtered by source and date facets.
SearchResults filterSearchResults(
  SearchResults results, {
  SearchSourceFilter sourceFilter = SearchSourceFilter.all,
  SearchDateFilter dateFilter = SearchDateFilter.all,
  DateTime Function() now = DateTime.now,
}) {
  if (sourceFilter == SearchSourceFilter.all &&
      dateFilter == SearchDateFilter.all) {
    return results;
  }

  final reference = now();

  bool matchesChannelSource({
    required SearchSourceFilter source,
    required ChannelType channelType,
  }) {
    switch (source) {
      case SearchSourceFilter.all:
        return true;
      case SearchSourceFilter.dp1:
        return channelType == ChannelType.dp1;
      case SearchSourceFilter.personal:
        return channelType == ChannelType.localVirtual;
    }
  }

  bool matchesPlaylistSource({
    required SearchSourceFilter source,
    required PlaylistType playlistType,
  }) {
    switch (source) {
      case SearchSourceFilter.all:
        return true;
      case SearchSourceFilter.dp1:
        return playlistType == PlaylistType.dp1;
      case SearchSourceFilter.personal:
        return playlistType == PlaylistType.addressBased;
    }
  }

  bool isRecent({DateTime? date, required SearchDateFilter filter}) {
    if (filter == SearchDateFilter.all) {
      return true;
    }

    if (date == null) {
      return true;
    }

    switch (filter) {
      case SearchDateFilter.all:
        return true;
      case SearchDateFilter.lastWeek:
        return date.isAfter(reference.subtract(const Duration(days: 7)));
      case SearchDateFilter.lastMonth:
        return date.isAfter(reference.subtract(const Duration(days: 30)));
      case SearchDateFilter.lastYear:
        return date.isAfter(reference.subtract(const Duration(days: 365)));
      case SearchDateFilter.older:
        return date.isBefore(reference.subtract(const Duration(days: 365)));
    }
  }

  final channels = results.channels
      .where((channel) {
        final channelType = channel.type;
        final isSourceMatch = matchesChannelSource(
          source: sourceFilter,
          channelType: channelType,
        );

        return isSourceMatch &&
            isRecent(
              date: channel.updatedAt ?? channel.createdAt,
              filter: dateFilter,
            );
      })
      .toList(growable: false);

  final playlists = results.playlists
      .where((playlist) {
        final isSourceMatch = matchesPlaylistSource(
          source: sourceFilter,
          playlistType: playlist.type,
        );
        return isSourceMatch &&
            isRecent(
              date: playlist.updatedAt ?? playlist.createdAt,
              filter: dateFilter,
            );
      })
      .toList(growable: false);

  final works = results.works
      .where((work) {
        // Work sources are mixed in local DB today; show by source filter only where
        // we can infer it.
        final sourceMatches =
            sourceFilter == SearchSourceFilter.all ||
            sourceFilter == SearchSourceFilter.dp1;
        return sourceMatches &&
            isRecent(date: work.updatedAt, filter: dateFilter);
      })
      .toList(growable: false);

  return SearchResults(
    channels: channels,
    playlists: playlists,
    works: works,
  );
}
