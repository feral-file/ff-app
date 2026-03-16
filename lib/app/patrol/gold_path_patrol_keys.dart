import 'package:flutter/widgets.dart';

/// Semantic keys used by gold-path Patrol automation.
abstract final class GoldPathPatrolKeys {
  /// Home tab button that switches to the Playlists surface.
  static const playlistsTab = ValueKey<String>('gold_path.home.tab.playlists');

  /// Home tab button that switches to the Channels surface.
  static const channelsTab = ValueKey<String>('gold_path.home.tab.channels');

  /// Curated section header inside the Channels tab.
  static const curatedChannelsSection = ValueKey<String>(
    'gold_path.channels.section.curated',
  );

  /// Primary FF1 display button rendered in work and playlist details.
  static const ffDisplayButton = ValueKey<String>(
    'gold_path.ff1.display_button',
  );

  /// Tooltip play button shown the first time the FF1 display affordance
  /// appears.
  static const ffDisplayTooltipButton = ValueKey<String>(
    'gold_path.ff1.display_tooltip_button',
  );

  /// Global Now Displaying overlay card.
  static const nowDisplayingBar = ValueKey<String>(
    'gold_path.now_displaying.bar',
  );

  /// Stable channel row key for Curated channel carousels.
  static ValueKey<String> channelRow(String channelId) {
    return ValueKey<String>('gold_path.channels.row.$channelId');
  }

  /// Stable work item key scoped to a specific channel carousel row.
  static ValueKey<String> channelWork({
    required String channelId,
    required String workId,
  }) {
    return ValueKey<String>('gold_path.channels.row.$channelId.work.$workId');
  }

  /// Stable work thumbnail key for detail or shelf reuse when needed.
  static ValueKey<String> workThumbnail(String workId) {
    return ValueKey<String>('gold_path.work.thumbnail.$workId');
  }
}
