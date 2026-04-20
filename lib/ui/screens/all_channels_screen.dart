import 'dart:async';

import 'package:app/app/providers/channels_provider.dart';
import 'package:app/app/routing/navigation_extensions.dart';
import 'package:app/app/routing/previous_page_title_scope.dart';
import 'package:app/app/routing/routes.dart';
import 'package:app/design/app_typography.dart';
import 'package:app/design/layout_constants.dart';
import 'package:app/domain/models/channel.dart';
import 'package:app/domain/models/playlist_item.dart';
import 'package:app/theme/app_color.dart';
import 'package:app/widgets/appbars/main_app_bar.dart';
import 'package:app/widgets/channels/channel_list_row.dart';
import 'package:app/widgets/error_view.dart';
import 'package:app/widgets/load_more_indicator.dart';
import 'package:app/widgets/loading_view.dart';
import 'package:app/widgets/playlist/section_details_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Filter for the "All channels" screen.
enum AllChannelsFilter {
  /// Show curated (DP-1) channels.
  curated,

  /// Show personal (local virtual) channels.
  personal,

  /// Show living registry channels.
  living,
}

/// Maps UI filter to domain ChannelType.
ChannelType _filterToType(AllChannelsFilter filter) {
  switch (filter) {
    case AllChannelsFilter.curated:
      return ChannelType.dp1;
    case AllChannelsFilter.personal:
      return ChannelType.localVirtual;
    case AllChannelsFilter.living:
      return ChannelType.living;
  }
}

/// All channels screen.
///
/// Mirrors the old app’s "View all" pages while using Riverpod state.
class AllChannelsScreen extends ConsumerStatefulWidget {
  /// Creates an [AllChannelsScreen].
  const AllChannelsScreen({
    required this.filter,
    this.backTitle,
    super.key,
  });

  /// Which channels to show.
  final AllChannelsFilter filter;

  /// Prior screen title for the back control.
  final String? backTitle;

  @override
  ConsumerState<AllChannelsScreen> createState() => _AllChannelsScreenState();
}

class _AllChannelsScreenState extends ConsumerState<AllChannelsScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(
        ref
            .read(channelsProvider(_filterToType(widget.filter)).notifier)
            .loadChannels(),
      );
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
    if (widget.filter != AllChannelsFilter.curated) {
      return;
    }
    if (_scrollController.position.pixels + 100 >=
        _scrollController.position.maxScrollExtent) {
      unawaited(
        ref.read(channelsProvider(ChannelType.dp1).notifier).loadMore(),
      );
    }
  }

  Future<void> _onRefresh() async {
    await ref
        .read(channelsProvider(_filterToType(widget.filter)).notifier)
        .refresh();
  }

  @override
  Widget build(BuildContext context) {
    final channelType = _filterToType(widget.filter);
    final state = ref.watch(channelsProvider(channelType));

    final channels = state.channels;
    final isLoading = state.isLoading;
    final isLoadingMore = state.isLoadingMore;
    final hasMore = state.hasMore;

    final title = switch (widget.filter) {
      AllChannelsFilter.curated => 'Curated',
      AllChannelsFilter.personal => 'Personal',
      AllChannelsFilter.living => 'Living',
    };
    // Descriptions from Feral File app (old repo) for consistency where
    // applicable.
    final description = switch (widget.filter) {
      AllChannelsFilter.curated =>
        'A small set of Channels selected by Feral File and invited '
            'collaborators. These are early recommendations designed to give '
            'you strong entry points into digital art.',
      AllChannelsFilter.personal =>
        'Public Channels gathered from across the ecosystem. '
            "They're not ranked or popularity-based—they simply give you a "
            "wide view of what's out there, organized by source.",
      AllChannelsFilter.living =>
        'Channels that update over time from the feed. Follow a channel to get '
            'notifications when new playlists or works appear.',
    };
    final iconAsset = switch (widget.filter) {
      AllChannelsFilter.curated => 'assets/images/D.svg',
      AllChannelsFilter.personal => 'assets/images/icon_account.svg',
      AllChannelsFilter.living => 'assets/images/D.svg',
    };

    return PreviousPageTitleScope(
      title: title,
      child: Scaffold(
        backgroundColor: AppColor.auGreyBackground,
        appBar: MainAppBar.preferred(
          context,
          backTitle: widget.backTitle ?? '',
        ),
        body: SafeArea(
          child: RefreshIndicator(
            onRefresh: _onRefresh,
            backgroundColor: AppColor.primaryBlack,
            color: AppColor.white,
            child: Builder(
              builder: (context) {
                if (isLoading && channels.isEmpty) {
                  return const LoadingView();
                }

                if (state.error != null && channels.isEmpty) {
                  return ErrorView(
                    error:
                        'We couldn’t load channels. Check your connection, '
                        'then Retry.',
                    onRetry: () => unawaited(
                      ref
                          .read(channelsProvider(channelType).notifier)
                          .loadChannels(),
                    ),
                  );
                }

                if (channels.isEmpty) {
                  return Center(
                    child: Text(
                      'No channels found',
                      style: AppTypography.body(context).grey,
                    ),
                  );
                }

                final rowData = channels
                    .map(
                      (c) => ChannelRowData(
                        channelId: c.id,
                        channelTitle: c.name,
                        channelSummary: c.description,
                        works: const <PlaylistItem>[],
                      ),
                    )
                    .toList();

                return CustomScrollView(
                  controller: _scrollController,
                  slivers: [
                    SliverToBoxAdapter(
                      child: SectionDetailsHeader(
                        icon: SvgPicture.asset(
                          iconAsset,
                          width: LayoutConstants.iconSizeDefault,
                          height: LayoutConstants.iconSizeDefault,
                          colorFilter: const ColorFilter.mode(
                            AppColor.white,
                            BlendMode.srcIn,
                          ),
                        ),
                        title: title,
                        description: description,
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: SizedBox(height: LayoutConstants.space6),
                    ),
                    SliverList.builder(
                      itemCount: rowData.length,
                      itemBuilder: (context, index) => ChannelListRow(
                        channelData: rowData[index],
                        onItemTap: (item) {
                          unawaited(
                            context.pushWithPreviousTitle(
                              '${Routes.works}/${item.id}',
                            ),
                          );
                        },
                      ),
                    ),
                    if (hasMore || isLoadingMore)
                      SliverToBoxAdapter(
                        child: LoadMoreIndicator(isLoadingMore: isLoadingMore),
                      ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
