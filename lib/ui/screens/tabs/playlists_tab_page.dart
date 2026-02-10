import 'package:app/app/providers/playlists_provider.dart';
import 'package:app/app/routing/routes.dart';
import 'package:app/design/layout_constants.dart';
import 'package:app/domain/models/playlist.dart';
import 'package:app/theme/app_color.dart';
import 'package:app/widgets/error_view.dart';
import 'package:app/widgets/loading_view.dart';
import 'package:app/widgets/playlist/playlist_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

/// Playlists tab page with curated and personal playlists.
class PlaylistsTabPage extends ConsumerStatefulWidget {
  /// Creates a PlaylistsTabPage.
  const PlaylistsTabPage({super.key});

  @override
  ConsumerState<PlaylistsTabPage> createState() => PlaylistsTabPageState();
}

/// State for PlaylistsTabPage.
class PlaylistsTabPageState extends ConsumerState<PlaylistsTabPage>
    with AutomaticKeepAliveClientMixin {
  static const int _previewCount = 5;

  final ScrollController _scrollController = ScrollController();

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);

    // Trigger initial load for both curated and personal (old repo semantics).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(playlistsProvider(PlaylistType.dp1).notifier).loadPlaylists();
      ref
          .read(playlistsProvider(PlaylistType.addressBased).notifier)
          .loadPlaylists();
    });
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels + 100 >=
        _scrollController.position.maxScrollExtent) {
      // Load more curated only (pagination applies to dp1).
      ref.read(playlistsProvider(PlaylistType.dp1).notifier).loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    // Watch slices to avoid rebuilds when unrelated state changes.
    final curatedSlice = ref.watch(
      playlistsProvider(PlaylistType.dp1).select((s) => (
        playlists: s.playlists,
        isLoading: s.isLoading,
        error: s.error,
        hasMore: s.hasMore,
      )),
    );
    final personalSlice = ref.watch(
      playlistsProvider(PlaylistType.addressBased).select((s) => (
        playlists: s.playlists,
        isLoading: s.isLoading,
        error: s.error,
      )),
    );
    final curatedPlaylists = curatedSlice.playlists;
    final personalPlaylists = personalSlice.playlists;
    final isLoading = curatedSlice.isLoading || personalSlice.isLoading;
    final error = curatedSlice.error ?? personalSlice.error;
    final hasMore = curatedSlice.hasMore;

    // Match old app: Use CustomScrollView with NeverScrollableScrollPhysics.
    // Parent NestedScrollView handles scrolling.
    return CustomScrollView(
      shrinkWrap: true,
      controller: _scrollController,
      physics: const NeverScrollableScrollPhysics(),
      slivers: [
        // Loading state
        if (isLoading && curatedPlaylists.isEmpty && personalPlaylists.isEmpty)
          const SliverToBoxAdapter(child: LoadingView()),

        // Error state
        if (error != null &&
            curatedPlaylists.isEmpty &&
            personalPlaylists.isEmpty)
          SliverToBoxAdapter(
            child: ErrorView(
              error:
                  'We couldn’t load playlists. Check your connection, then Retry.',
              onRetry: () {
                ref
                    .read(playlistsProvider(PlaylistType.dp1).notifier)
                    .loadPlaylists();
                ref
                    .read(playlistsProvider(PlaylistType.addressBased).notifier)
                    .loadPlaylists();
              },
            ),
          ),

        // Personal playlists section (preview).
        if (personalPlaylists.isNotEmpty)
          SliverToBoxAdapter(
            child: PlaylistSection(
              sectionName: 'Personal',
              sectionIcon: SvgPicture.asset(
                'assets/images/icon_account.svg',
                width: LayoutConstants.iconSizeDefault,
                height: LayoutConstants.iconSizeDefault,
                colorFilter: const ColorFilter.mode(
                  AppColor.auQuickSilver,
                  BlendMode.srcIn,
                ),
              ),
              playlists: personalPlaylists.take(_previewCount).toList(),
              hasMore: personalPlaylists.length > _previewCount,
              onViewAllTap: personalPlaylists.length > _previewCount
                  ? () => context.push('${Routes.allPlaylists}?filter=personal')
                  : null,
              onPlaylistItemTap: (_) {},
            ),
          ),

        // Curated playlists section (preview).
        if (curatedPlaylists.isNotEmpty)
          SliverToBoxAdapter(
            child: PlaylistSection(
              sectionName: 'Curated',
              sectionIcon: SvgPicture.asset(
                'assets/images/D.svg',
                width: LayoutConstants.iconSizeDefault,
                height: LayoutConstants.iconSizeDefault,
                colorFilter: const ColorFilter.mode(
                  AppColor.auQuickSilver,
                  BlendMode.srcIn,
                ),
              ),
              playlists: curatedPlaylists.take(_previewCount).toList(),
              hasMore: hasMore || curatedPlaylists.length > _previewCount,
              onViewAllTap: (hasMore || curatedPlaylists.length > _previewCount)
                  ? () => context.push('${Routes.allPlaylists}?filter=curated')
                  : null,
              onPlaylistItemTap: (_) {},
            ),
          ),

        // Spacing between sections.
        SliverToBoxAdapter(
          child: SizedBox(height: LayoutConstants.space12),
        ),
      ],
    );
  }
}
