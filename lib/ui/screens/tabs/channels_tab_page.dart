import 'package:app/app/providers/channels_provider.dart';
import 'package:app/app/routing/routes.dart';
import 'package:app/design/layout_constants.dart';
import 'package:app/domain/models/channel.dart';
import 'package:app/domain/models/playlist_item.dart';
import 'package:app/widgets/channels/channel_list_row.dart';
import 'package:app/widgets/channels/channel_section.dart';
import 'package:app/widgets/error_view.dart';
import 'package:app/widgets/loading_view.dart';
import 'package:app/theme/app_color.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
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

    // Trigger initial load for both curated and personal (old repo semantics).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(channelsProvider(ChannelType.dp1).notifier).loadChannels();
      ref
          .read(channelsProvider(ChannelType.localVirtual).notifier)
          .loadChannels();
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
      // Load more curated only (pagination applies to dp1).
      ref.read(channelsProvider(ChannelType.dp1).notifier).loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    // Watch slice to avoid rebuilds when unrelated state changes.
    final slice = ref.watch(
      channelsProvider(ChannelType.dp1).select((s) => (
        channels: s.channels,
        isLoading: s.isLoading,
        error: s.error,
      )),
    );
    final curatedChannels = slice.channels;
    final isLoading = slice.isLoading;
    final error = slice.error;

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
              error:
                  'We couldn’t load channels. Check your connection, then Retry.',
              onRetry: () {
                ref
                    .read(channelsProvider(ChannelType.dp1).notifier)
                    .loadChannels();
                ref
                    .read(channelsProvider(ChannelType.localVirtual).notifier)
                    .loadChannels();
              },
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

    // Build ChannelRowData from domain Channel. Works loaded per channel via channelPreviewProvider.
    final channelRowData = displayChannels.map((channel) {
      return ChannelRowData(
        channelId: channel.id,
        channelTitle: channel.name,
        channelSummary: channel.description,
        works: const <PlaylistItem>[],
      );
    }).toList();

    return SliverList.builder(
      itemCount: 1,
      itemBuilder: (context, index) => ChannelSection(
        sectionName: 'Curated',
        channels: channelRowData,
        sectionIcon: SvgPicture.asset(
          'assets/images/D.svg',
          width: LayoutConstants.iconSizeDefault,
          height: LayoutConstants.iconSizeDefault,
          colorFilter: const ColorFilter.mode(
            AppColor.auQuickSilver,
            BlendMode.srcIn,
          ),
        ),
        hasMore: hasMore,
        onViewAllTap: hasMore
            ? () {
                context.push('${Routes.allChannels}?filter=curated');
              }
            : null,
        onChannelItemTap: (workId) {
          // Navigate to work detail
          context.push('${Routes.works}/$workId');
        },
      ),
    );
  }
}
