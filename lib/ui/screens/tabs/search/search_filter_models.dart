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

  /// Show artist-matched work results.
  artists,

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
      case SearchFilterType.artists:
        return 'Artists';
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

/// Source facet for search results.
enum SearchSourceFilter {
  /// Show all result sources.
  all,

  /// Show only DP1 curated/DP1 channel and playlist results.
  dp1,

  /// Show only address-based/personal results.
  personal,
}

/// Date bucket facet for search results.
enum SearchDateFilter {
  /// Show all dates.
  all,

  /// Show only results updated in the last week.
  lastWeek,

  /// Show only results updated in the last month.
  lastMonth,

  /// Show only results updated in the last year.
  lastYear,

  /// Show only older results.
  older,
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

/// Presentation helpers for [SearchSourceFilter].
extension SearchSourceFilterX on SearchSourceFilter {
  /// Human-friendly label shown in the filter bar.
  String get label {
    switch (this) {
      case SearchSourceFilter.all:
        return 'All Sources';
      case SearchSourceFilter.dp1:
        return 'DP-1';
      case SearchSourceFilter.personal:
        return 'Personal';
    }
  }
}

/// Presentation helpers for [SearchDateFilter].
extension SearchDateFilterX on SearchDateFilter {
  /// Human-friendly label shown in the filter bar.
  String get label {
    switch (this) {
      case SearchDateFilter.all:
        return 'All Time';
      case SearchDateFilter.lastWeek:
        return 'Last Week';
      case SearchDateFilter.lastMonth:
        return 'Last Month';
      case SearchDateFilter.lastYear:
        return 'Last Year';
      case SearchDateFilter.older:
        return 'Older';
    }
  }
}
