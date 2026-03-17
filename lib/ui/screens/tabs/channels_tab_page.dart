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
import 'package:app/widgets/error_view.dart';
import 'package:app/widgets/seed_sync_loading_indicator.dart';
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
  static const int _previewCount = 5;

  final ScrollController _scrollController = ScrollController();
  ChannelsState _cachedCuratedState = ChannelsState.initial();
  ChannelsState _cachedPersonalState = ChannelsState.initial();

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
      return SeedSyncLoadingIndicator(
        progress: seedState.progress,
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

    final nextPersonalState = widget.isActive
        ? ref.watch(channelsProvider(ChannelType.localVirtual))
        : _cachedPersonalState;
    if (widget.isActive) {
      _cachedPersonalState = nextPersonalState;
    }
    final personalChannels = _cachedPersonalState.channels;

    // Surface error when either curated or personal fails with no data.
    // Both sections are first-class; user needs a retry path for either.
    final hasError =
        (curatedState.error != null && curatedChannels.isEmpty) ||
        (_cachedPersonalState.error != null && personalChannels.isEmpty);

    // Match old app: Use CustomScrollView with NeverScrollableScrollPhysics
    // Parent NestedScrollView handles scrolling
    return CustomScrollView(
      shrinkWrap: true,
      controller: _scrollController,
      physics: const NeverScrollableScrollPhysics(),
      slivers: [
        // Error state
        if (hasError)
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

        // Me section (localVirtual channels) - above Curated
        if (personalChannels.isNotEmpty) _buildMeSection(personalChannels),

        // Curated channels section
        if (curatedChannels.isNotEmpty) ...[
          SliverToBoxAdapter(
            child: SizedBox(height: LayoutConstants.space12),
          ),
          _buildCuratedChannelsSection(curatedChannels),
        ],

        // Spacing between sections
        SliverToBoxAdapter(
          child: SizedBox(height: LayoutConstants.space12),
        ),
      ],
    );
  }

  Widget _buildCuratedChannelsSection(List<Channel> channels) {
    // Show max 5 channels, with "View All" if more exist
    final displayChannels = channels.take(_previewCount).toList();
    final hasMore = channels.length > _previewCount;

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

  Widget _buildMeSection(List<Channel> channels) {
    final displayChannels = channels.take(_previewCount).toList();
    final hasMore = channels.length > _previewCount;

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
        sectionName: 'Me',
        channels: channelRowData,
        isActive: widget.isActive,
        sectionIcon: SvgPicture.asset(
          'assets/images/icon_account.svg',
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
                context.push('${Routes.allChannels}?filter=personal');
              }
            : null,
        onChannelItemTap: (item) {
          context.push('${Routes.works}/${item.id}');
        },
      ),
    );
  }
}
