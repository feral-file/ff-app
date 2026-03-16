import 'dart:async';

import 'package:app/design/layout_constants.dart';
import 'package:app/domain/models/playlist_item.dart';
import 'package:app/widgets/load_more_indicator.dart';
import 'package:app/widgets/work_item_thumbnail.dart';
import 'package:flutter/material.dart';

/// Number of placeholder items shown in loading skeleton.
const int _loadingItemsCount = 8;

/// DP1 Carousel - Horizontal scrollable carousel for displaying work items.
/// Uses domain [PlaylistItem] only.
///
/// When [isLoading] is true and [items] is empty, shows a skeleton carousel to
/// reserve layout height and prevent UI bounce. When [items] is empty and
/// [isLoading] is false, renders [SizedBox.shrink].
class DP1Carousel extends StatefulWidget {
  /// Creates a DP1Carousel.
  const DP1Carousel({
    required this.items,
    this.isLoading = false,
    this.loadingDelay = const Duration(milliseconds: 500),
    this.onItemTap,
    this.itemKeyBuilder,
    this.scrollController,
    this.isLoadingMore = false,
    this.onLoadMore,
    super.key,
  });

  /// List of work items to display (domain).
  final List<PlaylistItem> items;

  /// Whether the initial data is loading. When true and [items] is empty,
  /// shows a skeleton carousel instead of collapsing.
  final bool isLoading;

  /// Delay before showing initial loading skeleton.
  final Duration loadingDelay;

  /// Callback when an item is tapped.
  final void Function(PlaylistItem item)? onItemTap;

  /// Optional key builder for each rendered work item.
  final Key Function(PlaylistItem item, int index)? itemKeyBuilder;

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
  bool _showDelayedLoading = false;
  Timer? _loadingDelayTimer;

  @override
  void initState() {
    super.initState();
    _scrollController = widget.scrollController ?? ScrollController();
    _scrollController.addListener(_onScroll);
    _syncLoadingDelay();
  }

  @override
  void didUpdateWidget(DP1Carousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.items.length != widget.items.length) {
      // Reset load more trigger when items change
      _hasTriggeredLoadMore = false;
    }
    final hasLoadingInputsChanged =
        oldWidget.isLoading != widget.isLoading ||
        oldWidget.items.isEmpty != widget.items.isEmpty ||
        oldWidget.loadingDelay != widget.loadingDelay;
    if (hasLoadingInputsChanged) {
      _syncLoadingDelay();
    }
  }

  @override
  void dispose() {
    _loadingDelayTimer?.cancel();
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

  void _syncLoadingDelay() {
    _loadingDelayTimer?.cancel();

    final shouldDelayShow = widget.items.isEmpty && widget.isLoading;
    if (!shouldDelayShow) {
      if (_showDelayedLoading) {
        setState(() {
          _showDelayedLoading = false;
        });
      }
      return;
    }

    if (widget.loadingDelay <= Duration.zero) {
      if (!_showDelayedLoading) {
        setState(() {
          _showDelayedLoading = true;
        });
      }
      return;
    }

    if (_showDelayedLoading) {
      setState(() {
        _showDelayedLoading = false;
      });
    }
    _loadingDelayTimer = Timer(widget.loadingDelay, () {
      if (!mounted || widget.items.isNotEmpty || !widget.isLoading) return;
      setState(() {
        _showDelayedLoading = true;
      });
    });
  }

  /// Placeholder items for loading skeleton. Lazily created once.
  static List<PlaylistItem>? _cachedPlaceholders;

  static List<PlaylistItem> _placeholderItems() {
    _cachedPlaceholders ??= List<PlaylistItem>.generate(
      _loadingItemsCount,
      (index) => PlaylistItem(
        id: 'dp1_carousel_loading_$index',
        kind: PlaylistItemKind.dp1Item,
        title: 'Loading',
      ),
      growable: false,
    );
    return _cachedPlaceholders!;
  }

  @override
  Widget build(BuildContext context) {
    final isLoadingVisible = widget.isLoading && _showDelayedLoading;
    if (widget.items.isEmpty && !widget.isLoading) {
      return const SizedBox.shrink();
    }
    if (widget.items.isEmpty && widget.isLoading && !isLoadingVisible) {
      return const SizedBox(height: LayoutConstants.dp1CarouselHeight);
    }
    final displayItems = widget.items.isEmpty && isLoadingVisible
        ? _placeholderItems()
        : widget.items;
    return SizedBox(
      height: LayoutConstants.dp1CarouselHeight,
      child: CustomScrollView(
        controller: _scrollController,
        scrollDirection: Axis.horizontal,
        shrinkWrap: true,
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.symmetric(
              horizontal: LayoutConstants.dp1CarouselContentPaddingHorizontal,
            ),
            sliver: SliverList.builder(
              itemCount: displayItems.length,
              itemBuilder: (context, index) => Padding(
                padding: EdgeInsets.only(
                  right: index < displayItems.length - 1
                      ? LayoutConstants.workThumbnailGap
                      : 0,
                ),
                child: WorkItemThumbnail(
                  key: widget.itemKeyBuilder?.call(displayItems[index], index),
                  item: displayItems[index],
                  onTap: widget.items.isNotEmpty
                      ? () {
                          widget.onItemTap?.call(displayItems[index]);
                        }
                      : null,
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
