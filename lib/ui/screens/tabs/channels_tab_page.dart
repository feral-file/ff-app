import 'package:app/app/providers/channels_provider.dart';
import 'package:app/app/routing/routes.dart';
import 'package:app/design/layout_constants.dart';
import 'package:app/domain/models/channel.dart';
import 'package:app/widgets/channels/channel_list_row.dart';
import 'package:app/widgets/channels/channel_section.dart';
import 'package:app/widgets/dp1_carousel.dart';
import 'package:app/widgets/error_view.dart';
import 'package:app/widgets/loading_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Channels tab page with curated and personal channels.
/// Uses widgets copied from old app design.
class ChannelsTabPage extends ConsumerStatefulWidget {
  /// Creates a ChannelsTabPage.
  const ChannelsTabPage({super.key});

  @override
  ConsumerState<ChannelsTabPage> createState() => ChannelsTabPageState();
}

/// State for ChannelsTabPage.
class ChannelsTabPageState extends ConsumerState<ChannelsTabPage>
    with AutomaticKeepAliveClientMixin {
  final ScrollController _scrollController = ScrollController();

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);

    // Trigger initial load
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(channelsProvider.notifier).loadChannels();
    });
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels + 100 >=
        _scrollController.position.maxScrollExtent) {
      // Trigger pagination (old repo semantics: load more)
      ref.read(channelsProvider.notifier).loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    // Use select to optimize rebuilds - only rebuild when these specific fields change
    final isLoading = ref.watch(channelsProvider.select((s) => s.isLoading));
    final error = ref.watch(channelsProvider.select((s) => s.error));
    final curatedChannels = ref.watch(
      channelsProvider.select((s) => s.curatedChannels),
    );

    // Match old app: Use CustomScrollView with NeverScrollableScrollPhysics
    // Parent NestedScrollView handles scrolling
    return CustomScrollView(
      shrinkWrap: true,
      controller: _scrollController,
      physics: const NeverScrollableScrollPhysics(),
      slivers: [
        // Loading state
        if (isLoading && curatedChannels.isEmpty)
          const SliverToBoxAdapter(child: LoadingView()),

        // Error state
        if (error != null && curatedChannels.isEmpty)
          SliverToBoxAdapter(
            child: ErrorView(
              error: 'Error loading channels: $error',
              onRetry: () => ref.read(channelsProvider.notifier).loadChannels(),
            ),
          ),

        // Curated channels section
        if (curatedChannels.isNotEmpty)
          _buildCuratedChannelsSection(curatedChannels),

        // Spacing between sections
        SliverToBoxAdapter(
          child: SizedBox(height: LayoutConstants.space12),
        ),
      ],
    );
  }

  Widget _buildCuratedChannelsSection(List<Channel> channels) {
    // Show max 5 channels, with "View All" if more exist
    final displayChannels = channels.take(5).toList();
    final hasMore = channels.length > 5;

    // Convert channels to ChannelRowData
    final channelRowData = displayChannels.map((channel) {
      // TODO: Fetch actual works for each channel
      // For now, use mock data for the carousel
      final mockWorks = <WorkItemData>[];

      return ChannelRowData(
        channelId: channel.id,
        channelTitle: channel.name,
        channelSummary: channel.description,
        works: mockWorks,
      );
    }).toList();

    return SliverList.builder(
      itemCount: 1,
      itemBuilder: (context, index) => ChannelSection(
        sectionName: 'Curated',
        channels: channelRowData,
        sectionIcon: Icon(
          Icons.rss_feed,
          size: LayoutConstants.iconSizeDefault,
          color: const Color(0xFFA0A0A0),
        ),
        hasMore: hasMore,
        onViewAllTap: hasMore
            ? () {
                // TODO: Navigate to all channels page
              }
            : null,
        onChannelItemTap: (workId) {
          // Navigate to work detail
          context.go('${Routes.works}/$workId');
        },
        scrollController: _scrollController,
      ),
    );
  }
}
