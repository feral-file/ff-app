import 'package:app/design/app_typography.dart';
import 'package:app/design/layout_constants.dart';
import 'package:flutter/material.dart';

/// Tabs for the home index header.
enum HomeIndexHeaderTab {
  playlists('Playlists'),
  channels('Channels'),
  works('Works');

  const HomeIndexHeaderTab(this.label);
  final String label;
}

/// Home index header - tab navigation matching the old app layout.
class HomeIndexHeader extends StatelessWidget {
  const HomeIndexHeader({
    required this.selectedTab,
    required this.onTabChanged,
    super.key,
  });

  final HomeIndexHeaderTab selectedTab;
  final ValueChanged<HomeIndexHeaderTab> onTabChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: LayoutConstants.space3),
      child: Row(
        children: HomeIndexHeaderTab.values.map((tab) {
          final isSelected = tab == selectedTab;
          return GestureDetector(
            onTap: () => onTabChanged(tab),
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: EdgeInsets.only(right: LayoutConstants.space3),
              child: Text(
                tab.label,
                style: isSelected
                    ? AppTypography.body(context).white
                    : AppTypography.body(context).grey,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

