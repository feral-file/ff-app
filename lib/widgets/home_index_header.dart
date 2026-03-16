import 'package:app/app/patrol/gold_path_patrol_keys.dart';
import 'package:app/design/content_rhythm.dart';
import 'package:flutter/material.dart';

/// Tabs for the home index header.
enum HomeIndexHeaderTab {
  /// Playlist browsing surface.
  playlists('Playlists'),

  /// Channel browsing surface.
  channels('Channels'),

  /// Work browsing surface.
  works('Works')
  ;

  /// Creates a home header tab descriptor.
  const HomeIndexHeaderTab(this.label);

  /// Visible tab label in the home header.
  final String label;
}

/// Home index header - tab navigation matching the old app layout.
class HomeIndexHeader extends StatelessWidget {
  /// Creates the home tab header.
  const HomeIndexHeader({
    required this.selectedTab,
    required this.onTabChanged,
    super.key,
  });

  /// Currently selected home tab.
  final HomeIndexHeaderTab selectedTab;

  /// Callback fired when the user selects a different tab.
  final ValueChanged<HomeIndexHeaderTab> onTabChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: ContentRhythm.horizontalRail),
      child: Align(
        alignment: Alignment.centerLeft,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: HomeIndexHeaderTab.values.map((tab) {
              final isSelected = tab == selectedTab;
              return GestureDetector(
                key: switch (tab) {
                  HomeIndexHeaderTab.playlists =>
                    GoldPathPatrolKeys.playlistsTab,
                  HomeIndexHeaderTab.channels => GoldPathPatrolKeys.channelsTab,
                  _ => null,
                },
                onTap: () => onTabChanged(tab),
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: EdgeInsets.only(right: ContentRhythm.tabGap),
                  child: Text(
                    tab.label,
                    style: ContentRhythm.tabLabel(
                      context,
                      selected: isSelected,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}
