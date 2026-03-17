import 'package:app/app/providers/channel_detail_provider.dart';
import 'package:app/app/providers/services_provider.dart';
import 'package:app/app/routing/routes.dart';
import 'package:app/design/app_typography.dart';
import 'package:app/design/content_rhythm.dart';
import 'package:app/design/layout_constants.dart';
import 'package:app/domain/models/channel.dart';
import 'package:app/domain/models/playlist.dart';
import 'package:app/theme/app_color.dart';
import 'package:app/app/routing/all_playlists_route.dart';
import 'package:app/widgets/appbars/main_app_bar.dart';
import 'package:app/widgets/bottom_spacing.dart';
import 'package:app/widgets/channel_item.dart';
import 'package:app/widgets/error_view.dart';
import 'package:app/widgets/loading_view.dart';
import 'package:app/widgets/playlist/playlist_header_with_collection_state.dart';
import 'package:app/widgets/playlist/playlist_list_row.dart';
import 'package:app/widgets/playlist/playlist_section.dart';
import 'package:app/widgets/playlist/playlist_title.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

/// Channel detail screen.
/// Shows details and content for a specific channel.
class ChannelDetailScreen extends ConsumerStatefulWidget {
  /// Creates a ChannelDetailScreen.
  const ChannelDetailScreen({
    required this.channelId,
    super.key,
  });

  /// The channel ID to display.
  final String channelId;

  @override
  ConsumerState<ChannelDetailScreen> createState() =>
      _ChannelDetailScreenState();
}

class _ChannelDetailScreenState extends ConsumerState<ChannelDetailScreen> {
  static const int _previewCount = 5;

  String _creatorForAddressPlaylist(Playlist playlist) {
    final address = playlist.ownerAddress;
    if (address == null || address.isEmpty) return '';
    if (address.length > 10) {
      return '${address.substring(0, 6)}...${address.substring(address.length - 4)}';
    }
    return address;
  }

