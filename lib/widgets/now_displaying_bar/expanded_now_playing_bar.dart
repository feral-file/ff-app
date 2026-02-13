import 'package:app/design/build/primitives.dart';
import 'package:app/design/layout_constants.dart';
import 'package:app/domain/models/now_displaying_object.dart';
import 'package:flutter/material.dart';

import 'device_sub_nav.dart';
import 'display_item_list.dart';
import 'top_line.dart';

/// Expanded now playing bar matching old repo structure.
///
/// Container > Column > TopLine, SizedBox, DeviceSubNav, SizedBox, Expanded(DisplayItemList)
class ExpandedNowPlayingBar extends StatelessWidget {
  const ExpandedNowPlayingBar({
    required this.playingObject,
    this.onItemTap,
    super.key,
  });

  final DP1NowDisplayingObject playingObject;
  final void Function(int index)? onItemTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: LayoutConstants.nowPlayingBarExpandedHeight,
      ),
      padding: EdgeInsets.only(
        top: LayoutConstants.nowPlayingBarPaddingTop -
            LayoutConstants.nowPlayingBarTopLineStrokeWeight / 2,
        right: LayoutConstants.nowPlayingBarPaddingHorizontal,
        bottom: LayoutConstants.nowPlayingBarPaddingBottom,
        left: LayoutConstants.nowPlayingBarPaddingHorizontal,
      ),
      decoration: BoxDecoration(
        color: PrimitivesTokens.colorsBlack,
        borderRadius: BorderRadius.circular(
          LayoutConstants.nowPlayingBarCornerRadius,
        ),
      ),
      child: Column(
        children: [
          const TopLine(),
          SizedBox(
            height: LayoutConstants.nowPlayingBarBottomVerticalGap,
          ),
          const DeviceSubNav(),
          SizedBox(
            height: LayoutConstants.nowPlayingBarBottomVerticalGap,
          ),
          Expanded(
            child: DisplayItemList(
              items: playingObject.items,
              selectedIndex: playingObject.index,
              onItemTap: onItemTap,
            ),
          ),
        ],
      ),
    );
  }
}
