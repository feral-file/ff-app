import 'dart:async';

import 'package:app/app/providers/channels_provider.dart';
import 'package:app/app/providers/database_service_provider.dart';
import 'package:app/app/providers/playlist_details_provider.dart';
import 'package:app/app/providers/services_provider.dart';
import 'package:app/app/routing/navigation_extensions.dart';
import 'package:app/app/routing/previous_page_title_scope.dart';
import 'package:app/app/routing/routes.dart';
import 'package:app/design/app_typography.dart';
import 'package:app/design/content_rhythm.dart';
import 'package:app/design/layout_constants.dart';
import 'package:app/domain/models/channel.dart';
import 'package:app/domain/models/dp1/dp1_intent.dart';
import 'package:app/domain/models/playlist.dart';
import 'package:app/domain/models/wallet_address.dart';
import 'package:app/infra/database/converters.dart' show DatabaseConverters;
import 'package:app/theme/app_color.dart';
import 'package:app/ui/ui_helper.dart';
import 'package:app/widgets/appbars/main_app_bar.dart';
import 'package:app/widgets/common/touch_target.dart';
import 'package:app/widgets/delayed_loading.dart';
import 'package:app/widgets/error_view.dart';
import 'package:app/widgets/ff_display_button.dart';
import 'package:app/widgets/loading_view.dart';
import 'package:app/widgets/playlist/playlist_details_header.dart';
import 'package:app/widgets/playlist/playlist_header_with_collection_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

/// Playlist detail screen.
/// Shows details and works for a specific playlist.
/// Note: Exhibition/Season/Program are playlist roles (UI chrome),
/// not separate domain objects.
class PlaylistDetailScreen extends ConsumerStatefulWidget {
  /// Creates a PlaylistDetailScreen.
  const PlaylistDetailScreen({
    required this.playlistId,
    this.backTitle,
    super.key,
  });

  /// The playlist ID to display.
  final String playlistId;

  /// Optional back button label (title of the previous screen).
  final String? backTitle;

  @override
  ConsumerState<PlaylistDetailScreen> createState() =>
      _PlaylistDetailScreenState();
}

class _PlaylistDetailScreenState extends ConsumerState<PlaylistDetailScreen> {
  final ScrollController _scrollController = ScrollController();

