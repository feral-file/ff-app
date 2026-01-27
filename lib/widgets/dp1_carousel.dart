import 'package:app/widgets/artwork_item.dart';
import 'package:app/widgets/load_more_indicator.dart';
import 'package:flutter/material.dart';

/// Token values for DP1Carousel layout
class DP1CarouselTokens {
  /// Carousel item height.
  static const double itemHeight = 285.0;
  
  /// Horizontal padding for carousel content.
  static const double contentPaddingHorizontal = 12.0;
  
  /// Vertical padding for carousel content.
  static const double contentPaddingVertical = 0.0;
}

/// Work item data for carousel display
class WorkItemData {
  /// Creates WorkItemData.
  const WorkItemData({
    required this.workId,
    required this.thumbnailUrl,
    this.title,
    this.artist,
  });

  /// Work ID.
  final String workId;
  
  /// Thumbnail image URL.
  final String thumbnailUrl;
  
  /// Optional work title.
  final String? title;
  
  /// Optional artist name.
  final String? artist;
}

/// DP1 Carousel - Horizontal scrollable carousel for displaying work items
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

  /// List of work items to display.
  final List<WorkItemData> items;
  
  /// Callback when an item is tapped.
  final void Function(String workId)? onItemTap;
  
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
      height: DP1CarouselTokens.itemHeight,
      child: CustomScrollView(
        controller: _scrollController,
        scrollDirection: Axis.horizontal,
        shrinkWrap: true,
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.symmetric(
              horizontal: DP1CarouselTokens.contentPaddingHorizontal,
              vertical: DP1CarouselTokens.contentPaddingVertical,
            ),
            sliver: SliverList.builder(
              itemCount: widget.items.length,
              itemBuilder: (context, index) => DP1ItemThumbnail(
                item: widget.items[index],
                onTap: () {
                  widget.onItemTap?.call(widget.items[index].workId);
                },
              ),
            ),
          ),
          if (widget.isLoadingMore)
            SliverPadding(
              padding: const EdgeInsets.only(right: 12),
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
