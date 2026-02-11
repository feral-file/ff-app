import 'package:app/app/providers/playlists_provider.dart';
import 'package:app/app/providers/remote_config_provider.dart';
import 'package:app/app/routing/routes.dart';
import 'package:app/design/layout_constants.dart';
import 'package:app/domain/models/playlist.dart';
import 'package:app/theme/app_color.dart';
import 'package:app/widgets/error_view.dart';
import 'package:app/widgets/playlist/playlist_section.dart';
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
  PlaylistsState _cachedPersonalState = PlaylistsState.initial();

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

  void _loadPlaylists() {
    ref.read(playlistsProvider(PlaylistType.dp1).notifier).loadPlaylists();
    ref
        .read(playlistsProvider(PlaylistType.addressBased).notifier)
        .loadPlaylists();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    // Watch both providers (curated = dp1, personal = addressBased).
    final nextCuratedState = widget.isActive
        ? ref.watch(playlistsProvider(PlaylistType.dp1))
        : _cachedCuratedState;
    final nextPersonalState = widget.isActive
        ? ref.watch(playlistsProvider(PlaylistType.addressBased))
        : _cachedPersonalState;
    final shouldKeepSnapshot =
        widget.isActive &&
        (_cachedCuratedState.playlists.isNotEmpty ||
            _cachedPersonalState.playlists.isNotEmpty) &&
        nextCuratedState.playlists.isEmpty &&
        nextPersonalState.playlists.isEmpty &&
        (nextCuratedState.isLoading || nextPersonalState.isLoading);

    final curatedState = shouldKeepSnapshot
        ? _cachedCuratedState
        : nextCuratedState;
    final personalState = shouldKeepSnapshot
        ? _cachedPersonalState
        : nextPersonalState;
    if (widget.isActive && !shouldKeepSnapshot) {
      _cachedCuratedState = nextCuratedState;
      _cachedPersonalState = nextPersonalState;
    }
    final curatedPlaylists = curatedState.playlists;
    final curatedBaseUrl = _firstCuratedBaseUrl();
    final curatedSectionPlaylists = curatedBaseUrl == null
        ? curatedPlaylists
        : curatedPlaylists
              .where((playlist) => playlist.baseUrl == curatedBaseUrl)
              .toList();
    final personalPlaylists = personalState.playlists;
    final error = curatedState.error ?? personalState.error;

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
              isActive: widget.isActive,
              hasMore: personalPlaylists.length > _previewCount,
              onViewAllTap: personalPlaylists.length > _previewCount
                  ? () => context.push('${Routes.allPlaylists}?filter=personal')
                  : null,
              onPlaylistItemTap: (item) {
                context.push('${Routes.works}/${item.id}');
              },
            ),
          ),

        // Curated playlists section (preview).
        if (curatedSectionPlaylists.isNotEmpty)
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
              playlists: curatedSectionPlaylists.take(_previewCount).toList(),
              isActive: widget.isActive,
              hasMore: curatedSectionPlaylists.length > _previewCount,
              onViewAllTap: curatedSectionPlaylists.length > _previewCount
                  ? () => context.push('${Routes.allPlaylists}?filter=curated')
                  : null,
              onPlaylistItemTap: (item) {
                context.push('${Routes.works}/${item.id}');
              },
            ),
          ),

        // Spacing between sections.
        SliverToBoxAdapter(
          child: SizedBox(height: LayoutConstants.space12),
        ),
      ],
    );
  }

  String? _firstCuratedBaseUrl() {
    final curatedUrls = ref.watch(curatedChannelUrlsProvider);
    if (curatedUrls.isEmpty) {
      return null;
    }

    final firstUrl = curatedUrls.first.trim();
    if (firstUrl.isEmpty) {
      return null;
    }

    try {
      final uri = Uri.parse(firstUrl);
      if (!uri.hasScheme || uri.host.isEmpty) {
        return null;
      }
      return uri.origin;
    } on FormatException {
      return null;
    }
  }
}