  String _pageTitle(AsyncValue<PlaylistDetailsState> detailsAsync) {
    final playlist = switch (detailsAsync) {
      AsyncData(value: final details) => details.playlist,
      _ => null,
    };
    final name = playlist?.name.trim();
    if (name != null && name.isNotEmpty) return name;
    return 'Playlist';
  }

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  void _onScroll() {
    final pos = _scrollController.position;
    if (pos.pixels >= pos.maxScrollExtent * 0.8) {
      unawaited(
        ref
            .read(playlistDetailsProvider(widget.playlistId).notifier)
            .loadMore(),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final detailsAsync = ref.watch(playlistDetailsProvider(widget.playlistId));

    final state = detailsAsync.hasValue ? detailsAsync.value : null;
    final hasPlaylist = state?.playlist != null && state?.items != null;

    return PreviousPageTitleScope(
      title: _pageTitle(detailsAsync),
      child: Scaffold(
        backgroundColor: AppColor.auGreyBackground,
        appBar: MainAppBar.preferred(
          context,
          backTitle: widget.backTitle ?? '',
          backgroundColor: AppColor.auGreyBackground,
          actions: [
            if (hasPlaylist)
              FFDisplayButton(
                onDeviceSelected: (device) async {
                  final current = ref
                      .read(playlistDetailsProvider(widget.playlistId))
                      .value;
                  if (current?.playlist == null || current?.items == null) {
                    return;
                  }
                  final canvas = ref.read(canvasClientServiceV2Provider);

                  final database = ref.read(databaseServiceProvider);

                  final allItems = await database.getPlaylistItems(
                    widget.playlistId,
                  );
                  final dp1 = DatabaseConverters.playlistAndItemsToDP1Playlist(
                    current!.playlist!,
                    allItems,
                  );
                  await canvas.castPlaylist(
                    device,
                    dp1,
                    DP1Intent.displayNow(),
                    usingUrl: false,
                  );
                },
              ),
          ],
        ),
        body: SafeArea(
          child: detailsAsync.when(
            loading: () => const DelayedLoadingGate(
              isLoading: true,
              child: LoadingView(),
            ),
            error: (error, _) => ErrorView(
              error:
                  'We couldn’t load this playlist. Check your connection, then '
                  'Retry.',
              onRetry: () =>
                  ref.invalidate(playlistDetailsProvider(widget.playlistId)),
            ),
            data: (state) {
              final playlist = state.playlist;
              final items = state.items;
              if (playlist == null) {
                return Center(
                  child: Text(
                    'Playlist not found',
                    style: AppTypography.body(context).grey,
                  ),
                );
              }

              // Playlist (domain) uses name; channel for subtitle
              final channelId = playlist.channelId;
              final channelAsync = channelId == null
                  ? const AsyncValue<Channel?>.data(null)
                  : ref.watch(channelByIdProvider(channelId));

              final ownerAddress = playlist.ownerAddress;
              final isAddressPlaylist =
                  ownerAddress != null && ownerAddress.isNotEmpty;

              return Builder(
                builder: (scopedContext) => CustomScrollView(
                  controller: _scrollController,
                  slivers: [
                    SliverToBoxAdapter(
                      child: isAddressPlaylist
                          ? channelAsync.when(
                              loading: () => PlaylistHeaderWithCollectionState(
                                primaryText: playlist.name,
                                secondaryText: '',
                                total: state.total,
                                ownerAddress: ownerAddress,
                                showDivider: true,
                                onRetry: () => ref
                                    .read(addressServiceProvider)
                                    .indexAndSyncAddress(ownerAddress),
                                trailing: _buildOptionsButton(
                                  scopedContext,
                                  ref,
                                  playlist,
                                ),
                              ),
                              error: (_, _) =>
                                  PlaylistHeaderWithCollectionState(
                                    primaryText: playlist.name,
                                    secondaryText: '',
                                    total: state.total,
                                    ownerAddress: ownerAddress,
                                    showDivider: true,
                                    onRetry: () => ref
                                        .read(addressServiceProvider)
                                        .indexAndSyncAddress(ownerAddress),
                                    trailing: _buildOptionsButton(
                                      scopedContext,
                                      ref,
                                      playlist,
                                    ),
                                  ),
                              data: (_) => PlaylistHeaderWithCollectionState(
                                primaryText: playlist.name,
                                secondaryText: '',
                                total: state.total,
                                ownerAddress: ownerAddress,
                                showDivider: true,
                                onRetry: () => ref
                                    .read(addressServiceProvider)
                                    .indexAndSyncAddress(ownerAddress),
                                trailing: _buildOptionsButton(
                                  scopedContext,
                                  ref,
                                  playlist,
                                ),
                              ),
                            )
                          : channelAsync.when(
                              loading: () => PlaylistDetailsHeader(
                                title: playlist.name,
                                total: state.total,
                              ),
                              error: (_, _) => PlaylistDetailsHeader(
                                title: playlist.name,
                                total: state.total,
                              ),
                              data: (channel) => PlaylistDetailsHeader(
                                title: playlist.name,
                                total: state.total,
                                subtitle:
                                    playlist.type == PlaylistType.favorite ||
                                        playlist.type ==
                                            PlaylistType.addressBased
                                    ? null
                                    : channel?.name,
                              ),
                            ),
                    ),
                    SliverToBoxAdapter(
                      child: SizedBox(height: ContentRhythm.rowVerticalPadding),
                    ),
                    if (items.isEmpty)
                      SliverToBoxAdapter(
                        child: Center(
                          child: Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: ContentRhythm.horizontalRail,
                            ),
                            child: Text(
                              'This playlist is empty.',
                              style: AppTypography.body(scopedContext).grey,
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                      )
                    else
                      UIHelper.worksSliverGrid(
                        works: items,
                        onItemTap: (item) {
                          unawaited(
                            scopedContext.pushWithPreviousTitle(
                              '${Routes.works}/${item.id}',
                            ),
                          );
                        },
                      ),
                    if (state.isLoadingMore)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.all(LayoutConstants.space4),
                          child: const Center(child: LoadingWidget()),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildOptionsButton(
    BuildContext context,
    WidgetRef ref,
    Playlist playlist,
  ) {
    return IconButton(
      padding: EdgeInsets.zero,
      onPressed: () {
        unawaited(
          UIHelper.showDrawerAction(
            context,
            options: [
              OptionItem(
                title: 'Delete',
                icon: const Icon(Icons.delete_outline, size: 20),
                onTap: () {
                  Navigator.pop(context);
                  UIHelper.showDeletePlaylistConfirmation(
                    context,
                    playlist,
                    (p) async {
                      final addr = p.ownerAddress!;
                      await ref
                          .read(addressServiceProvider)
                          .removeAddress(
                            walletAddress: WalletAddress(
                              address: addr,
                              name: p.name,
                              createdAt: p.createdAt ?? DateTime.now(),
                            ),
                            playlistId: p.id,
                          );
                      if (context.mounted) {
                        context.pop();
                      }
                    },
                  );
                },
              ),
              OptionItem.emptyOptionItem,
            ],
            title: playlist.name,
          ),
        );
      },
      constraints: const BoxConstraints(
        maxWidth: 44,
        maxHeight: 44,
        minWidth: 44,
        minHeight: 44,
      ),
      icon: TouchTarget(
        minSize: LayoutConstants.minTouchTarget,
        child: SvgPicture.asset('assets/images/more_circle.svg'),
      ),
    );
  }
}
