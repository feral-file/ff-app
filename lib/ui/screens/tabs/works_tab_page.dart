import 'dart:async';

import 'package:app/app/providers/seed_database_provider.dart';
import 'package:app/app/providers/works_provider.dart';
import 'package:app/app/routing/routes.dart';
import 'package:app/design/layout_constants.dart';
import 'package:app/theme/app_color.dart';
import 'package:app/ui/ui_helper.dart';
import 'package:app/widgets/error_view.dart';
import 'package:app/widgets/load_more_indicator.dart';
import 'package:app/widgets/seed_sync_loading_indicator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Works tab page with grid view of all works.
class WorksTabPage extends ConsumerStatefulWidget {
  /// Creates a WorksTabPage.
  const WorksTabPage({
    required this.isActive,
    super.key,
  });

  /// Whether this tab is currently active.
  final bool isActive;

  @override
  ConsumerState<WorksTabPage> createState() => WorksTabPageState();
}

/// State for WorksTabPage.
class WorksTabPageState extends ConsumerState<WorksTabPage>
    with AutomaticKeepAliveClientMixin {
  late ScrollController _scrollController;
  late WorksNotifier _worksNotifier;
  WorksState _cachedState = WorksState.initial();
  int _lastSeededVisibleCount = -1;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _worksNotifier = ref.read(worksProvider.notifier);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _worksNotifier.setActive(widget.isActive);
    });
  }

  @override
  void didUpdateWidget(covariant WorksTabPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isActive != widget.isActive) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _worksNotifier.setActive(widget.isActive);
      });
    }
  }

  @override
  void dispose() {
    _worksNotifier.setActive(false);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScrollPositionChanged(ScrollPosition position) {
    if (!widget.isActive) return;
    _updateVisibleRange(position);
    // Handle scroll position update from parent
    if (position.pixels + 100 >= position.maxScrollExtent &&
        position.maxScrollExtent > 0) {
      _worksNotifier.loadMore();
    }
  }

  Future<void> _onRefresh() async {
    if (!widget.isActive) return;
    await _worksNotifier.refresh();
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

    final worksState = widget.isActive
        ? ref.watch(worksProvider)
        : _cachedState;
    if (widget.isActive) {
      final shouldKeepSnapshot =
          _cachedState.works.isNotEmpty &&
          worksState.works.isEmpty &&
          worksState.isLoading;
      if (shouldKeepSnapshot) {
        return RefreshIndicator(
          onRefresh: _onRefresh,
          backgroundColor: AppColor.primaryBlack,
          color: AppColor.white,
          child: _buildContent(_cachedState),
        );
      }
      _cachedState = worksState;
    }

    return RefreshIndicator(
      onRefresh: _onRefresh,
      backgroundColor: AppColor.primaryBlack,
      color: AppColor.white,
      child: _buildContent(worksState),
    );
  }

  Widget _buildContent(WorksState state) {
    if (state.error != null && state.works.isEmpty) {
      return CustomScrollView(
        physics: const NeverScrollableScrollPhysics(),
        shrinkWrap: true,
        slivers: [
          SliverToBoxAdapter(
            child: ErrorView(
              error:
                  'We couldn’t load works. Check your connection, then Retry.',
              onRetry: _worksNotifier.loadWorks,
            ),
          ),
        ],
      );
    }

    return _buildWorksGridView(state);
  }

  Widget _buildWorksGridView(WorksState state) {
    final works = state.works;
    final hasMore = state.hasMore;
    final isLoadingMore = state.isLoadingMore;
    _seedVisibleRange(works.length);

    return _LoadMoreListener(
      onScrollPositionChanged: _onScrollPositionChanged,
      child: CustomScrollView(
        physics: const NeverScrollableScrollPhysics(),
        shrinkWrap: true,
        controller: _scrollController,
        slivers: [
          // Works grid - domain PlaylistItem only
          UIHelper.worksSliverGrid(
            works: works,
            onItemTap: (item) => context.pushNamed(
              RouteNames.workDetail,
              pathParameters: {'workId': item.id},
            ),
          ),
          // Load more indicator at end of list when hasMore or loading next page
          if (hasMore || isLoadingMore)
            SliverToBoxAdapter(
              child: LoadMoreIndicator(
                isLoadingMore: isLoadingMore,
                padding: EdgeInsets.symmetric(vertical: LayoutConstants.space4),
              ),
            ),
        ],
      ),
    );
  }

  void _seedVisibleRange(int worksCount) {
    if (!widget.isActive || worksCount == 0) return;
    if (_lastSeededVisibleCount == worksCount) return;
    _lastSeededVisibleCount = worksCount;
    final end = (worksCount - 1).clamp(0, 23);
    _worksNotifier.updateVisibleRange(
      startIndex: 0,
      endIndex: end,
    );
  }

  void _updateVisibleRange(ScrollPosition position) {
    final worksCount = ref.read(worksProvider).works.length;
    if (worksCount == 0) return;

    final viewportWidth = MediaQuery.sizeOf(context).width;
    const crossAxisCount = 2;
    final crossAxisSpacing = LayoutConstants.space4;
    final mainAxisSpacing = LayoutConstants.space4;
    final tileWidth = (viewportWidth - crossAxisSpacing) / crossAxisCount;
    final tileHeight = tileWidth / LayoutConstants.worksGridChildAspectRatio;
    final rowExtent = tileHeight + mainAxisSpacing;
    if (rowExtent <= 0) return;

    final firstVisibleRow = (position.pixels / rowExtent).floor();
    final visibleRowCount = (position.viewportDimension / rowExtent).ceil() + 1;
    final start = (firstVisibleRow * crossAxisCount).clamp(0, worksCount - 1);
    final end = (((firstVisibleRow + visibleRowCount) * crossAxisCount) - 1)
        .clamp(start, worksCount - 1);

    _worksNotifier.updateVisibleRange(
      startIndex: start,
      endIndex: end,
    );
  }
}

/// Generic scroll listener widget for nested scroll hierarchies.
/// Listens to parent scroll position and passes updates to callback.
/// Copied from old app design.
class _LoadMoreListener extends StatefulWidget {
  const _LoadMoreListener({
    required this.child,
    required this.onScrollPositionChanged,
  });

  final Widget child;
  final void Function(ScrollPosition) onScrollPositionChanged;

  @override
  State<_LoadMoreListener> createState() => _LoadMoreListenerState();
}

class _LoadMoreListenerState extends State<_LoadMoreListener> {
  ScrollPosition? _scrollPosition;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _setupScrollListener();
  }

  void _setupScrollListener() {
    try {
      // Remove old listener if exists
      _scrollPosition?.removeListener(_onScroll);

      // Get parent Scrollable position
      final scrollableState = Scrollable.of(context);
      _scrollPosition = scrollableState.position;

      // Add listener
      _scrollPosition?.addListener(_onScroll);
    } catch (e) {
      // Scrollable not found in widget tree
    }
  }

  void _onScroll() {
    if (!mounted) {
      _scrollPosition?.removeListener(_onScroll);
      return;
    }

    final position = _scrollPosition;
    if (position == null) return;

    // Notify parent about position change
    widget.onScrollPositionChanged(position);
  }

  @override
  void dispose() {
    _scrollPosition?.removeListener(_onScroll);
    _scrollPosition = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

// Work grid cards are built via UIHelper + WorkGridCard.
