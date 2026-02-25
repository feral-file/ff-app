import 'package:app/app/providers/playlist_details_provider.dart';
import 'package:app/app/routing/routes.dart';
import 'package:app/design/layout_constants.dart';
import 'package:app/domain/models/playlist.dart';
import 'package:app/domain/models/playlist_item.dart';
import 'package:app/widgets/dp1_carousel.dart';
import 'package:app/widgets/error_view.dart';
import 'package:app/widgets/playlist/playlist_title.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Playlist List Row - Combines list item info with carousel content.
/// Uses domain models (Playlist, PlaylistItem) only.
class PlaylistRowItem extends ConsumerStatefulWidget {
  /// Creates a PlaylistRowItem.
  const PlaylistRowItem({
    required this.playlist,
    this.playlistCreator,
    this.onItemTap,
    this.scrollController,
    this.isActive = true,
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

  /// Whether this row should actively listen to providers.
  final bool isActive;

  /// Optional custom header builder.
  final Widget? Function(Playlist playlist, int itemCount)? headerBuilder;

  @override
  ConsumerState<PlaylistRowItem> createState() => _PlaylistRowItemState();
}

class _PlaylistRowItemState extends ConsumerState<PlaylistRowItem> {
  static const int _loadingItemsCount = 8;

  late ScrollController _carouselScrollController;
  AsyncValue<PlaylistDetailsState> _cachedDetailsAsync =
      const AsyncValue<PlaylistDetailsState>.loading();

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

  @override
  void didUpdateWidget(covariant PlaylistRowItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.playlist.id != widget.playlist.id) {
      _cachedDetailsAsync = const AsyncValue<PlaylistDetailsState>.loading();
    }
  }

  void _onScrollListener() {
    final scrollController = _carouselScrollController;
    if (scrollController.position.pixels >=
        scrollController.position.maxScrollExtent * 0.8) {
      ref.read(playlistDetailsProvider(widget.playlist.id).notifier).loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final playlist = widget.playlist;
    final playlistTitle = playlist.name;
    final creator = widget.playlistCreator ?? '';

    final detailsAsync = widget.isActive
        ? ref.watch(playlistDetailsProvider(playlist.id))
        : _cachedDetailsAsync;
    if (widget.isActive) {
      _cachedDetailsAsync = detailsAsync;
    }
    final isLoading = detailsAsync.isLoading;

    return GestureDetector(
      onTap: isLoading
          ? null
          : () {
              context.push('${Routes.playlists}/${playlist.id}');
            },
      child: Container(
        decoration: const BoxDecoration(
          border: Border(
            bottom: BorderSide(
              
            ),
          ),
        ),
        padding: EdgeInsets.only(bottom: LayoutConstants.space3),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            detailsAsync.when(
              data: (state) =>
                  widget.headerBuilder?.call(
                    playlist,
                    state.total,
                  ) ??
                  PlaylistTitle(
                    primaryText: playlistTitle,
                    secondaryText: creator,
                    total: state.total,
                  ),
              loading: () => PlaylistTitle(
                primaryText: playlistTitle,
                secondaryText: creator,
              ),
              error: (_, __) => PlaylistTitle(
                primaryText: playlistTitle,
                secondaryText: creator,
              ),
            ),
            detailsAsync.when(
              data: (state) {
                if (state.items.isEmpty) {
                  return const SizedBox.shrink();
                }
                return DP1Carousel(
                  items: state.items,
                  onItemTap: widget.onItemTap,
                  scrollController: _carouselScrollController,
                  isLoadingMore: state.isLoadingMore,
                );
              },
              loading: _buildLoadingCarousel,
              error: (_, __) => SizedBox(
                height: LayoutConstants.dp1CarouselHeight,
                child: ErrorView(
                  error: 'We couldn’t load works in this playlist.',
                  onRetry: () =>
                      ref.invalidate(playlistDetailsProvider(playlist.id)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingCarousel() {
    final placeholderItems = List<PlaylistItem>.generate(
      _loadingItemsCount,
      (index) => PlaylistItem(
        id: 'pl_loading_$index',
        kind: PlaylistItemKind.dp1Item,
        title: 'Loading',
      ),
      growable: false,
    );

    return DP1Carousel(
      items: placeholderItems,
      scrollController: _carouselScrollController,
    );
  }
}
