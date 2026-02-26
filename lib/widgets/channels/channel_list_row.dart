import 'package:app/app/providers/channel_preview_provider.dart';
import 'package:app/design/app_typography.dart';
import 'package:app/design/layout_constants.dart';
import 'package:app/domain/models/playlist_item.dart';
import 'package:app/widgets/channel_item.dart';
import 'package:app/widgets/dp1_carousel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Data model for a channel row (domain only).
class ChannelRowData {
  /// Creates ChannelRowData.
  const ChannelRowData({
    required this.channelId,
    required this.channelTitle,
    required this.works, this.channelSummary,
  });

  /// Channel ID.
  final String channelId;

  /// Channel title.
  final String channelTitle;

  /// Optional channel summary.
  final String? channelSummary;

  /// List of works in this channel (domain).
  /// When empty, [ChannelListRow] loads preview via [channelPreviewProvider].
  final List<PlaylistItem> works;
}

/// Channel List Row - Combines channel info with carousel of works.
/// When [ChannelRowData.works] is empty, uses [channelPreviewProvider] to load
/// and page preview works for the channel.
class ChannelListRow extends ConsumerStatefulWidget {
  /// Creates a ChannelListRow.
  const ChannelListRow({
    required this.channelData,
    this.onItemTap,
    this.isActive = true,
    super.key,
  });

  /// Channel data to display.
  final ChannelRowData channelData;

  /// Callback when a work item is tapped.
  final void Function(PlaylistItem item)? onItemTap;

  /// Whether this row should actively listen to providers.
  final bool isActive;

  @override
  ConsumerState<ChannelListRow> createState() => _ChannelListRowState();
}

class _ChannelListRowState extends ConsumerState<ChannelListRow> {
  static const int _loadingItemsCount = 8;

  ChannelPreviewState _cachedPreviewState = ChannelPreviewState.initial();

  Widget _buildLoadingCarousel() {
    final placeholderItems = List<PlaylistItem>.generate(
      _loadingItemsCount,
      (index) => PlaylistItem(
        id: 'ch_loading_$index',
        kind: PlaylistItemKind.dp1Item,
        title: 'Loading',
      ),
      growable: false,
    );
    return DP1Carousel(
      items: placeholderItems,
    );
  }

  @override
  void didUpdateWidget(ChannelListRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.channelData.channelId != widget.channelData.channelId) {
      _cachedPreviewState = ChannelPreviewState.initial();
    }
    if (!oldWidget.isActive &&
        widget.isActive &&
        widget.channelData.works.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !widget.isActive) return;
        ref
            .read(channelPreviewProvider(widget.channelData.channelId).notifier)
            .load();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final channelId = widget.channelData.channelId;
    final nextPreviewState = widget.isActive
        ? ref.watch(channelPreviewProvider(channelId))
        : _cachedPreviewState;

    // When the autoDispose provider is recreated after a tab switch it returns
    // initial() — isLoading: false, works: [] — before the DB watch delivers
    // data. Keep showing cached works during that gap to avoid a height
    // collapse that makes the list jumpy.
    final shouldKeepCached = widget.isActive &&
        _cachedPreviewState.works.isNotEmpty &&
        nextPreviewState.works.isEmpty &&
        nextPreviewState.error == null;

    final previewState =
        shouldKeepCached ? _cachedPreviewState : nextPreviewState;
    if (widget.isActive && !shouldKeepCached) {
      _cachedPreviewState = nextPreviewState;
    }

    final works = widget.channelData.works.isNotEmpty
        ? widget.channelData.works
        : previewState.works;
    final hasMore =
        widget.channelData.works.isEmpty && previewState.hasMore;
    final isLoadingMore =
        widget.channelData.works.isEmpty && previewState.isLoadingMore;
    final isLoading =
        widget.channelData.works.isEmpty && previewState.isLoading;
    final error = widget.channelData.works.isEmpty ? previewState.error : null;

    return Container(
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(
            
          ),
        ),
      ),
      padding: EdgeInsets.only(bottom: LayoutConstants.space3),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ChannelHeader(
            channelId: widget.channelData.channelId,
            channelTitle: widget.channelData.channelTitle,
            channelSummary: widget.channelData.channelSummary,
            maxLines: 4,
          ),
          if (error != null)
            Padding(
              padding: EdgeInsets.only(top: LayoutConstants.space2),
              child: Text(
                "We couldn't load this channel's works. Tap to retry.",
                style: AppTypography.caption(context).grey,
              ),
            ),
          if (error != null)
            Padding(
              padding: EdgeInsets.only(top: LayoutConstants.space2),
              child: TextButton(
                onPressed: () {
                  ref.read(channelPreviewProvider(channelId).notifier).load();
                },
                child: Text(
                  'Retry',
                  style: AppTypography.body(context),
                ),
              ),
            ),
          // Show a skeleton carousel while loading so the layout height is
          // reserved and no jump occurs when the real carousel appears.
          if (isLoading && works.isEmpty)
            _buildLoadingCarousel()
          else if (works.isNotEmpty)
            DP1Carousel(
              items: works,
              onItemTap: widget.onItemTap,
              isLoadingMore: isLoadingMore,
              onLoadMore: hasMore
                  ? () {
                      ref
                          .read(channelPreviewProvider(channelId).notifier)
                          .loadMore();
                    }
                  : null,
            ),
        ],
      ),
    );
  }
}
