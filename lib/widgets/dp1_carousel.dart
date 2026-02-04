import 'package:app/design/layout_constants.dart';
import 'package:app/infra/database/app_database.dart';
import 'package:app/widgets/load_more_indicator.dart';
import 'package:app/widgets/work_item_thumbnail.dart';
import 'package:flutter/material.dart';

/// DP1 Carousel - Horizontal scrollable carousel for displaying work items.
/// Uses Drift ItemData only.
class DP1Carousel extends StatefulWidget {
  /// Creates a DP1Carousel.
  const DP1Carousel({
    required this.items,
    this.onItemTap,
    this.scrollController,
    this.isLoadingMore = false,
    this.onLoadMore,
    super.key,
  });

  /// List of work items to display (Drift ItemData).
  final List<ItemData> items;

  /// Callback when an item is tapped.
  final void Function(ItemData item)? onItemTap;

  /// Optional scroll controller.
  final ScrollController? scrollController;

  /// Whether more items are currently loading.
  final bool isLoadingMore;

  /// Callback to trigger loading more items.
  final VoidCallback? onLoadMore;

  @override
  State<DP1Carousel> createState() => _DP1CarouselState();
}

class _DP1CarouselState extends State<DP1Carousel> {
  late final ScrollController _scrollController;
  bool _hasTriggeredLoadMore = false;

  @override
  void initState() {
    super.initState();
    _scrollController = widget.scrollController ?? ScrollController();
    _scrollController.addListener(_onScroll);
  }

  @override
  void didUpdateWidget(DP1Carousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.items.length != widget.items.length) {
      // Reset load more trigger when items change
      _hasTriggeredLoadMore = false;
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    if (widget.scrollController == null) {
      _scrollController.dispose();
    }
    super.dispose();
  }

  void _onScroll() {
    if (!mounted) return;

    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.position.pixels;

    // Trigger onLoadMore when scrolled to 80% of the carousel
    if (currentScroll >= maxScroll * 0.8 &&
        !widget.isLoadingMore &&
        !_hasTriggeredLoadMore &&
        widget.onLoadMore != null) {
      _hasTriggeredLoadMore = true;
      widget.onLoadMore!();
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: LayoutConstants.dp1CarouselHeight,
      child: CustomScrollView(
        controller: _scrollController,
        scrollDirection: Axis.horizontal,
        shrinkWrap: true,
        slivers: [
          SliverPadding(
            padding: EdgeInsets.symmetric(
              horizontal: LayoutConstants.dp1CarouselContentPaddingHorizontal,
              vertical: LayoutConstants.dp1CarouselContentPaddingVertical,
            ),
            sliver: SliverList.builder(
              itemCount: widget.items.length,
              itemBuilder: (context, index) => Padding(
                padding: EdgeInsets.only(
                  right: index < widget.items.length - 1
                      ? LayoutConstants.workThumbnailGap
                      : 0,
                ),
                child: WorkItemThumbnail(
                  item: widget.items[index],
                  onTap: () {
                    widget.onItemTap?.call(widget.items[index]);
                  },
                ),
              ),
            ),
          ),
          if (widget.isLoadingMore)
            SliverPadding(
              padding: EdgeInsets.only(right: LayoutConstants.space3),
              sliver: SliverToBoxAdapter(
                child: LoadMoreIndicator(
                  isLoadingMore: widget.isLoadingMore,
                  padding: EdgeInsets.zero,
                  showText: false,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
