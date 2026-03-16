import 'package:app/design/content_rhythm.dart';
import 'package:app/design/layout_constants.dart';
import 'package:app/domain/models/playlist_item.dart';
import 'package:app/widgets/now_displaying_bar/display_item.dart';
import 'package:flutter/material.dart';

/// Display item list for expanded now playing bar.
///
/// Matches old repo DisplayItemList structure.
/// Simplified for ff-app: takes items directly (no PlaylistDetailsBloc).
class DisplayItemList extends StatelessWidget {
  const DisplayItemList({
    required this.items,
    required this.selectedIndex,
    this.onItemTap,
    this.scrollController,
    super.key,
  });

  final List<PlaylistItem> items;
  final int selectedIndex;
  final void Function(int index)? onItemTap;
  final ScrollController? scrollController;
  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return _emptyView(context);
    }

    return CustomScrollView(
      controller: scrollController,
      shrinkWrap: true,
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              final item = items[index];
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  NowDisplayingDisplayItem(
                    item: item,
                    isPlaying: index == selectedIndex,
                    isInExpandedView: true,
                    onTap: () {
                      if (index != selectedIndex && onItemTap != null) {
                        onItemTap!(index);
                      }
                    },
                  ),
                  if (index != items.length - 1)
                    SizedBox(
                      height:
                          LayoutConstants.nowPlayingBarBottomDisplayItemListGap,
                    ),
                ],
              );
            },
            childCount: items.length,
          ),
        ),
      ],
    );
  }

  Widget _emptyView(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: ContentRhythm.horizontalRail,
        vertical: LayoutConstants.space16,
      ),
      child: Text(
        'Playlist empty',
        style: ContentRhythm.supporting(context).copyWith(color: Colors.white),
      ),
    );
  }
}
