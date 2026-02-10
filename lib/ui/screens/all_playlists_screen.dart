import 'package:app/app/providers/playlists_provider.dart';
import 'package:app/app/routing/routes.dart';
import 'package:app/design/app_typography.dart';
import 'package:app/design/layout_constants.dart';
import 'package:app/domain/models/playlist.dart';
import 'package:app/theme/app_color.dart';
import 'package:app/widgets/error_view.dart';
import 'package:app/widgets/load_more_indicator.dart';
import 'package:app/widgets/loading_view.dart';
import 'package:app/widgets/playlist/playlist_list_row.dart';
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

/// Maps UI filter to domain PlaylistType.
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
      ref
          .read(playlistsProvider(_filterToType(widget.filter)).notifier)
          .loadPlaylists();
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

  Future<void> _onRefresh() async {
    await ref
        .read(playlistsProvider(_filterToType(widget.filter)).notifier)
        .refresh();
  }

  @override
  Widget build(BuildContext context) {
    final playlistType = _filterToType(widget.filter);
    final state = ref.watch(playlistsProvider(playlistType));

    final playlists = state.playlists;
    final isLoading = state.isLoading;
    final isLoadingMore = state.isLoadingMore;
    final hasMore = state.hasMore;

    final title = widget.filter == AllPlaylistsFilter.curated
        ? 'Curated'
        : 'Personal';
    final description = widget.filter == AllPlaylistsFilter.curated
        ? 'Playlists curated from DP-1 feeds.'
        : 'Playlists from your saved addresses.';
    final iconAsset = widget.filter == AllPlaylistsFilter.curated
        ? 'assets/images/D.svg'
        : 'assets/images/icon_account.svg';

    return Scaffold(
      backgroundColor: AppColor.auGreyBackground,
      appBar: AppBar(
        backgroundColor: AppColor.auGreyBackground,
        title: Text(
          'Playlists',
          style: AppTypography.h4(context).white,
        ),
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

              if (state.error != null && playlists.isEmpty) {
                return ErrorView(
                  error:
                      'We couldn’t load playlists. Check your connection, then Retry.',
                  onRetry: () => ref
                      .read(playlistsProvider(playlistType).notifier)
                      .loadPlaylists(),
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
                    itemCount: playlists.length,
                    itemBuilder: (context, index) => PlaylistRowItem(
                      playlist: playlists[index],
                      onItemTap: (item) {
                        context.push('${Routes.playlists}/${item.id}');
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
    );
  }
}
