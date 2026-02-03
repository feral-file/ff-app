import 'package:app/app/routing/routes.dart';
import 'package:app/domain/models/playlist.dart';
import 'package:app/domain/models/playlist_item.dart';
import 'package:app/infra/database/database_provider.dart';
import 'package:app/widgets/dp1_carousel.dart';
import 'package:app/widgets/playlist/playlist_title.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Provider for fetching playlist items by playlist ID.
final playlistItemsProvider =
    FutureProvider.family<List<PlaylistItem>, String>((ref, playlistId) async {
  final databaseService = ref.watch(databaseServiceProvider);
  return databaseService.getPlaylistItems(playlistId);
});

/// Playlist List Row - Combines list item info with carousel content
class PlaylistRowItem extends ConsumerStatefulWidget {
  /// Creates a PlaylistRowItem.
  const PlaylistRowItem({
    required this.playlist,
    this.playlistCreator,
    this.onItemTap,
    this.scrollController,
    this.headerBuilder,
    super.key,
  });

  /// Playlist to display.
  final Playlist playlist;

  /// Optional creator name to display.
  final String? playlistCreator;

  /// Callback when a carousel item is tapped.
  final void Function(String workId)? onItemTap;

  /// Optional scroll controller for carousel.
  final ScrollController? scrollController;

  /// Optional custom header builder.
  final Widget? Function(Playlist playlist, int itemCount)? headerBuilder;

  @override
  ConsumerState<PlaylistRowItem> createState() => _PlaylistRowItemState();
}

class _PlaylistRowItemState extends ConsumerState<PlaylistRowItem> {
  late ScrollController _carouselScrollController;

  @override
  void initState() {
    super.initState();
    _carouselScrollController = widget.scrollController ?? ScrollController();
    _carouselScrollController.addListener(_onScrollListener);
  }

  @override
  void dispose() {
    _carouselScrollController.removeListener(_onScrollListener);
    if (widget.scrollController == null) {
      _carouselScrollController.dispose();
    }
    super.dispose();
  }

  void _onScrollListener() {
    final scrollController = _carouselScrollController;
    if (scrollController.position.pixels >=
        scrollController.position.maxScrollExtent * 0.8) {
      // TODO: Implement load more for playlist items
      // For now, we load all items at once
    }
  }

  @override
  Widget build(BuildContext context) {
    final playlist = widget.playlist;
    final playlistTitle = playlist.name;
    final creator = widget.playlistCreator ?? '';

    // Watch playlist items
    final playlistItemsAsync = ref.watch(playlistItemsProvider(playlist.id));

    return GestureDetector(
      onTap: () {
        context.go('${Routes.playlists}/${playlist.id}');
      },
      child: Container(
        decoration: const BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: Colors.black,
              width: 1,
            ),
          ),
        ),
        padding: const EdgeInsets.only(bottom: 11),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            playlistItemsAsync.when(
              data: (items) {
                return widget.headerBuilder?.call(playlist, items.length) ??
                    PlaylistTitle(
                      primaryText: playlistTitle,
                      secondaryText: creator,
                      total: items.length,
                    );
              },
              loading: () => PlaylistTitle(
                primaryText: playlistTitle,
                secondaryText: creator,
              ),
              error: (_, __) => PlaylistTitle(
                primaryText: playlistTitle,
                secondaryText: creator,
              ),
            ),
            // Carousel
            playlistItemsAsync.when(
              data: (items) {
                if (items.isEmpty) {
                  return const SizedBox.shrink();
                }

                // Convert PlaylistItem to WorkItemData
                final workItems = items.map((item) {
                  return WorkItemData(
                    workId: item.id,
                    thumbnailUrl: item.thumbnailUrl ?? '',
                    title: item.title,
                    artist: item.artistName,
                  );
                }).toList();

                return DP1Carousel(
                  items: workItems,
                  onItemTap: widget.onItemTap,
                  scrollController: _carouselScrollController,
                  isLoadingMore: false,
                );
              },
              loading: () => const SizedBox(
                height: 285,
                child: Center(
                  child: CircularProgressIndicator(
                    color: Colors.white,
                  ),
                ),
              ),
              error: (error, _) => SizedBox(
                height: 285,
                child: Center(
                  child: Text(
                    'Error loading items',
                    style: const TextStyle(color: Colors.grey),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
