import 'dart:async';

import 'package:app/app/providers/channels_provider.dart';
import 'package:app/app/providers/publisher_section_providers.dart';
import 'package:app/app/routing/navigation_extensions.dart';
import 'package:app/app/routing/previous_page_title_scope.dart';
import 'package:app/app/routing/routes.dart';
import 'package:app/design/app_typography.dart';
import 'package:app/design/content_rhythm.dart';
import 'package:app/design/layout_constants.dart';
import 'package:app/domain/models/channel.dart';
import 'package:app/domain/models/dp1/dp1_publisher.dart';
import 'package:app/theme/app_color.dart';
import 'package:app/widgets/appbars/main_app_bar.dart';
import 'package:app/widgets/channels/channel_list_row.dart';
import 'package:app/widgets/error_view.dart';
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
}

/// Maps UI filter to domain ChannelType.
ChannelType _filterToType(AllChannelsFilter filter) {
  switch (filter) {
    case AllChannelsFilter.curated:
      return ChannelType.dp1;
    case AllChannelsFilter.personal:
      return ChannelType.localVirtual;
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
  bool get _shouldGroup => widget.filter == AllChannelsFilter.curated;

  void _retryCuratedChannelGroups({List<DP1Publisher>? publishers}) {
    // Curated channels now render entirely from grouped stream providers.
    // Retry must rebuild the stream sources themselves; otherwise the screen
    // only retries the removed notifier path and the visible error state never
    // gets a new subscription.
    ref.invalidate(publishersProvider);
    for (final publisher in publishers ?? const <DP1Publisher>[]) {
      ref.invalidate(channelsByPublisherProvider(publisher.id));
    }
    ref.invalidate(channelsByPublisherProvider(null));
  }

  @override
  void initState() {
    super.initState();
    if (!_shouldGroup) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(
          ref
              .read(channelsProvider(_filterToType(widget.filter)).notifier)
              .loadChannels(),
        );
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _refreshCuratedChannelGroups({
    List<DP1Publisher>? publishers,
  }) async {
    // Refresh must wait for the grouped stream sources to emit again; simply
    // invalidating them would let RefreshIndicator finish before the visible
    // data path has actually reloaded.
    _retryCuratedChannelGroups(publishers: publishers);
    final refreshFutures = <Future<void>>[
      ref.refresh(publishersProvider.future),
      ref.refresh(channelsByPublisherProvider(null).future),
    ];
    for (final publisher in publishers ?? const <DP1Publisher>[]) {
      refreshFutures.add(
        ref.refresh(channelsByPublisherProvider(publisher.id).future),
      );
    }
    await Future.wait(refreshFutures);
  }

  Future<void> _onRefresh() async {
    if (_shouldGroup) {
      await _refreshCuratedChannelGroups(
        publishers: ref.read(publishersProvider).value,
      );
      return;
    }
    await ref
        .read(channelsProvider(_filterToType(widget.filter)).notifier)
        .refresh();
  }

  List<Widget> _buildLoadingStateSlivers() {
    return const [
      SliverFillRemaining(
        hasScrollBody: false,
        child: LoadingView(),
      ),
    ];
  }

  List<Widget> _buildErrorStateSlivers(BuildContext context) {
    return [
      SliverFillRemaining(
        hasScrollBody: false,
        child: ErrorView(
          error:
              'We couldn’t load channels. Check your connection, then Retry.',
          onRetry: _shouldGroup
              ? _retryCuratedChannelGroups
              : () => unawaited(
                  ref
                      .read(
                        channelsProvider(_filterToType(widget.filter)).notifier,
                      )
                      .loadChannels(),
                ),
        ),
      ),
    ];
  }

  List<Widget> _buildEmptyStateSlivers(BuildContext context) {
    return [
      SliverFillRemaining(
        hasScrollBody: false,
        child: Center(
          child: Text(
            'No channels found',
            style: AppTypography.body(context).grey,
          ),
        ),
      ),
    ];
  }

  List<Widget> _buildGroupedContentSlivers(
    BuildContext context,
  ) {
    final publishersAsync = ref.watch(publishersProvider);
    if (publishersAsync.isLoading && !publishersAsync.hasValue) {
      return _buildLoadingStateSlivers();
    }

    if (publishersAsync.hasError) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: ErrorView(
            error:
                'We couldn’t load channels. Check your connection, then Retry.',
            onRetry: _retryCuratedChannelGroups,
          ),
        ),
      ];
    }

    final publishers = publishersAsync.value ?? const <DP1Publisher>[];
    final contentSlivers = <Widget>[];

    for (var i = 0; i < publishers.length; i++) {
      final publisher = publishers[i];
      final publisherChannelsAsync = ref.watch(
        channelsByPublisherProvider(publisher.id),
      );
      if (publisherChannelsAsync.isLoading &&
          !publisherChannelsAsync.hasValue) {
        return _buildLoadingStateSlivers();
      }
      if (publisherChannelsAsync.hasError) {
        return [
          SliverFillRemaining(
            hasScrollBody: false,
            child: ErrorView(
              error:
                  'We couldn’t load channels. '
                  'Check your connection, then Retry.',
              onRetry: () => _retryCuratedChannelGroups(publishers: publishers),
            ),
          ),
        ];
      }
      final publisherChannels =
          publisherChannelsAsync.value ?? const <Channel>[];
      contentSlivers.addAll([
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.only(
              left: ContentRhythm.horizontalRail,
              right: ContentRhythm.horizontalRail,
              bottom: LayoutConstants.space3,
              top: i == 0 ? 0 : LayoutConstants.space4,
            ),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                publisher.title,
                style: AppTypography.h3(context).white,
              ),
            ),
          ),
        ),
        SliverList.builder(
          itemCount: publisherChannels.length,
          itemBuilder: (context, index) {
            final channel = publisherChannels[index];
            return ChannelListRow(
              channelData: ChannelRowData(
                channelId: channel.id,
                channelTitle: channel.name,
                channelSummary: channel.description,
                works: const [],
              ),
              onItemTap: (item) {
                unawaited(
                  context.pushWithPreviousTitle('${Routes.works}/${item.id}'),
                );
              },
            );
          },
        ),
      ]);
    }

    final nullPublisherChannelsAsync = ref.watch(
      channelsByPublisherProvider(null),
    );
    if (nullPublisherChannelsAsync.isLoading &&
        !nullPublisherChannelsAsync.hasValue) {
      return _buildLoadingStateSlivers();
    }
    if (nullPublisherChannelsAsync.hasError) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: ErrorView(
            error:
                'We couldn’t load channels. Check your connection, then Retry.',
            onRetry: () => _retryCuratedChannelGroups(publishers: publishers),
          ),
        ),
      ];
    }

    final nullPublisherChannels =
        nullPublisherChannelsAsync.value ?? const <Channel>[];
    if (nullPublisherChannels.isNotEmpty) {
      contentSlivers.addAll([
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.only(
              left: ContentRhythm.horizontalRail,
              right: ContentRhythm.horizontalRail,
              bottom: LayoutConstants.space3,
              top: contentSlivers.isEmpty ? 0 : LayoutConstants.space4,
            ),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Other',
                style: AppTypography.h3(context).white,
              ),
            ),
          ),
        ),
        SliverList.builder(
          itemCount: nullPublisherChannels.length,
          itemBuilder: (context, index) {
            final channel = nullPublisherChannels[index];
            return ChannelListRow(
              channelData: ChannelRowData(
                channelId: channel.id,
                channelTitle: channel.name,
                channelSummary: channel.description,
                works: const [],
              ),
              onItemTap: (item) {
                unawaited(
                  context.pushWithPreviousTitle('${Routes.works}/${item.id}'),
                );
              },
            );
          },
        ),
      ]);
    }

    if (contentSlivers.isEmpty) {
      return _buildEmptyStateSlivers(context);
    }

    return contentSlivers;
  }

  List<Widget> _buildFlatContentSlivers(BuildContext context) {
    final state = ref.watch(channelsProvider(_filterToType(widget.filter)));
    final channels = state.channels;
    final isLoading = state.isLoading;
    final error = state.error;

    if (isLoading && channels.isEmpty) {
      return _buildLoadingStateSlivers();
    }

    if (error != null && channels.isEmpty) {
      return _buildErrorStateSlivers(context);
    }

    if (channels.isEmpty) {
      return _buildEmptyStateSlivers(context);
    }

    return [
      SliverList.builder(
        itemCount: channels.length,
        itemBuilder: (context, index) => ChannelListRow(
          channelData: ChannelRowData(
            channelId: channels[index].id,
            channelTitle: channels[index].name,
            channelSummary: channels[index].description,
            works: const [],
          ),
          onItemTap: (item) {
            unawaited(
              context.pushWithPreviousTitle('${Routes.works}/${item.id}'),
            );
          },
        ),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.filter == AllChannelsFilter.curated
        ? 'Curated'
        : 'Personal';
    // Descriptions from Feral File app (old repo) for consistency.
    final description = widget.filter == AllChannelsFilter.curated
        ? 'A small set of Channels selected by Feral File and invited '
              'collaborators. These are early recommendations designed to give '
              'you strong entry points into digital art.'
        : 'Public Channels gathered from across the ecosystem. '
              "They're not ranked or popularity-based—they simply give you a "
              "wide view of what's out there, organized by source.";
    final iconAsset = widget.filter == AllChannelsFilter.curated
        ? 'assets/images/D.svg'
        : 'assets/images/icon_account.svg';
    final shouldGroup = _shouldGroup;
    late final List<Widget> contentSlivers;

    if (shouldGroup) {
      contentSlivers = _buildGroupedContentSlivers(context);
    } else {
      contentSlivers = _buildFlatContentSlivers(context);
    }

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
            child: CustomScrollView(
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
                ...contentSlivers,
              ],
            ),
          ),
        ),
      ),
    );
  }
}
