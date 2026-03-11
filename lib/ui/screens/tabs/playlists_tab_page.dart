import 'dart:async';

import 'package:app/app/providers/me_section_playlists_provider.dart';
import 'package:app/app/providers/playlists_provider.dart';
import 'package:app/app/providers/seed_database_provider.dart';
import 'package:app/app/providers/services_provider.dart';
import 'package:app/app/routing/routes.dart';
import 'package:app/design/layout_constants.dart';
import 'package:app/domain/models/playlist.dart';
import 'package:app/theme/app_color.dart';
import 'package:app/ui/screens/tabs/tab_reload_guard.dart';
import 'package:app/widgets/error_view.dart';
import 'package:app/widgets/playlist/playlist_header_with_collection_state.dart';
import 'package:app/widgets/playlist/playlist_section.dart';
import 'package:app/widgets/playlist/playlist_title.dart';
import 'package:app/widgets/seed_sync_loading_indicator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

/// Playlists tab page with curated and personal playlists.
class PlaylistsTabPage extends ConsumerStatefulWidget {
  /// Creates a PlaylistsTabPage.
  const PlaylistsTabPage({
    required this.isActive,
    super.key,
  });

  /// Whether this tab is currently active.
  final bool isActive;

  @override
  ConsumerState<PlaylistsTabPage> createState() => PlaylistsTabPageState();
}

