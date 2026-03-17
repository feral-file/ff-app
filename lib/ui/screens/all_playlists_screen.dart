import 'package:app/app/providers/channel_detail_provider.dart';
import 'package:app/app/providers/me_section_playlists_provider.dart';
import 'package:app/app/providers/playlists_provider.dart';
import 'package:app/app/providers/services_provider.dart';
import 'package:app/app/routing/routes.dart';
import 'package:app/design/app_typography.dart';
import 'package:app/design/layout_constants.dart';
import 'package:app/domain/models/channel.dart';
import 'package:app/domain/models/playlist.dart';
import 'package:app/theme/app_color.dart';
import 'package:app/widgets/appbars/main_app_bar.dart';
import 'package:app/widgets/bottom_spacing.dart';
import 'package:app/widgets/error_view.dart';
import 'package:app/widgets/load_more_indicator.dart';
import 'package:app/widgets/loading_view.dart';
import 'package:app/widgets/playlist/playlist_header_with_collection_state.dart';
import 'package:app/widgets/playlist/playlist_list_row.dart';
import 'package:app/widgets/playlist/playlist_title.dart';
import 'package:app/widgets/playlist/section_details_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

/// Parses channel types from query param (comma-separated, e.g. "dp1,localVirtual").
/// Returns null or empty list when param is null/empty.
List<ChannelType>? parseChannelTypes(String? value) {
  if (value == null || value.isEmpty) return null;
  final parts = value.split(',');
  final types = <ChannelType>[];
  for (final part in parts) {
    final parsed = ChannelType.fromString(part);
    if (parsed != null) types.add(parsed);
  }
  return types.isEmpty ? null : types;
}

/// Parses playlist types from query param (comma-separated, e.g. "dp1,favorite").
/// Returns null or empty list when param is null/empty (show all).
List<PlaylistType>? parsePlaylistTypes(String? value) {
  if (value == null || value.isEmpty) return null;
  final parts = value.split(',');
  final types = <PlaylistType>[];
  for (final part in parts) {
    final parsed = PlaylistType.fromString(part);
    if (parsed != null) types.add(parsed);
  }
  return types.isEmpty ? null : types;
}

/// Parses channel IDs from query param (comma-separated).
/// Returns null or empty list when param is null/empty.
List<String>? parseChannelIds(String? value) {
  if (value == null || value.isEmpty) return null;
  final ids = value
      .split(',')
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toList();
  return ids.isEmpty ? null : ids;
}

/// Builds query string for all playlists route.
String buildAllPlaylistsQuery({
  List<ChannelType>? channelTypes,
  List<String>? channelIds,
  List<PlaylistType>? playlistTypes,
}) {
  final params = <String, String>{};
  if (channelTypes != null && channelTypes.isNotEmpty) {
    params['channelTypes'] = channelTypes
        .map((t) => t.toQueryParamString())
        .join(',');
  }
  if (channelIds != null && channelIds.isNotEmpty) {
    params['channelIds'] = channelIds.join(',');
  }
  if (playlistTypes != null && playlistTypes.isNotEmpty) {
    params['playlistTypes'] = playlistTypes
        .map((t) => t.toQueryParamString())
        .join(',');
  }
  if (params.isEmpty) return '';
  return '?${params.entries.map((e) => '${e.key}=${Uri.encodeComponent(e.value)}').join('&')}';
}

/// Payload for the all playlists screen (title, description, icon).
/// Pass via [GoRouterState.extra] when navigating; not in query params.
class AllPlaylistsScreenPayload {
  const AllPlaylistsScreenPayload({
    this.title,
    this.description,
    this.iconAsset,
  });

  final String? title;
  final String? description;
  final String? iconAsset;
}

/// Parsed all-playlists query params (reverse of [buildAllPlaylistsQuery]).
typedef AllPlaylistsQueryParams = ({
  List<ChannelType>? channelTypes,
  List<String>? channelIds,
  List<PlaylistType>? playlistTypes,
});

/// Parses query params produced by [buildAllPlaylistsQuery].
/// Supports both [channelIds] and legacy [channelId] (single).
AllPlaylistsQueryParams parseAllPlaylistsQuery(Map<String, String>? query) {
  if (query == null || query.isEmpty) {
    return (channelTypes: null, channelIds: null, playlistTypes: null);
  }
  final channelIds =
      parseChannelIds(query['channelIds']) ??
      (query['channelId'] != null ? [query['channelId']!] : null);
  return (
    channelTypes: parseChannelTypes(query['channelTypes']),
    channelIds: channelIds,
    playlistTypes: parsePlaylistTypes(query['playlistTypes']),
  );
}

