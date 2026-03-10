import 'package:app/design/build/primitives.dart';
import 'package:app/design/layout_constants.dart';
import 'package:app/domain/models/now_displaying_object.dart';
import 'package:app/widgets/now_displaying_bar/display_item.dart';
import 'package:app/widgets/now_displaying_bar/header_with_animated_below.dart';
import 'package:app/widgets/now_displaying_bar/now_displaying_quick_setting_view.dart';
import 'package:app/widgets/now_displaying_bar/sleep_mode_indicator.dart';
import 'package:app/widgets/now_displaying_bar/top_line.dart';
import 'package:flutter/material.dart';

/// Wraps [child] with [GestureDetector] when [onTap] is non-null.
/// Used to isolate the navigate tap area from the sleep indicator tap area.
class _TapToNavigate extends StatelessWidget {
  const _TapToNavigate({
    required this.onTap,
    required this.child,
  });

  final VoidCallback? onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (onTap != null) {
      return GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: child,
      );
    }
    return child;
  }
}

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
              children: [
                Expanded(
                  child: _TapToNavigate(
                    onTap: widget.onTap,
                    child: NowDisplayingDisplayItem(
                      item: playingObject.currentItem,
                      deviceName: playingObject.connectedDevice.name,
                      isPlaying: true,
                    ),
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

    return content;
  }
}
