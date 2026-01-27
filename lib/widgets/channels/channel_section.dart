import 'package:app/widgets/channels/channel_list_row.dart';
import 'package:app/widgets/channels/channel_section_header.dart';
import 'package:flutter/material.dart';

/// Channel Section - Combines header with list of channel rows
class ChannelSection extends StatelessWidget {
  /// Creates a ChannelSection.
  const ChannelSection({
    required this.sectionName,
    required this.channels,
    this.sectionIcon,
    this.onViewAllTap,
    this.onChannelItemTap,
    this.scrollController,
    this.hasMore = true,
    super.key,
  });

  /// Section name to display.
  final String sectionName;
  
  /// List of channel data to display.
  final List<ChannelRowData> channels;
  
  /// Optional icon widget for the section.
  final Widget? sectionIcon;
  
  /// Callback when "View All" is tapped.
  final VoidCallback? onViewAllTap;
  
  /// Callback when a work item within a channel is tapped.
  final void Function(String workId)? onChannelItemTap;
  
  /// Optional scroll controller for the list.
  final ScrollController? scrollController;
  
  /// Whether there are more items to view.
  final bool hasMore;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      shrinkWrap: true,
      padding: EdgeInsets.zero,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: channels.length + 2,
      itemBuilder: (context, index) {
        // Header
        if (index == 0) {
          return ChannelSectionHeader(
            sectionName: sectionName,
            sectionIcon: sectionIcon,
            onViewAllTap: hasMore ? onViewAllTap : null,
            hasMore: hasMore,
          );
        }

        // Gap
        if (index == 1) {
          return const SizedBox(
            height: 10,
          );
        }

        // List items
        final channelIndex = index - 2;
        final channelData = channels[channelIndex];

        return ChannelListRow(
          channelData: channelData,
          onItemTap: onChannelItemTap,
          scrollController: scrollController,
        );
      },
    );
  }
}
