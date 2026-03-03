import 'dart:async';

import 'package:app/app/providers/search_provider.dart';
import 'package:app/app/routing/routes.dart';
import 'package:app/design/app_typography.dart';
import 'package:app/design/layout_constants.dart';
import 'package:app/domain/models/channel.dart';
import 'package:app/domain/models/playlist.dart';
import 'package:app/domain/models/playlist_item.dart';
import 'package:app/theme/app_color.dart';
import 'package:app/ui/screens/tabs/search/search_filter_models.dart';
import 'package:app/ui/screens/tabs/search/search_filtering.dart';
import 'package:app/ui/screens/tabs/search/widgets/filter_bar.dart';
import 'package:app/ui/screens/tabs/search/widgets/search_bar.dart'
    as search_widgets;
import 'package:app/ui/ui_helper.dart';
import 'package:app/widgets/buttons/primary_button.dart';
import 'package:app/widgets/channels/channel_list_row.dart';
import 'package:app/widgets/loading_view.dart';
import 'package:app/widgets/playlist/playlist_list_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

/// Search screen matching the old repo `SearchPage` UI.
class SearchTabPage extends ConsumerStatefulWidget {
  /// Creates a [SearchTabPage].
  const SearchTabPage({super.key});

  @override
  ConsumerState<SearchTabPage> createState() => _SearchTabPageState();
}

