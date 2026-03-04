import 'package:app/app/providers/address_indexing_job_provider.dart';
import 'package:app/app/providers/playlist_details_provider.dart';
import 'package:app/app/routing/routes.dart';
import 'package:app/design/layout_constants.dart';
import 'package:app/domain/extensions/playlist_ext.dart';
import 'package:app/domain/models/playlist.dart';
import 'package:app/domain/models/playlist_item.dart';
import 'package:app/infra/config/app_state_service.dart';
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

    final nextDetailsAsync = widget.isActive
        ? ref.watch(playlistDetailsProvider(playlist.id))
        : _cachedDetailsAsync;

    // When the autoDispose provider is recreated after a tab switch it starts
    // in AsyncLoading. If we already have data in cache, keep showing it until
    // the new provider delivers fresh data — prevents a skeleton flash on every
    // tab switch.
    final shouldKeepCached =
        widget.isActive &&
        _cachedDetailsAsync is AsyncData<PlaylistDetailsState> &&
        nextDetailsAsync.isLoading;

    final detailsAsync = shouldKeepCached
        ? _cachedDetailsAsync
        : nextDetailsAsync;
    if (widget.isActive && !shouldKeepCached) {
      _cachedDetailsAsync = nextDetailsAsync;
    }
    final isLoading = detailsAsync.isLoading;

    // For address playlists with empty items: show loading skeleton until
    // indexing completes (or fails). Prevents bounce when tokens are not yet
    // ingested.
    AddressIndexingProcessStatus? processStatus;
    if (playlist.isAddressPlaylist && playlist.ownerAddress != null) {
      final statusAsync = ref.watch(
        addressIndexingProcessStatusProvider(playlist.ownerAddress!),
      );
      processStatus = switch (statusAsync) {
        AsyncData(value: final v) => v,
        _ => null,
      };
    }

    return GestureDetector(
      onTap: isLoading
          ? null
          : () {
              context.push('${Routes.playlists}/${playlist.id}');
            },
      child: Container(
        decoration: const BoxDecoration(
          border: Border(
            bottom: BorderSide(),
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
                  ),
              loading: () => PlaylistTitle(
                primaryText: playlistTitle,
                secondaryText: creator,
              ),
              error: (_, _) => PlaylistTitle(
                primaryText: playlistTitle,
                secondaryText: creator,
              ),
            ),
            detailsAsync.when(
              data: (state) {
                final itemsEmpty = state.items.isEmpty;
                final showLoadingSkeleton = itemsEmpty &&
                    playlist.isAddressPlaylist &&
                    processStatus?.state !=
                        AddressIndexingProcessState.completed &&
                    processStatus?.state !=
                        AddressIndexingProcessState.failed &&
                    processStatus?.state !=
                        AddressIndexingProcessState.stopped;
                return DP1Carousel(
                  items: state.items,
                  isLoading: showLoadingSkeleton,
                  onItemTap: widget.onItemTap,
                  scrollController: _carouselScrollController,
                  isLoadingMore: state.isLoadingMore,
                );
              },
              loading: () => DP1Carousel(
                items: const [],
                isLoading: true,
                scrollController: _carouselScrollController,
              ),
              error: (_, _) => SizedBox(
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
