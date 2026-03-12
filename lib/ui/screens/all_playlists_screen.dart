import 'package:app/app/providers/me_section_playlists_provider.dart';
import 'package:app/app/providers/playlists_provider.dart';
import 'package:app/app/providers/services_provider.dart';
import 'package:app/app/routing/routes.dart';
import 'package:app/design/app_typography.dart';
import 'package:app/design/layout_constants.dart';
import 'package:app/domain/models/playlist.dart';
import 'package:app/theme/app_color.dart';
import 'package:app/widgets/appbars/main_app_bar.dart';
import 'package:app/widgets/error_view.dart';
import 'package:app/widgets/load_more_indicator.dart';
import 'package:app/widgets/loading_view.dart';
import 'package:app/widgets/playlist/playlist_header_with_collection_state.dart';
import 'package:app/widgets/playlist/playlist_list_row.dart';
import 'package:app/widgets/playlist/playlist_title.dart';
import 'package:app/widgets/playlist/section_details_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

/// Filter for the "All playlists" screen.
enum AllPlaylistsFilter {
  /// Show curated (DP-1) playlists.
  curated,

  /// Show personal (address-based) playlists.
  personal,
}

/// Maps UI filter to domain PlaylistType (curated only; personal uses me section).
PlaylistType _filterToType(AllPlaylistsFilter filter) {
  switch (filter) {
    case AllPlaylistsFilter.curated:
      return PlaylistType.dp1;
    case AllPlaylistsFilter.personal:
      return PlaylistType.addressBased;
  }
}

/// All playlists screen.
///
/// Mirrors the old app’s "View all" pages while using Riverpod state.
class AllPlaylistsScreen extends ConsumerStatefulWidget {
  /// Creates an [AllPlaylistsScreen].
  const AllPlaylistsScreen({
    required this.filter,
    super.key,
  });

  /// Which playlists to show.
  final AllPlaylistsFilter filter;

  @override
  ConsumerState<AllPlaylistsScreen> createState() => _AllPlaylistsScreenState();
}

class _AllPlaylistsScreenState extends ConsumerState<AllPlaylistsScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.filter == AllPlaylistsFilter.curated) {
        ref.read(playlistsProvider(PlaylistType.dp1).notifier).loadPlaylists();
      }
      // Personal uses meSectionPlaylistsProvider (auto-loads on watch).
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
    if (widget.filter != AllPlaylistsFilter.curated) return;
    if (_scrollController.position.pixels + 100 >=
        _scrollController.position.maxScrollExtent) {
      ref.read(playlistsProvider(PlaylistType.dp1).notifier).loadMore();
    }
  }

  String _creatorForAddressPlaylist(Playlist playlist) {
    final address = playlist.ownerAddress;
    if (address == null || address.isEmpty) return '';
    if (address.length > 10) {
      return '${address.substring(0, 6)}...${address.substring(address.length - 4)}';
    }
    return address;
  }

  Future<void> _onRefresh() async {
    if (widget.filter == AllPlaylistsFilter.curated) {
      await ref.read(playlistsProvider(PlaylistType.dp1).notifier).refresh();
    } else {
      ref.invalidate(meSectionPlaylistsProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isPersonal = widget.filter == AllPlaylistsFilter.personal;
    final curatedState = ref.watch(playlistsProvider(PlaylistType.dp1));
    final meSectionAsync = ref.watch(meSectionPlaylistsProvider);

    final meSectionState = meSectionAsync.when(
      data: (v) => v,
      loading: () => null,
      error: (_, _) => null,
    );
    final playlists = isPersonal
        ? (meSectionState?.playlists ?? [])
        : curatedState.playlists;
    final isLoading = isPersonal
        ? (meSectionAsync.isLoading || (meSectionState?.isLoading == true))
        : curatedState.isLoading;
    final isLoadingMore = !isPersonal && curatedState.isLoadingMore;
    final hasMore = !isPersonal && curatedState.hasMore;

    final title = widget.filter == AllPlaylistsFilter.curated
        ? 'Curated'
        : 'Me';
    // Descriptions from Feral File app (old repo) for consistency.
    final description = widget.filter == AllPlaylistsFilter.curated
        ? 'Playlists assembled by Feral File and a small group of invited '
              'artists and curators. These are early recommendations to help you '
              'explore digital art as we build toward deeper, global curation.'
        : 'Playlists built from the wallet addresses you add. Use it to browse '
              "the works you own or to explore any address you're curious about.";
    final iconAsset = widget.filter == AllPlaylistsFilter.curated
        ? 'assets/images/D.svg'
        : 'assets/images/icon_account.svg';

    return Scaffold(
      backgroundColor: AppColor.auGreyBackground,
      appBar: MainAppBar.preferred(
        context,
        backTitle: 'Index',
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _onRefresh,
          backgroundColor: AppColor.primaryBlack,
          color: AppColor.white,
          child: Builder(
            builder: (context) {
              if (isLoading && playlists.isEmpty) {
                return const LoadingView();
              }

              if ((isPersonal
                      ? meSectionAsync.hasError
                      : curatedState.error != null) &&
                  playlists.isEmpty) {
                return ErrorView(
                  error:
                      'We couldn’t load playlists. Check your connection, then Retry.',
                  onRetry: () {
                    if (isPersonal) {
                      ref.invalidate(meSectionPlaylistsProvider);
                    } else {
                      ref
                          .read(playlistsProvider(PlaylistType.dp1).notifier)
                          .loadPlaylists();
                    }
                  },
                );
              }

              if (playlists.isEmpty) {
                return Center(
                  child: Text(
                    'No playlists found',
                    style: AppTypography.body(context).grey,
                  ),
                );
              }

              return CustomScrollView(
                controller: _scrollController,
                slivers: [
                  const SliverToBoxAdapter(child: SizedBox(height: 21)),
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
                  const SliverToBoxAdapter(child: SizedBox(height: 50)),
                  SliverList.builder(
                    itemCount: playlists.length,
                    itemBuilder: (context, index) {
                      final playlist = playlists[index];
                      return PlaylistRowItem(
                        playlist: playlist,
                        headerBuilder:
                            widget.filter == AllPlaylistsFilter.personal
                            ? (p, itemCount) {
                                if (p.type == PlaylistType.favorite) {
                                  return PlaylistTitle(
                                    primaryText: p.name,
                                    secondaryText: '',
                                  );
                                }
                                final ownerAddress = p.ownerAddress;
                                if (ownerAddress == null ||
                                    ownerAddress.isEmpty) {
                                  return null;
                                }
                                final creator = _creatorForAddressPlaylist(p);
                                return PlaylistHeaderWithCollectionState(
                                  primaryText: p.name,
                                  secondaryText: creator,
                                  total: itemCount,
                                  ownerAddress: ownerAddress,
                                  onRetry: () => ref
                                      .read(addressServiceProvider)
                                      .indexAndSyncAddress(ownerAddress),
                                );
                              }
                            : null,
                        onItemTap: (item) {
                          context.push('${Routes.works}/${item.id}');
                        },
                      );
                    },
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
    );
  }
}
