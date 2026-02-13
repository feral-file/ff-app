import 'package:app/app/providers/now_displaying_provider.dart';
import 'package:app/design/build/primitives.dart';
import 'package:app/design/layout_constants.dart';
import 'package:app/domain/models/now_displaying_object.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'device_sub_nav.dart';
import 'display_item_list.dart';
import 'top_line.dart';

/// Expanded now playing bar matching old repo structure.
///
/// Container > Column > TopLine, SizedBox, DeviceSubNav, SizedBox, Expanded(DisplayItemList)
/// When [scrollController] is provided, scroll position expands the now-displaying
/// window so items visible while scrolling are loaded/enriched.
class ExpandedNowPlayingBar extends ConsumerStatefulWidget {
  const ExpandedNowPlayingBar({
    required this.playingObject,
    this.onItemTap,
    super.key,
  });

  final DP1NowDisplayingObject playingObject;
  final void Function(int index)? onItemTap;

  @override
  ConsumerState<ExpandedNowPlayingBar> createState() =>
      _ExpandedNowPlayingBarState();
}

class _ExpandedNowPlayingBarState extends ConsumerState<ExpandedNowPlayingBar> {
  /// When the visible range is within this many items of the window edge,
  /// we extend the window by one page in that direction.
  static const int _edgeMarginItems = 10;

  /// One page size for extension (same as base window half-size).
  static const int _pageSize = nowDisplayingWindowHalfSize;

  void _onScroll() {
    final controller = _scrollController;
    if (!controller.hasClients) return;
    final position = controller.position;
    final totalItems = widget.playingObject.items.length;
    if (totalItems == 0) return;

    final window = ref.read(nowDisplayingWindowProvider);
    if (window == null) return;

    const headerHeight = LayoutConstants.nowDisplayingExpandedListHeaderHeight;
    const itemHeight = LayoutConstants.nowDisplayingExpandedListItemHeight;

    final pixels = position.pixels;
    final viewportHeight = position.viewportDimension;
    final listOffset = (pixels - headerHeight).clamp(0.0, double.infinity);
    final firstVisible =
        (listOffset / itemHeight).floor().clamp(0, totalItems - 1);
    final lastVisibleRaw =
        ((listOffset + viewportHeight) / itemHeight).ceil().toInt();
    final lastVisible = (lastVisibleRaw - 1).clamp(0, totalItems - 1);

    // Extend when scroll is about to reach the start or end of the current window
    // (not maxScrollExtent, since we display all items in the list).
    final nearWindowStart = firstVisible <= window.start + _edgeMarginItems;
    final nearWindowEnd = lastVisible >= window.end - 1 - _edgeMarginItems;

    if (!nearWindowStart && !nearWindowEnd) return;

    int newStart = window.start;
    int newEnd = window.end;
    if (nearWindowStart && window.start > 0) {
      newStart = (window.start - _pageSize).clamp(0, totalItems);
    }
    if (nearWindowEnd && window.end < totalItems) {
      newEnd = (window.end + _pageSize).clamp(0, totalItems);
    }
    if (newStart == window.start && newEnd == window.end) return;

    ref
        .read(nowDisplayingRequestedRangeProvider.notifier)
        .expandTo(newStart, newEnd);
  }

  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollController.addListener(_onScroll);
    // Set initial window from visible range after first layout.
    WidgetsBinding.instance.addPostFrameCallback((_) => _onScroll());
  }

  @override
  void didUpdateWidget(covariant ExpandedNowPlayingBar oldWidget) {
    super.didUpdateWidget(oldWidget);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final playingObject = widget.playingObject;
    return Container(
      constraints: BoxConstraints(
        maxHeight: LayoutConstants.nowPlayingBarExpandedHeight,
      ),
      padding: EdgeInsets.only(
        top:
            LayoutConstants.nowPlayingBarPaddingTop -
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
              onItemTap: widget.onItemTap,
              scrollController: _scrollController,
            ),
          ),
        ],
      ),
    );
  }
}