/// State for PlaylistsTabPage.
class PlaylistsTabPageState extends ConsumerState<PlaylistsTabPage>
    with AutomaticKeepAliveClientMixin {
  static const int _previewCount = 5;

  final ScrollController _scrollController = ScrollController();
  PlaylistsState _cachedCuratedState = PlaylistsState.initial();
  MeSectionPlaylistsState _cachedMeSectionState = MeSectionPlaylistsState.initial;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!widget.isActive) return;
      _loadPlaylists();
    });
  }

  @override
  void didUpdateWidget(covariant PlaylistsTabPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.isActive && widget.isActive) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !widget.isActive) return;
        _loadPlaylists();
      });
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!widget.isActive) return;
    if (_scrollController.position.pixels + 100 >=
        _scrollController.position.maxScrollExtent) {
      // Load more curated only (pagination applies to dp1).
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

  void _loadPlaylists() {
    final curatedState = ref.read(playlistsProvider(PlaylistType.dp1));
    final shouldLoadCurated = shouldLoadTabData(
      isLoading: curatedState.isLoading,
      hasCachedItems: curatedState.playlists.isNotEmpty,
      hasError: curatedState.error != null,
    );
    if (shouldLoadCurated) {
      ref.read(playlistsProvider(PlaylistType.dp1).notifier).loadPlaylists();
    }

    // Me section uses meSectionPlaylistsProvider (auto-loads on watch).
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final seedState = ref.watch(seedDownloadProvider);
    if (seedState.status == SeedDownloadStatus.syncing) {
      return SeedSyncLoadingIndicator(
        progress: seedState.progress,
      );
    }
    if (seedState.status == SeedDownloadStatus.error) {
      return Center(
        child: ErrorView(
          error:
              seedState.errorMessage ??
              "We couldn't prepare your feed. Check your connection, "
                  'then Retry.',
          onRetry: () => unawaited(ref.read(seedDownloadRetryProvider)()),
        ),
      );
    }

    // Watch curated (dp1) and Me section (Favorite, address-based).
    final nextCuratedState = widget.isActive
        ? ref.watch(playlistsProvider(PlaylistType.dp1))
        : _cachedCuratedState;
    final nextMeSectionAsync = widget.isActive
        ? ref.watch(meSectionPlaylistsProvider)
        : null;
    // When loading, use initial (empty) to avoid showing stale favorites after
    // Forget I Exist. Do not fall back to cache during reload.
    final nextMeSectionState = nextMeSectionAsync?.when(
          data: (v) => v,
          loading: () => MeSectionPlaylistsState.initial,
          error: (_, _) => null,
        ) ?? _cachedMeSectionState;

    final shouldKeepCuratedSnapshot =
        widget.isActive &&
        _cachedCuratedState.playlists.isNotEmpty &&
        nextCuratedState.playlists.isEmpty &&
        nextCuratedState.isLoading;

    final curatedState =
        shouldKeepCuratedSnapshot ? _cachedCuratedState : nextCuratedState;
    if (widget.isActive) {
      if (!shouldKeepCuratedSnapshot) {
        _cachedCuratedState = nextCuratedState;
      }
      final meSectionData = nextMeSectionAsync?.when(
        data: (v) => v,
        loading: () => null,
        error: (_, _) => null,
      );
      if (meSectionData != null) {
        _cachedMeSectionState = meSectionData;
      }
    }
    // When active, use nextMeSectionState so loading shows empty (e.g. after
    // Forget I Exist). When inactive, use cache.
    final displayMeSectionState =
        widget.isActive ? nextMeSectionState : _cachedMeSectionState;
    final personalPlaylists = displayMeSectionState.playlists;
    final error = curatedState.error ?? displayMeSectionState.error;
    final curatedPlaylists = curatedState.playlists;
    final curatedSectionPlaylists = curatedPlaylists.where((playlist) {
      final channelId = playlist.channelId;
      if (channelId == null || channelId.isEmpty) {
        return false;
      }
      return true;
    }).toList();

    // Match old app: Use CustomScrollView with NeverScrollableScrollPhysics.
    // Parent NestedScrollView handles scrolling.
    return CustomScrollView(
      shrinkWrap: true,
      controller: _scrollController,
      physics: const NeverScrollableScrollPhysics(),
      slivers: [
        // Error state
        if (error != null &&
            curatedSectionPlaylists.isEmpty &&
            personalPlaylists.isEmpty)
          SliverToBoxAdapter(
            child: ErrorView(
              error:
                  'We couldn’t load playlists. Check your connection, then Retry.',
              onRetry: () {
                ref
                    .read(playlistsProvider(PlaylistType.dp1).notifier)
                    .loadPlaylists();
                ref.invalidate(meSectionPlaylistsProvider);
              },
            ),
          ),

        // Me section (Favorite, address-based).
        if (personalPlaylists.isNotEmpty)
          SliverToBoxAdapter(
            child: Column(
              children: [
                PlaylistSection(
                  sectionName: 'Me',
                  playlistHeaderBuilder: (playlist, itemCount) {
                    // Favorite playlist: simple title.
                    if (playlist.type == PlaylistType.favorite) {
                      return PlaylistTitle(
                        primaryText: playlist.name,
                        secondaryText: '',
                      );
                    }
                    // Address playlists: collection state header.
                    final ownerAddress = playlist.ownerAddress;
                    if (ownerAddress == null || ownerAddress.isEmpty) {
                      return null;
                    }
                    final creator = _creatorForAddressPlaylist(playlist);
                    return PlaylistHeaderWithCollectionState(
                      primaryText: playlist.name,
                      secondaryText: creator,
                      total: itemCount,
                      ownerAddress: ownerAddress,
                      onRetry: () => ref
                          .read(addressServiceProvider)
                          .indexAndSyncAddress(ownerAddress),
                    );
                  },
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
                  isActive: widget.isActive,
                  hasMore: personalPlaylists.length > _previewCount,
                  onViewAllTap: personalPlaylists.length > _previewCount
                      ? () => context.push(
                          '${Routes.allPlaylists}?filter=personal',
                        )
                      : null,
                  onPlaylistItemTap: (item) {
                    context.push('${Routes.works}/${item.id}');
                  },
                ),
                SizedBox(height: LayoutConstants.space12),
              ],
            ),
          ),

        // Curated playlists section (preview).
        if (curatedSectionPlaylists.isNotEmpty)
          SliverToBoxAdapter(
            child: Column(
              children: [
                PlaylistSection(
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
                  playlists: curatedSectionPlaylists
                      .take(_previewCount)
                      .toList(),
                  isActive: widget.isActive,
                  hasMore: curatedSectionPlaylists.length > _previewCount,
                  onViewAllTap: curatedSectionPlaylists.length > _previewCount
                      ? () => context.push(
                          '${Routes.allPlaylists}?filter=curated',
                        )
                      : null,
                  onPlaylistItemTap: (item) {
                    context.push('${Routes.works}/${item.id}');
                  },
                ),
                SizedBox(height: LayoutConstants.space12),
              ],
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