class _SearchTabPageState extends ConsumerState<SearchTabPage>
    with AutomaticKeepAliveClientMixin {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  ProviderSubscription<AsyncValue<SearchResults>>? _resultsSubscription;

  SearchResults? _lastSuccessfulResults;
  SearchFilterType _filterType = SearchFilterType.channels;
  SearchSortOrder _sortOrder = SearchSortOrder.relevance;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _resultsSubscription = ref.listenManual<AsyncValue<SearchResults>>(
      searchResultsProvider,
      (_, next) {
        next.whenData((data) {
          if (!mounted) return;
          setState(() {
            _lastSuccessfulResults = data;
            final available = availableTypesFromResults(data);
            final nextType = selectInitialType(
              available: available,
              current: _filterType,
            );
            if (nextType != null) {
              _filterType = nextType;
            }
          });
        });
      },
    );
  }

  @override
  void dispose() {
    _resultsSubscription?.close();
    _resultsSubscription = null;
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onSearchSubmitted(String query) {
    ref.read(searchQueryProvider.notifier).setQuery(query);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final query = ref.watch(searchQueryProvider);
    final resultsAsync = ref.watch(searchResultsProvider);
    final unfilteredResults =
        resultsAsync.asData?.value ??
        _lastSuccessfulResults ??
        const SearchResults(channels: [], playlists: [], works: []);

    final availableTypes = availableTypesFromResults(unfilteredResults);
    final safeFilterType =
        selectInitialType(available: availableTypes, current: _filterType) ??
        _filterType;

    final resultsContent = SizedBox.expand(
      child: Column(
        children: [
          FilterBar(
            selectedFilterType: safeFilterType,
            onFilterTypeChanged: (type) {
              setState(() => _filterType = type);
            },
            availableTypes: availableTypes,
            sortOrder: _sortOrder,
            onSortOrderChanged: (order) {
              setState(() => _sortOrder = order);
            },
          ),
          Expanded(
            child: _buildResultsSection(
              context: context,
              query: query,
              resultsAsync: resultsAsync,
              unfilteredResults: unfilteredResults,
              filterType: safeFilterType,
            ),
          ),
        ],
      ),
    );

    final resultsWithOverlay = (query.isNotEmpty && resultsAsync.isLoading)
        ? Stack(
            children: [
              resultsContent,
              Positioned.fill(
                child: ColoredBox(
                  color: AppColor.auGreyBackground.withValues(alpha: 0.6),
                  child: Center(
                    child: LoadingWidget(
                      backgroundColor: AppColor.auGreyBackground.withValues(
                        alpha: 0.8,
                      ),
                      text: 'Searching...',
                    ),
                  ),
                ),
              ),
            ],
          )
        : resultsContent;

    return Scaffold(
      backgroundColor: AppColor.auGreyBackground,
      appBar: _buildOldStyleSearchAppBar(context),
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.all(LayoutConstants.pageHorizontalDefault),
            child: search_widgets.SearchBar(
              controller: _searchController,
              onSubmitted: _onSearchSubmitted,
              autoFocus: true,
            ),
          ),
          Expanded(child: resultsWithOverlay),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildOldStyleSearchAppBar(BuildContext context) {
    return AppBar(
      systemOverlayStyle: const SystemUiOverlayStyle(
        statusBarColor: AppColor.auGreyBackground,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      centerTitle: true,
      scrolledUnderElevation: 0,
      toolbarHeight: 54,
      leadingWidth: 56,
      leading: IconButton(
        constraints: const BoxConstraints(
          maxWidth: 44,
          maxHeight: 44,
          minWidth: 44,
          minHeight: 44,
        ),
        onPressed: () => Navigator.pop(context),
        icon: SvgPicture.asset(
          'assets/images/icon_back.svg',
          width: 24,
          height: 24,
          colorFilter: const ColorFilter.mode(
            AppColor.white,
            BlendMode.srcIn,
          ),
        ),
      ),
      title: Text(
        'Search',
        overflow: TextOverflow.ellipsis,
        style: AppTypography.body(context).white,
        textAlign: TextAlign.center,
      ),
      actions: const [
        SizedBox(width: 16),
      ],
      backgroundColor: AppColor.auGreyBackground,
      surfaceTintColor: Colors.transparent,
      shadowColor: Colors.transparent,
      elevation: 0,
      bottom: const PreferredSize(
        preferredSize: Size.fromHeight(1),
        child: Divider(
          height: 1,
          thickness: 1,
          color: AppColor.primaryBlack,
        ),
      ),
    );
  }

  Widget _buildResultsSection({
    required BuildContext context,
    required String query,
    required AsyncValue<SearchResults> resultsAsync,
    required SearchResults unfilteredResults,
    required SearchFilterType filterType,
  }) {
    if (resultsAsync.hasError) {
      return _buildErrorView(context);
    }

    if (query.isEmpty) {
      return _buildInitialView(context);
    }

    if (resultsAsync.isLoading) {
      // Don't show empty view while loading (overlay handles it).
      return const SizedBox.shrink();
    }

    final results = resultsAsync.asData?.value ?? unfilteredResults;
    if (results.isEmpty) {
      return _buildEmptyView(context);
    }

    return _buildResultsView(
      context: context,
      results: results,
      filterType: filterType,
    );
  }

  Widget _buildInitialView(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(LayoutConstants.space6),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Search for channels, playlists, or works',
              style: AppTypography.body(context).white,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyView(BuildContext context) {
    final textStyle = AppTypography.body(context).white;
    return SingleChildScrollView(
      child: Padding(
        padding: EdgeInsets.all(LayoutConstants.pageHorizontalDefault),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'No results found',
              style: textStyle.copyWith(fontWeight: FontWeight.w700),
            ),
            SizedBox(height: LayoutConstants.space4),
            Text(
              'Try exhibitions, playlists, artists, or curators. '
              'Collection search will return soon.',
              style: textStyle,
            ),
            SizedBox(height: LayoutConstants.space2),
            Text(
              'Examples: Dmitri Cherniak artworks, generative art exhibitions, '
              'Maya Man',
              style: textStyle,
            ),
            SizedBox(height: LayoutConstants.space2),
            Text(
              "Didn't find what you wanted? Tap Help to tell us.",
              style: textStyle,
            ),
            SizedBox(height: LayoutConstants.space6),
            PrimaryButton(
              onTap: () {
                unawaited(UIHelper.showCustomerSupport(context));
              },
              text: 'Help',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorView(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(LayoutConstants.space6),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: LayoutConstants.space12,
              color: AppColor.auGrey,
            ),
            SizedBox(height: LayoutConstants.space4),
            Text(
              "We couldn't complete your search",
              style: AppTypography.body(context).white,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultsView({
    required BuildContext context,
    required SearchResults results,
    required SearchFilterType filterType,
  }) {
    final filtered = filterResultsByType(results, filterType);

    switch (filterType) {
      case SearchFilterType.channels:
        return _buildChannelsView(context, filtered.channels);
      case SearchFilterType.playlists:
        return _buildPlaylistsView(context, filtered.playlists);
      case SearchFilterType.works:
        return _buildWorksView(context, filtered.works);
    }
  }

  Widget _buildChannelsView(BuildContext context, List<Channel> channels) {
    if (channels.isEmpty) {
      return _buildEmptyView(context);
    }

    return CustomScrollView(
      controller: _scrollController,
      slivers: [
        SliverList.builder(
          itemCount: channels.length,
          itemBuilder: (context, index) => ChannelListRow(
            channelData: ChannelRowData(
              channelId: channels[index].id,
              channelTitle: channels[index].name,
              channelSummary: channels[index].description,
              works: const <PlaylistItem>[],
            ),
            onItemTap: (item) {
              unawaited(context.push('${Routes.works}/${item.id}'));
            },
          ),
        ),
        SliverToBoxAdapter(
          child: SizedBox(height: LayoutConstants.space16),
        ),
      ],
    );
  }

  Widget _buildPlaylistsView(BuildContext context, List<Playlist> playlists) {
    if (playlists.isEmpty) {
      return _buildEmptyView(context);
    }

    return CustomScrollView(
      controller: _scrollController,
      slivers: [
        SliverList.builder(
          itemCount: playlists.length,
          itemBuilder: (context, index) => PlaylistRowItem(
            playlist: playlists[index],
            onItemTap: (item) {
              unawaited(context.push('${Routes.works}/${item.id}'));
            },
          ),
        ),
        SliverToBoxAdapter(
          child: SizedBox(height: LayoutConstants.space16),
        ),
      ],
    );
  }

  Widget _buildWorksView(BuildContext context, List<PlaylistItem> works) {
    if (works.isEmpty) {
      return _buildEmptyView(context);
    }

    return CustomScrollView(
      controller: _scrollController,
      slivers: [
        SliverPadding(
          padding: EdgeInsets.symmetric(
            horizontal: LayoutConstants.pageHorizontalDefault,
          ),
          sliver: UIHelper.worksSliverGrid(
            works: works,
            onItemTap: (item) {
              unawaited(context.push('${Routes.works}/${item.id}'));
            },
          ),
        ),
        SliverToBoxAdapter(
          child: SizedBox(height: LayoutConstants.space16),
        ),
      ],
    );
  }
}
