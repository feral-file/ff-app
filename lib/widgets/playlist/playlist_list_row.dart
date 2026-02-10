import 'package:app/app/providers/playlist_details_provider.dart';
import 'package:app/app/routing/routes.dart';
import 'package:app/design/layout_constants.dart';
import 'package:app/domain/models/playlist.dart';
import 'package:app/domain/models/playlist_item.dart';
import 'package:app/theme/app_color.dart';
import 'package:app/widgets/dp1_carousel.dart';
import 'package:app/widgets/error_view.dart';
import 'package:app/widgets/loading_view.dart';
import 'package:app/widgets/playlist/playlist_title.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Playlist List Row - Combines list item info with carousel content.
/// Uses domain models (Playlist, PlaylistItem) only.
/// Only watches [playlistDetailsProvider]; no separate playlist items provider.
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
      ref.read(playlistDetailsProvider(widget.playlist.id).notifier).loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final playlist = widget.playlist;
    final playlistTitle = playlist.name;
    final creator = widget.playlistCreator ?? '';

    final detailsAsync = ref.watch(playlistDetailsProvider(playlist.id));

    return GestureDetector(
      onTap: () {
        context.push('${Routes.playlists}/${playlist.id}');
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
            detailsAsync.when(
              data: (state) => widget.headerBuilder?.call(
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
              loading: () => SizedBox(
                height: LayoutConstants.dp1CarouselHeight,
                child: const LoadingView(),
              ),
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
}