  Widget _buildMeChannelContent(
    BuildContext context,
    WidgetRef ref,
    Channel channel,
    List<Playlist> playlists,
  ) {
    final channelId = channel.id;
    final nonAddress =
        playlists.where((p) => p.type != PlaylistType.addressBased).toList();
    final addressPlaylists =
        playlists.where((p) => p.type == PlaylistType.addressBased).toList();

    final allEmpty = nonAddress.isEmpty && addressPlaylists.isEmpty;

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: SizedBox(height: ContentRhythm.sectionSpacing),
        ),
        SliverToBoxAdapter(
          child: ChannelHeader(
            channelId: channelId,
            channelTitle: channel.name,
            channelSummary: channel.description,
            clickable: false,
            renderSummaryAsHtml: true,
          ),
        ),
        SliverToBoxAdapter(
          child: SizedBox(height: ContentRhythm.sectionSpacing),
        ),
        if (allEmpty)
          SliverToBoxAdapter(
            child: Center(
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: ContentRhythm.horizontalRail,
                ),
                child: Text(
                  'This channel has no playlists.',
                  style: ContentRhythm.supporting(context),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          )
        else ...[
          if (nonAddress.isNotEmpty)
            SliverToBoxAdapter(
              child: Column(
                children: [
                  PlaylistSection(
                    sectionName: 'Playlists',
                    sectionIcon: SvgPicture.asset(
                      'assets/images/list.svg',
                      width: LayoutConstants.iconSizeDefault,
                      height: LayoutConstants.iconSizeDefault,
                      colorFilter: const ColorFilter.mode(
                        AppColor.auQuickSilver,
                        BlendMode.srcIn,
                      ),
                    ),
                    playlists: nonAddress.take(_previewCount).toList(),
                    hasMore: nonAddress.length > _previewCount,
                    onViewAllTap: nonAddress.length > _previewCount
                        ? () => context.push(
                              '${Routes.allPlaylists}${buildAllPlaylistsQuery(channelIds: [channelId], playlistTypes: [PlaylistType.dp1, PlaylistType.favorite])}',
                              extra: const AllPlaylistsScreenPayload(
                                title: 'Playlists',
                                description: 'All playlists in this channel.',
                                iconAsset: 'assets/images/list.svg',
                              ),
                            )
                        : null,
                    onPlaylistItemTap: (item) {
                      context.push('${Routes.works}/${item.id}');
                    },
                    playlistHeaderBuilder: (playlist, itemCount) {
                      if (playlist.type == PlaylistType.favorite) {
                        return PlaylistTitle(
                          primaryText: playlist.name,
                          secondaryText: '',
                        );
                      }
                      return null;
                    },
                  ),
                  SizedBox(height: LayoutConstants.space12),
                ],
              ),
            ),
          if (addressPlaylists.isNotEmpty)
            SliverToBoxAdapter(
              child: Column(
                children: [
                  PlaylistSection(
                    sectionName: 'Address',
                    sectionIcon: SvgPicture.asset(
                      'assets/images/icon_account.svg',
                      width: LayoutConstants.iconSizeDefault,
                      height: LayoutConstants.iconSizeDefault,
                      colorFilter: const ColorFilter.mode(
                        AppColor.auQuickSilver,
                        BlendMode.srcIn,
                      ),
                    ),
                    playlists: addressPlaylists.take(_previewCount).toList(),
                    hasMore: addressPlaylists.length > _previewCount,
                    onViewAllTap: addressPlaylists.length > _previewCount
                        ? () => context.push(
                              '${Routes.allPlaylists}${buildAllPlaylistsQuery(channelIds: [channelId], playlistTypes: [PlaylistType.addressBased])}',
                              extra: const AllPlaylistsScreenPayload(
                                title: 'Address',
                                description:
                                    'Content from wallet addresses you add to '
                                    'this channel.',
                                iconAsset: 'assets/images/icon_account.svg',
                              ),
                            )
                        : null,
                    onPlaylistItemTap: (item) {
                      context.push('${Routes.works}/${item.id}');
                    },
                    playlistHeaderBuilder: (playlist, itemCount) {
                      final ownerAddress = playlist.ownerAddress;
                      if (ownerAddress == null || ownerAddress.isEmpty) {
                        return null;
                      }
                      final creator = _creatorForAddressPlaylist(playlist);
                      return PlaylistHeaderWithCollectionState(
                        primaryText: playlist.name,
                        secondaryText: creator,
                        total: itemCount,
                        ownerAddress: ownerAddress,
                        onRetry: () => ref
                            .read(addressServiceProvider)
                            .indexAndSyncAddress(ownerAddress),
                      );
                    },
                  ),
                  SizedBox(height: LayoutConstants.space12),
                ],
              ),
            ),
        ],
        const SliverToBoxAdapter(child: BottomSpacing()),
      ],
    );
  }

  Widget _buildDefaultChannelContent(
    BuildContext context,
    Channel channel,
    List<Playlist> playlists,
  ) {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: SizedBox(height: ContentRhythm.sectionSpacing),
        ),
        SliverToBoxAdapter(
          child: ChannelHeader(
            channelId: channel.id,
            channelTitle: channel.name,
            channelSummary: channel.description,
            clickable: false,
            renderSummaryAsHtml: true,
          ),
        ),
        SliverToBoxAdapter(
          child: SizedBox(height: ContentRhythm.sectionSpacing),
        ),
        if (playlists.isEmpty)
          SliverToBoxAdapter(
            child: Center(
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: ContentRhythm.horizontalRail,
                ),
                child: Text(
                  'This channel has no playlists.',
                  style: ContentRhythm.supporting(context),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          )
        else
          SliverList.builder(
            itemCount: playlists.length,
            itemBuilder: (context, index) => PlaylistRowItem(
              playlist: playlists[index],
              onItemTap: (item) {
                context.push('${Routes.works}/${item.id}');
              },
            ),
          ),
        const SliverToBoxAdapter(child: BottomSpacing()),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final channelId = widget.channelId;
    Future<void> onRefresh() async {
      ref.invalidate(channelDetailsProvider(channelId));
    }

    return Scaffold(
      backgroundColor: AppColor.auGreyBackground,
      appBar: MainAppBar.preferred(
        context,
        backTitle: 'Channels',
        backgroundColor: AppColor.auGreyBackground,
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: onRefresh,
          backgroundColor: AppColor.primaryBlack,
          color: AppColor.white,
          child: ref
              .watch(channelDetailsProvider(channelId))
              .when(
                loading: () => const LoadingView(),
                error: (error, _) => ErrorView(
                  error:
                      'We couldn’t load this channel. Check your connection, then Retry.',
                  onRetry: onRefresh,
                ),
                data: (details) {
                  final channel = details.channel;
                  final playlists = details.playlists;
                  if (channel == null) {
                    return Center(
                      child: Text(
                        'Channel not found',
                        style: AppTypography.body(context).grey,
                      ),
                    );
                  }

                  final isMeChannel =
                      channel.type == ChannelType.localVirtual;
                  if (isMeChannel) {
                    return _buildMeChannelContent(
                      context,
                      ref,
                      channel,
                      playlists,
                    );
                  }

                  return _buildDefaultChannelContent(
                    context,
                    channel,
                    playlists,
                  );
                },
              ),
        ),
      ),
    );
  }
}
