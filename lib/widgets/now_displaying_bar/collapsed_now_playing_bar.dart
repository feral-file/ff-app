import 'package:app/design/build/primitives.dart';
import 'package:app/design/layout_constants.dart';
import 'package:app/domain/models/now_displaying_object.dart';
import 'package:flutter/material.dart';

import 'display_item.dart';
import 'header_with_animated_below.dart';
import 'now_displaying_quick_setting_view.dart';
import 'sleep_mode_indicator.dart';
import 'top_line.dart';

/// Collapsed now playing bar matching old repo structure.
///
/// Container > HeaderWithAnimated > header: Column(TopLine, Row(DisplayItem, SleepModeIndicator))
/// child: NowDisplayingQuickSettingView
class CollapsedNowPlayingBar extends StatefulWidget {
  const CollapsedNowPlayingBar({
    required this.playingObject,
    this.onToggle,
    this.onTap,
    super.key,
  });

  final DP1NowDisplayingObject playingObject;
  final void Function()? onToggle;
  final VoidCallback? onTap;

  @override
  State<CollapsedNowPlayingBar> createState() => _CollapsedNowPlayingBarState();
}

class _CollapsedNowPlayingBarState extends State<CollapsedNowPlayingBar>
    with SingleTickerProviderStateMixin {
  @override
  void initState() {
    super.initState();
  }

  @override
  void didUpdateWidget(CollapsedNowPlayingBar oldWidget) {
    super.didUpdateWidget(oldWidget);
  }

  @override
  void dispose() {
    super.dispose();
  }

  DP1NowDisplayingObject get playingObject => widget.playingObject;

  @override
  Widget build(BuildContext context) {
    final content = Container(
      padding: EdgeInsets.only(
        top: LayoutConstants.nowPlayingBarPaddingTop,
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
      child: HeaderWithAnimated(
        header: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            const TopLine(),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: NowDisplayingDisplayItem(
                    item: playingObject.currentItem,
                    deviceName: playingObject.connectedDevice.name,
                    isPlaying: true,
                    isInExpandedView: false,
                    onTap: null,
                  ),
                ),
                SizedBox(width: LayoutConstants.space4),
                const SleepModeIndicator(
                  isSleeping: false,
                ),
              ],
            ),
          ],
        ),
        isExpandedListenable: ValueNotifier(false),
        child: const NowDisplayingQuickSettingView(),
      ),
    );

    if (widget.onTap != null) {
      return GestureDetector(
        onTap: widget.onTap,
        child: content,
      );
    }
    return content;
  }
}
