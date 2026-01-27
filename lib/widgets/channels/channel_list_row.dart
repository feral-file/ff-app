import 'package:app/widgets/channel_item.dart';
import 'package:app/widgets/dp1_carousel.dart';
import 'package:flutter/material.dart';

/// Data model for a channel row.
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
  
  /// List of works in this channel.
  final List<WorkItemData> works;
}

/// Channel List Row - Combines channel info with carousel of works
class ChannelListRow extends StatelessWidget {
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
  final void Function(String workId)? onItemTap;
  
  /// Optional scroll controller.
  final ScrollController? scrollController;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        // TODO: Navigate to channel detail page
        // Navigator.of(context).pushNamed(
        //   AppRouter.channelDetailPage,
        //   arguments: ChannelDetailPagePayload(
        //     channelId: channelData.channelId,
        //   ),
        // );
      },
      child: Container(
        decoration: const BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: Colors.black,
              width: 1,
            ),
          ),
        ),
        padding: const EdgeInsets.only(bottom: 11),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ChannelHeader(
              channelId: channelData.channelId,
              channelTitle: channelData.channelTitle,
              channelSummary: channelData.channelSummary,
              maxLines: 4,
            ),
            DP1Carousel(
              items: channelData.works,
              onItemTap: onItemTap,
              scrollController: scrollController,
            ),
          ],
        ),
      ),
    );
  }
}
