import 'dart:async';

import 'package:app/app/providers/channels_provider.dart';
import 'package:app/app/providers/seed_database_provider.dart';
import 'package:app/app/routing/routes.dart';
import 'package:app/design/layout_constants.dart';
import 'package:app/domain/models/channel.dart';
import 'package:app/domain/models/playlist_item.dart';
import 'package:app/theme/app_color.dart';
import 'package:app/ui/screens/tabs/tab_reload_guard.dart';
import 'package:app/widgets/channels/channel_list_row.dart';
import 'package:app/widgets/channels/channel_section.dart';
import 'package:app/widgets/delayed_loading.dart';
import 'package:app/widgets/error_view.dart';
import 'package:app/widgets/loading_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

/// Channels tab page with curated and personal channels.
/// Uses widgets copied from old app design.
class ChannelsTabPage extends ConsumerStatefulWidget {
  /// Creates a ChannelsTabPage.
  const ChannelsTabPage({
    required this.isActive,
    super.key,
  });

  /// Whether this tab is currently active.
  final bool isActive;

  @override
  ConsumerState<ChannelsTabPage> createState() => ChannelsTabPageState();
}

/// State for ChannelsTabPage.
class ChannelsTabPageState extends ConsumerState<ChannelsTabPage>
    with AutomaticKeepAliveClientMixin {
  final ScrollController _scrollController = ScrollController();
  ChannelsState _cachedCuratedState = ChannelsState.initial();

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!widget.isActive) return;
      _loadChannels();
    });
  }

  @override
  void didUpdateWidget(covariant ChannelsTabPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.isActive && widget.isActive) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !widget.isActive) return;
        _loadChannels();
      });
    }
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!widget.isActive) return;
    if (_scrollController.position.pixels + 100 >=
        _scrollController.position.maxScrollExtent) {
      // Load more curated only (pagination applies to dp1).
      ref.read(channelsProvider(ChannelType.dp1).notifier).loadMore();
    }
  }

  void _loadChannels() {
    final curatedState = ref.read(channelsProvider(ChannelType.dp1));
    final shouldLoadCurated = shouldLoadTabData(
      isLoading: curatedState.isLoading,
      hasCachedItems: curatedState.channels.isNotEmpty,
      hasError: curatedState.error != null,
    );
    if (shouldLoadCurated) {
      ref.read(channelsProvider(ChannelType.dp1).notifier).loadChannels();
    }

    final personalState = ref.read(channelsProvider(ChannelType.localVirtual));
    final shouldLoadPersonal = shouldLoadTabData(
      isLoading: personalState.isLoading,
      hasCachedItems: personalState.channels.isNotEmpty,
      hasError: personalState.error != null,
    );
    if (shouldLoadPersonal) {
      ref
          .read(channelsProvider(ChannelType.localVirtual).notifier)
          .loadChannels();
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final seedState = ref.watch(seedDownloadProvider);
    if (seedState.status == SeedDownloadStatus.syncing) {
      return Center(
        child: DelayedLoadingGate(
          isLoading: true,
          child: LoadingWidget(
            backgroundColor: Colors.transparent,
            text:
                'Updating art library... '
                '${((seedState.progress ?? 0) * 100).round()}%',
          ),
        ),
      );
    }
    if (seedState.status == SeedDownloadStatus.error) {
      return Center(
        child: ErrorView(
          error:
              seedState.errorMessage ??
              "We couldn't prepare your feed. Check your connection, "
                  'then Retry.',
          onRetry: () => unawaited(ref.read(seedDownloadRetryProvider)()),
        ),
      );
    }

    // Watch curated channels provider (tab shows only curated).
    final nextCuratedState = widget.isActive
        ? ref.watch(channelsProvider(ChannelType.dp1))
        : _cachedCuratedState;
    final shouldKeepSnapshot =
        widget.isActive &&
        _cachedCuratedState.channels.isNotEmpty &&
        nextCuratedState.channels.isEmpty &&
        nextCuratedState.isLoading;
    final curatedState = shouldKeepSnapshot
        ? _cachedCuratedState
        : nextCuratedState;
    if (widget.isActive && !shouldKeepSnapshot) {
      _cachedCuratedState = nextCuratedState;
    }
    final curatedChannels = curatedState.channels;
    final error = curatedState.error;

    // Match old app: Use CustomScrollView with NeverScrollableScrollPhysics
    // Parent NestedScrollView handles scrolling
    return CustomScrollView(
      shrinkWrap: true,
      controller: _scrollController,
      physics: const NeverScrollableScrollPhysics(),
      slivers: [
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
        isActive: widget.isActive,
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
        onChannelItemTap: (item) {
          // Navigate to work detail
          context.push('${Routes.works}/${item.id}');
        },
      ),
    );
  }
}
