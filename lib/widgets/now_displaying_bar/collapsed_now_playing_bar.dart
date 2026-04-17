import 'package:app/app/providers/ff1_wifi_providers.dart';
import 'package:app/design/build/primitives.dart';
import 'package:app/design/layout_constants.dart';
import 'package:app/domain/models/now_displaying_object.dart';
import 'package:app/widgets/now_displaying_bar/display_item.dart';
import 'package:app/widgets/now_displaying_bar/header_with_animated_below.dart';
import 'package:app/widgets/now_displaying_bar/loop_button.dart';
import 'package:app/widgets/now_displaying_bar/now_displaying_quick_setting_view.dart';
import 'package:app/widgets/now_displaying_bar/shuffle_button.dart';
import 'package:app/widgets/now_displaying_bar/sleep_mode_indicator.dart';
import 'package:app/widgets/now_displaying_bar/top_line.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
/// Container > HeaderWithAnimated > header:
///   Column(TopLine, Row(DisplayItem, Shuffle, Loop, SleepMode))
/// child: NowDisplayingQuickSettingView
class CollapsedNowPlayingBar extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final supportsShuffle = ref.watch(ff1SupportsShuffleProvider);
    final supportsLoop = ref.watch(ff1SupportsLoopProvider);
    // [playingObject.items] is the visible window only; FF1 status carries the
    // full playlist length for shuffle/repeat semantics.
    final playerStatus = ref.watch(ff1CurrentPlayerStatusProvider);
    final playlistWorkCount =
        playerStatus?.items?.length ?? playingObject.items.length;
    final showPlaylistControls = playlistWorkCount > 1;

    return Container(
      padding: EdgeInsets.only(
        top: LayoutConstants.nowPlayingBarPaddingTop,
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
                    onTap: onTap,
                    child: NowDisplayingDisplayItem(
                      item: playingObject.currentItem,
                      deviceName: playingObject.connectedDevice.name,
                      isPlaying: true,
                    ),
                  ),
                ),
                if (showPlaylistControls && supportsShuffle)
                  const ShuffleButton(),
                if (showPlaylistControls && supportsLoop) const LoopButton(),
                const SleepModeIndicator(isSleeping: false),
              ],
            ),
          ],
        ),
        isExpandedListenable: ValueNotifier(false),
        child: const NowDisplayingQuickSettingView(),
      ),
    );
  }
}
