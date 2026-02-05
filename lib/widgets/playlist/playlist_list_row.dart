import 'package:app/app/routing/routes.dart';
import 'package:app/design/layout_constants.dart';
import 'package:app/domain/models/playlist.dart';
import 'package:app/domain/models/playlist_item.dart';
import 'package:app/infra/database/database_provider.dart';
import 'package:app/theme/app_color.dart';
import 'package:app/widgets/dp1_carousel.dart';
import 'package:app/widgets/error_view.dart';
import 'package:app/widgets/loading_view.dart';
import 'package:app/widgets/playlist/playlist_title.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod/src/providers/stream_provider.dart';

/// Stream of playlist items (domain) for a playlist.
final StreamProviderFamily<List<PlaylistItem>, String>
playlistItemsStreamProvider = StreamProvider.family<List<PlaylistItem>, String>(
  (ref, playlistId) {
    final databaseService = ref.watch(databaseServiceProvider);
    return databaseService.watchPlaylistItems(playlistId);
  },
);

/// Playlist List Row - Combines list item info with carousel content.
/// Uses domain models (Playlist, PlaylistItem) only.
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

  /// Playlist to display (domain).
  final Playlist playlist;

  /// Optional creator name to display.
  final String? playlistCreator;

  /// Callback when a carousel item is tapped.
  final void Function(PlaylistItem item)? onItemTap;

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

    final itemsAsync = ref.watch(playlistItemsStreamProvider(playlist.id));

    return GestureDetector(
      onTap: () {
        context.go('${Routes.playlists}/${playlist.id}');
      },
      child: Container(
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: AppColor.primaryBlack,
              width: LayoutConstants.dividerThickness,
            ),
          ),
        ),
        padding: EdgeInsets.only(bottom: LayoutConstants.space3),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            itemsAsync.when(
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
            itemsAsync.when(
              data: (items) {
                if (items.isEmpty) {
                  return const SizedBox.shrink();
                }
                return DP1Carousel(
                  items: items,
                  onItemTap: widget.onItemTap,
                  scrollController: _carouselScrollController,
                  isLoadingMore: false,
                );
              },
              loading: () => SizedBox(
                height: LayoutConstants.dp1CarouselHeight,
                child: const LoadingView(),
              ),
              error: (_, __) => SizedBox(
                height: LayoutConstants.dp1CarouselHeight,
                child: ErrorView(
                  error: 'We couldn’t load works in this playlist.',
                  onRetry: null,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
