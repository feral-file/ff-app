import 'package:app/app/providers/search_provider.dart';
import 'package:app/app/routing/routes.dart';
import 'package:app/design/app_typography.dart';
import 'package:app/design/layout_constants.dart';
import 'package:app/domain/models/channel.dart';
import 'package:app/domain/models/playlist.dart';
import 'package:app/domain/models/playlist_item.dart';
import 'package:app/theme/app_color.dart';
import 'package:easy_debounce/easy_debounce.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Search tab page with debounced search functionality.
class SearchTabPage extends ConsumerStatefulWidget {
  /// Creates a SearchTabPage.
  const SearchTabPage({super.key});

  @override
  ConsumerState<SearchTabPage> createState() => _SearchTabPageState();
}

class _SearchTabPageState extends ConsumerState<SearchTabPage>
    with AutomaticKeepAliveClientMixin {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    // Auto-focus on search when tab is opened
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _searchFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    EasyDebounce.cancel('search');
    super.dispose();
  }

  void _onSearchChanged(String query) {
    // Debounce search to avoid excessive queries
    EasyDebounce.debounce(
      'search',
      const Duration(milliseconds: 500),
      () {
        ref.read(searchQueryProvider.notifier).setQuery(query);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final searchQuery = ref.watch(searchQueryProvider);
    final searchResultsAsync = ref.watch(searchResultsProvider);

    return Scaffold(
      backgroundColor: AppColor.auGreyBackground,
      appBar: AppBar(
        backgroundColor: AppColor.auGreyBackground,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColor.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Search',
          style: AppTypography.h4(context).white,
        ),
      ),
      body: Column(
        children: [
          // Search input
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: LayoutConstants.pageHorizontalDefault,
              vertical: LayoutConstants.space3,
            ),
            child: TextField(
            controller: _searchController,
            focusNode: _searchFocusNode,
            style: AppTypography.body(context).white,
            decoration: InputDecoration(
              hintText: 'Search channels, playlists, works...',
              hintStyle: AppTypography.body(context).grey,
              filled: true,
              fillColor: AppColor.darkGrey,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
              prefixIcon: const Icon(
                Icons.search,
                color: AppColor.auQuickSilver,
              ),
              suffixIcon: searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(
                        Icons.clear,
                        color: AppColor.auQuickSilver,
                      ),
                      onPressed: () {
                        _searchController.clear();
                        ref.read(searchQueryProvider.notifier).clear();
                        EasyDebounce.cancel('search');
                      },
                    )
                  : null,
            ),
            onChanged: _onSearchChanged,
          ),
        ),

          // Search results
          Expanded(
            child: searchResultsAsync.when(
              data: (results) {
                if (searchQuery.isEmpty) {
                  return _buildEmptyState();
                }

                if (results.isEmpty) {
                  return _buildNoResults(searchQuery);
                }

                // Results available - render sections
                return _buildResults(results);
              },
              loading: () => _buildLoading(),
              error: (error, stack) => _buildError(error.toString()),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(LayoutConstants.space6),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search,
              size: 64,
              color: AppColor.auQuickSilver,
            ),
            SizedBox(height: LayoutConstants.space4),
            Text(
              'Search for anything',
              style: AppTypography.h4(context).white,
            ),
            SizedBox(height: LayoutConstants.space2),
            Text(
              'Find channels, playlists, and works',
              style: AppTypography.bodySmall(context).grey,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoResults(String query) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(LayoutConstants.space6),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 64,
              color: AppColor.auQuickSilver,
            ),
            SizedBox(height: LayoutConstants.space4),
            Text(
              'No results found',
              style: AppTypography.h4(context).white,
            ),
            SizedBox(height: LayoutConstants.space2),
            Text(
              'Try different keywords or check spelling',
              style: AppTypography.bodySmall(context).grey,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoading() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(color: AppColor.feralFileHighlight),
          SizedBox(height: LayoutConstants.space4),
          Text(
            'Searching...',
            style: AppTypography.body(context).grey,
          ),
        ],
      ),
    );
  }

  Widget _buildError(String error) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(LayoutConstants.space6),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 48,
              color: AppColor.error,
            ),
            SizedBox(height: LayoutConstants.space4),
            Text(
              'Search error',
              style: AppTypography.h4(context).white,
            ),
            SizedBox(height: LayoutConstants.space2),
            Text(
              error,
              style: AppTypography.bodySmall(context).grey,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResults(SearchResults results) {
    return ListView(
      padding: EdgeInsets.symmetric(
        horizontal: LayoutConstants.pageHorizontalDefault,
      ),
      children: [
        // Channels section
        if (results.channels.isNotEmpty) ...[
          _buildSectionHeader('Channels (${results.channels.length})'),
          ...results.channels.map((channel) => _buildChannelTile(channel)),
          SizedBox(height: LayoutConstants.space4),
        ],

        // Playlists section
        if (results.playlists.isNotEmpty) ...[
          _buildSectionHeader('Playlists (${results.playlists.length})'),
          ...results.playlists.map((playlist) => _buildPlaylistTile(playlist)),
          SizedBox(height: LayoutConstants.space4),
        ],

        // Works section
        if (results.works.isNotEmpty) ...[
          _buildSectionHeader('Works (${results.works.length})'),
          ...results.works.map((work) => _buildWorkTile(work)),
        ],
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: EdgeInsets.only(
        top: LayoutConstants.space3,
        bottom: LayoutConstants.space2,
      ),
      child: Text(
        title,
        style: AppTypography.h4(context).white,
      ),
    );
  }

  Widget _buildChannelTile(Channel channel) {
    return Padding(
      padding: EdgeInsets.only(bottom: LayoutConstants.space2),
      child: InkWell(
        onTap: () {
          context.go('${Routes.channels}/${channel.id}');
        },
        child: Container(
          padding: EdgeInsets.all(LayoutConstants.space3),
          decoration: BoxDecoration(
            color: AppColor.darkGrey,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(
                channel.isPinned ? Icons.push_pin : Icons.rss_feed,
                color: AppColor.feralFileLightBlue,
              ),
              SizedBox(width: LayoutConstants.space3),
              Expanded(
                child: Text(
                  channel.name,
                  style: AppTypography.body(context).white,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlaylistTile(Playlist playlist) {
    return Padding(
      padding: EdgeInsets.only(bottom: LayoutConstants.space2),
      child: InkWell(
        onTap: () {
          context.go('${Routes.playlists}/${playlist.id}');
        },
        child: Container(
          padding: EdgeInsets.all(LayoutConstants.space3),
          decoration: BoxDecoration(
            color: AppColor.darkGrey,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.playlist_play,
                color: AppColor.feralFileLightBlue,
              ),
              SizedBox(width: LayoutConstants.space3),
              Expanded(
                child: Text(
                  playlist.name,
                  style: AppTypography.body(context).white,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWorkTile(PlaylistItem work) {
    return Padding(
      padding: EdgeInsets.only(bottom: LayoutConstants.space2),
      child: InkWell(
        onTap: () {
          context.go('${Routes.works}/${work.id}');
        },
        child: Container(
          padding: EdgeInsets.all(LayoutConstants.space3),
          decoration: BoxDecoration(
            color: AppColor.darkGrey,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.image,
                color: AppColor.feralFileLightBlue,
              ),
              SizedBox(width: LayoutConstants.space3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      work.title,
                      style: AppTypography.body(context).white,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (work.artistName != null && work.artistName!.isNotEmpty)
                      Text(
                        work.artistName!,
                        style: AppTypography.bodySmall(context).grey,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
