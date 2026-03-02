import 'package:app/design/app_typography.dart';
import 'package:flutter/widgets.dart';

/// Search filter types supported by the app search UI.
///
/// This is a UI-scoped model (not a domain concept) and intentionally matches
/// the old app's SearchPage type selector labels.
enum SearchFilterType {
  /// Show channel results.
  channels,

  /// Show playlist results.
  playlists,

  /// Show work results.
  works,
}

/// Presentation helpers for [SearchFilterType].
extension SearchFilterTypeX on SearchFilterType {
  /// Human-friendly label shown in the filter bar.
  String get label {
    switch (this) {
      case SearchFilterType.channels:
        return 'Channels';
      case SearchFilterType.playlists:
        return 'Playlists';
      case SearchFilterType.works:
        return 'Works';
    }
  }
}

/// Sort options for the search UI.
///
/// Kept for parity with the old app UI; current repo search results are backed
/// by local DB search and may not support multiple sort orders yet.
enum SearchSortOrder {
  /// Sort by relevance (default).
  relevance,

  /// Sort alphabetically.
  aToZ,

  /// Sort by recency.
  recent,
}

/// Presentation helpers for [SearchSortOrder].
extension SearchSortOrderX on SearchSortOrder {
  /// Human-friendly label shown in the filter bar.
  String get label {
    switch (this) {
      case SearchSortOrder.relevance:
        return 'Relevance';
      case SearchSortOrder.aToZ:
        return 'A to Z';
      case SearchSortOrder.recent:
        return 'Recent';
    }
  }

  /// Text style used for sort UI labels.
  TextStyle textStyle(BuildContext context) {
    return AppTypography.body(context).white;
  }
}
