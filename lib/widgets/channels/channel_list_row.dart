import 'package:app/app/providers/channel_preview_provider.dart';
import 'package:app/design/app_typography.dart';
import 'package:app/design/layout_constants.dart';
import 'package:app/domain/models/playlist_item.dart';
import 'package:app/theme/app_color.dart';
import 'package:app/widgets/channel_item.dart';
import 'package:app/widgets/dp1_carousel.dart';
import 'package:app/widgets/loading_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Data model for a channel row (domain only).
class ChannelRowData {
  /// Creates ChannelRowData.
  const ChannelRowData({
    required this.channelId,
    required this.channelTitle,
    this.channelSummary,
    required this.works,
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
    this.scrollController,
    super.key,
  });

  /// Channel data to display.
  final ChannelRowData channelData;

  /// Callback when a work item is tapped.
  final void Function(PlaylistItem item)? onItemTap;

  /// Optional scroll controller.
  final ScrollController? scrollController;

  @override
  ConsumerState<ChannelListRow> createState() => _ChannelListRowState();
}

class _ChannelListRowState extends ConsumerState<ChannelListRow> {
  @override
  Widget build(BuildContext context) {
    final channelId = widget.channelData.channelId;
    final previewState = ref.watch(channelPreviewProvider(channelId));

    // Trigger initial load when using provider (works from parent empty and state initial).
    if (widget.channelData.works.isEmpty &&
        previewState.works.isEmpty &&
        !previewState.isLoading &&
        previewState.error == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) return;
        ref.read(channelPreviewProvider(channelId).notifier).load();
      });
    }

    final works = widget.channelData.works.isNotEmpty
        ? widget.channelData.works
        : previewState.works;
    final hasMore = widget.channelData.works.isNotEmpty
        ? false
        : previewState.hasMore;
    final isLoadingMore =
        widget.channelData.works.isEmpty && previewState.isLoadingMore;
    final isLoading =
        widget.channelData.works.isEmpty && previewState.isLoading;
    final error = widget.channelData.works.isEmpty ? previewState.error : null;

    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: AppColor.primaryBlack,
            width: LayoutConstants.dividerThickness,
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
                'We couldn\'t load this channel\'s works. Tap to retry.',
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
          if (isLoading && works.isEmpty)
            Padding(
              padding: EdgeInsets.only(top: LayoutConstants.space2),
              child: const LoadingView(),
            ),
          if (works.isNotEmpty)
            DP1Carousel(
              items: works,
              onItemTap: widget.onItemTap,
              scrollController: widget.scrollController,
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
