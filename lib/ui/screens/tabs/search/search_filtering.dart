import 'package:app/app/providers/search_provider.dart';
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
