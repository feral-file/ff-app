import 'package:app/app/providers/playlists_provider.dart';
import 'package:app/design/app_typography.dart';
import 'package:app/design/layout_constants.dart';
import 'package:app/domain/models/playlist.dart';
import 'package:app/theme/app_color.dart';
import 'package:app/widgets/playlist/playlist_list_row.dart';
import 'package:app/widgets/playlist/playlist_section_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
  final ScrollController _scrollController = ScrollController();

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);

    // Trigger initial load
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(playlistsProvider.notifier).loadPlaylists();
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
      // Trigger pagination (old repo semantics: load more)
      ref.read(playlistsProvider.notifier).loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    // Use select to optimize rebuilds - only rebuild when these specific fields change
    final isLoading = ref.watch(playlistsProvider.select((s) => s.isLoading));
    final error = ref.watch(playlistsProvider.select((s) => s.error));
    final curatedPlaylists = ref.watch(
      playlistsProvider.select((s) => s.curatedPlaylists),
    );
    final personalPlaylists = ref.watch(
      playlistsProvider.select((s) => s.personalPlaylists),
    );

    // Match old app: Use CustomScrollView with NeverScrollableScrollPhysics
    // Parent NestedScrollView handles scrolling
    return CustomScrollView(
      shrinkWrap: true,
      controller: _scrollController,
      physics: const NeverScrollableScrollPhysics(),
      slivers: [
        // Loading state
        if (isLoading && curatedPlaylists.isEmpty && personalPlaylists.isEmpty)
          const SliverToBoxAdapter(child: _LoadingView()),

        // Error state
        if (error != null &&
            curatedPlaylists.isEmpty &&
            personalPlaylists.isEmpty)
          SliverToBoxAdapter(
            child: _ErrorView(
              error: 'Error loading playlists: $error',
              onRetry: () =>
                  ref.read(playlistsProvider.notifier).loadPlaylists(),
            ),
          ),

        // Personal playlists section
        if (personalPlaylists.isNotEmpty)
          SliverToBoxAdapter(
            child: _buildPersonalPlaylistsSection(personalPlaylists),
          ),

        // Curated playlists section
        if (curatedPlaylists.isNotEmpty)
          SliverToBoxAdapter(
            child: _buildCuratedPlaylistsSection(curatedPlaylists),
          ),
      ],
    );
  }

  Widget _buildPersonalPlaylistsSection(List<Playlist> playlists) {
    return Column(
      children: [
        ...playlists.map(
          (playlist) => PlaylistRowItem(
            playlist: playlist,
            onItemTap: (workId) {
              // TODO: Navigate to work detail page
              // context.go('${Routes.works}/$workId');
            },
          ),
        ),
        SizedBox(height: LayoutConstants.space12),
      ],
    );
  }

  Widget _buildCuratedPlaylistsSection(List<Playlist> playlists) {
    // Show max 5 playlists, with "View All" if more exist
    final displayPlaylists = playlists.take(5).toList();
    final hasMore = playlists.length > 5;

    return Column(
      children: [
        PlaylistSectionHeader(
          sectionName: 'Curated',
          hasMore: hasMore,
          onViewAllTap: hasMore
              ? () {
                  // TODO: Navigate to all playlists page
                }
              : null,
        ),
        const SizedBox(height: 10),
        ...displayPlaylists.map(
          (playlist) => PlaylistRowItem(
            playlist: playlist,
            onItemTap: (workId) {
              // TODO: Navigate to work detail page
              // context.go('${Routes.works}/$workId');
            },
          ),
        ),
        SizedBox(height: LayoutConstants.space12),
      ],
    );
  }
}

/// Simple loading widget matching old app design.
class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: CircularProgressIndicator(
        color: AppColor.white,
      ),
    );
  }
}

/// Simple error widget matching old app design.
class _ErrorView extends StatelessWidget {
  const _ErrorView({
    required this.error,
    this.onRetry,
  });

  final String error;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: LayoutConstants.pageHorizontalDefault,
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              error,
              style: AppTypography.body(context).grey,
              textAlign: TextAlign.center,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: onRetry,
                child: Text(
                  'Retry',
                  style: AppTypography.body(context).white,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