/// Parses all-playlists query from a query string (e.g. "?channelTypes=dp1").
AllPlaylistsQueryParams parseAllPlaylistsQueryFromString(String? queryString) {
  if (queryString == null || queryString.isEmpty) {
    return (channelTypes: null, channelIds: null, playlistTypes: null);
  }
  final s = queryString.startsWith('?') ? queryString : '?$queryString';
  final uri = Uri.parse('http://x/$s');
  return parseAllPlaylistsQuery(uri.queryParameters);
}

/// All playlists screen.
///
/// Mirrors the old app’s "View all" pages while using Riverpod state.
class AllPlaylistsScreen extends ConsumerStatefulWidget {
  /// Creates an [AllPlaylistsScreen].
  const AllPlaylistsScreen({
    this.channelTypes,
    this.channelIds,
    this.playlistTypes,
    this.title,
    this.description,
    this.iconAsset,
    super.key,
  });

  /// Channel types to show playlists for (dp1 = curated, localVirtual = personal).
  /// When null or empty, defaults to [ChannelType.dp1].
  final List<ChannelType>? channelTypes;

  /// Optional channel IDs to filter playlists. When null or empty, ignored.
  final List<String>? channelIds;

  /// Optional playlist types to filter. When null or empty, shows all.
  final List<PlaylistType>? playlistTypes;

  /// Optional section title. When null, the section header is not shown.
  final String? title;

  /// Optional section description. When null, not shown.
  final String? description;

  /// Optional icon asset path. When null, title is shown without icon.
  /// Never shown without title.
  final String? iconAsset;

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
      final types = _effectiveChannelTypes();
      if (_effectiveChannelIds().isEmpty && types.contains(ChannelType.dp1)) {
        ref.read(playlistsProvider(PlaylistType.dp1).notifier).loadPlaylists();
      }
      // Personal and channel-scoped use stream providers (auto-load on watch).
    });
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  List<ChannelType> _effectiveChannelTypes() {
    final types = widget.channelTypes;
    if (types == null || types.isEmpty) return [ChannelType.dp1];
    return types;
  }

  List<String> _effectiveChannelIds() {
    final ids = widget.channelIds;
    if (ids == null || ids.isEmpty) return [];
    return ids;
  }

  void _onScroll() {
    if (_effectiveChannelIds().isNotEmpty) return;
    if (!_effectiveChannelTypes().contains(ChannelType.dp1)) return;
    if (_scrollController.position.pixels + 100 >=
        _scrollController.position.maxScrollExtent) {
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

  Future<void> _onRefresh() async {
    final types = _effectiveChannelTypes();
    final ids = _effectiveChannelIds();
    if (ids.isNotEmpty) {
      ref.invalidate(channelPlaylistsFromIdsProvider(ids.join(',')));
    }
    if (ids.isEmpty && types.contains(ChannelType.dp1)) {
      await ref.read(playlistsProvider(PlaylistType.dp1).notifier).refresh();
    }
    if (types.contains(ChannelType.localVirtual)) {
      ref.invalidate(meSectionPlaylistsProvider);
    }
  }

  List<Playlist> _filterByPlaylistTypes(
    List<Playlist> raw,
    List<PlaylistType>? types,
  ) {
    if (types == null || types.isEmpty) return raw;
    return raw.where((p) => types.contains(p.type)).toList();
  }

  bool _shouldShowAddressHeaders() {
    if (_effectiveChannelIds().isNotEmpty) {
      final types = widget.playlistTypes;
      return types == null ||
          types.isEmpty ||
          types.contains(PlaylistType.addressBased);
    }
    return _effectiveChannelTypes().contains(ChannelType.localVirtual);
  }

  @override
  Widget build(BuildContext context) {
    final ids = _effectiveChannelIds();
    final isChannelScoped = ids.isNotEmpty;
    final channelPlaylistsAsync = isChannelScoped
        ? ref.watch(channelPlaylistsFromIdsProvider(ids.join(',')))
        : null;

    final curatedState = ref.watch(playlistsProvider(PlaylistType.dp1));
    final meSectionAsync = ref.watch(meSectionPlaylistsProvider);

    final meSectionState = meSectionAsync.when(
      data: (v) => v,
      loading: () => null,
      error: (_, _) => null,
    );

    List<Playlist> playlists;
    bool isLoading;
    bool isLoadingMore;
    bool hasMore;
    bool hasError;

    if (isChannelScoped) {
      final raw =
          channelPlaylistsAsync?.when(
            data: (v) => v,
            loading: () => <Playlist>[],
            error: (_, _) => <Playlist>[],
          ) ??
          <Playlist>[];
      playlists = _filterByPlaylistTypes(raw, widget.playlistTypes);
      isLoading = channelPlaylistsAsync?.isLoading ?? true;
      isLoadingMore = false;
      hasMore = false;
      hasError = channelPlaylistsAsync?.hasError ?? false;
    } else {
      final types = _effectiveChannelTypes();
      final hasDp1 = types.contains(ChannelType.dp1);
      final hasLocalVirtual = types.contains(ChannelType.localVirtual);
      if (hasDp1 && hasLocalVirtual) {
        final curated = curatedState.playlists;
        final personal = meSectionState?.playlists ?? [];
        playlists = [...curated, ...personal];
        isLoading =
            curatedState.isLoading ||
            (meSectionAsync.isLoading || (meSectionState?.isLoading == true));
        isLoadingMore = curatedState.isLoadingMore;
        hasMore = curatedState.hasMore;
        hasError = curatedState.error != null || meSectionAsync.hasError;
      } else if (hasLocalVirtual) {
        playlists = meSectionState?.playlists ?? [];
        isLoading =
            meSectionAsync.isLoading || (meSectionState?.isLoading == true);
        isLoadingMore = false;
        hasMore = false;
        hasError = meSectionAsync.hasError;
      } else {
        playlists = curatedState.playlists;
        isLoading = curatedState.isLoading;
        isLoadingMore = curatedState.isLoadingMore;
        hasMore = curatedState.hasMore;
        hasError = curatedState.error != null;
      }
    }

    final title = widget.title;
    final description = widget.description;
    final iconAsset = widget.iconAsset;

    return Scaffold(
      backgroundColor: AppColor.auGreyBackground,
      appBar: MainAppBar.preferred(
        context,
        backTitle: 'Index',
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

              if (hasError && playlists.isEmpty) {
                return ErrorView(
                  error:
                      'We couldn’t load playlists. Check your connection, then Retry.',
                  onRetry: () {
                    if (isChannelScoped) {
                      ref.invalidate(
                        channelPlaylistsFromIdsProvider(ids.join(',')),
                      );
                    } else if (_effectiveChannelTypes().contains(
                      ChannelType.localVirtual,
                    )) {
                      ref.invalidate(meSectionPlaylistsProvider);
                    }
                    if (_effectiveChannelTypes().contains(ChannelType.dp1)) {
                      ref
                          .read(playlistsProvider(PlaylistType.dp1).notifier)
                          .loadPlaylists();
                    }
                  },
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
                  const SliverToBoxAdapter(child: SizedBox(height: 21)),
                  if (title != null)
                    SliverToBoxAdapter(
                      child: SectionDetailsHeader(
                        icon: iconAsset != null
                            ? SvgPicture.asset(
                                iconAsset,
                                width: LayoutConstants.iconSizeDefault,
                                height: LayoutConstants.iconSizeDefault,
                                colorFilter: const ColorFilter.mode(
                                  AppColor.white,
                                  BlendMode.srcIn,
                                ),
                              )
                            : null,
                        title: title,
                        description: description,
                      ),
                    ),
                  const SliverToBoxAdapter(child: SizedBox(height: 50)),
                  SliverList.builder(
                    itemCount: playlists.length,
                    itemBuilder: (context, index) {
                      final playlist = playlists[index];
                      return PlaylistRowItem(
                        playlist: playlist,
                        headerBuilder: _shouldShowAddressHeaders()
                            ? (p, itemCount) {
                                if (p.type == PlaylistType.favorite) {
                                  return PlaylistTitle(
                                    primaryText: p.name,
                                    secondaryText: '',
                                  );
                                }
                                final ownerAddress = p.ownerAddress;
                                if (ownerAddress == null ||
                                    ownerAddress.isEmpty) {
                                  return null;
                                }
                                final creator = _creatorForAddressPlaylist(p);
                                return PlaylistHeaderWithCollectionState(
                                  primaryText: p.name,
                                  secondaryText: creator,
                                  total: itemCount,
                                  ownerAddress: ownerAddress,
                                  onRetry: () => ref
                                      .read(addressServiceProvider)
                                      .indexAndSyncAddress(ownerAddress),
                                );
                              }
                            : null,
                        onItemTap: (item) {
                          context.push('${Routes.works}/${item.id}');
                        },
                      );
                    },
                  ),
                  if (hasMore || isLoadingMore)
                    SliverToBoxAdapter(
                      child: LoadMoreIndicator(isLoadingMore: isLoadingMore),
                    ),
                  const SliverToBoxAdapter(child: BottomSpacing()),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
