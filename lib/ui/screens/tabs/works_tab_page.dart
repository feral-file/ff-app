import 'package:app/app/providers/works_provider.dart';
import 'package:app/app/routing/routes.dart';
import 'package:app/design/layout_constants.dart';
import 'package:app/theme/app_color.dart';
import 'package:app/widgets/error_view.dart';
import 'package:app/widgets/load_more_indicator.dart';
import 'package:app/widgets/loading_view.dart';
import 'package:app/ui/ui_helper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Works tab page with grid view of all works.
class WorksTabPage extends ConsumerStatefulWidget {
  /// Creates a WorksTabPage.
  const WorksTabPage({super.key});

  @override
  ConsumerState<WorksTabPage> createState() => WorksTabPageState();
}

/// State for WorksTabPage.
class WorksTabPageState extends ConsumerState<WorksTabPage>
    with AutomaticKeepAliveClientMixin {
  late ScrollController _scrollController;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();

    // Trigger initial load
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(worksProvider.notifier).loadWorks();
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScrollPositionChanged(ScrollPosition position) {
    // Handle scroll position update from parent
    if (position.pixels + 100 >= position.maxScrollExtent &&
        position.maxScrollExtent > 0) {
      ref.read(worksProvider.notifier).loadMore();
    }
  }

  Future<void> _onRefresh() async {
    await ref.read(worksProvider.notifier).refresh();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final worksState = ref.watch(worksProvider);

    return RefreshIndicator(
      onRefresh: _onRefresh,
      backgroundColor: AppColor.primaryBlack,
      color: AppColor.white,
      child: _buildContent(worksState),
    );
  }

  Widget _buildContent(WorksState state) {
    if (state.isLoading && state.works.isEmpty) {
      return CustomScrollView(
        physics: const NeverScrollableScrollPhysics(),
        shrinkWrap: true,
        slivers: const [SliverToBoxAdapter(child: LoadingView())],
      );
    }

    if (state.error != null && state.works.isEmpty) {
      return CustomScrollView(
        physics: const NeverScrollableScrollPhysics(),
        shrinkWrap: true,
        slivers: [
          SliverToBoxAdapter(
            child: ErrorView(
              error: 'We couldn’t load works. Check your connection, then Retry.',
              onRetry: () => ref.read(worksProvider.notifier).loadWorks(),
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
    final isLoadingMore = state.isLoading && works.isNotEmpty;

    return _LoadMoreListener(
      onScrollPositionChanged: _onScrollPositionChanged,
      child: CustomScrollView(
        physics: const NeverScrollableScrollPhysics(),
        shrinkWrap: true,
        controller: _scrollController,
        slivers: [
          // Works grid - Drift ItemData only
          UIHelper.worksSliverGrid(
            works: works,
            onItemTap: (item) => context.go('${Routes.works}/${item.id}'),
          ),
          
          // Load more indicator (uses LoadingWidget / GIF)
          if (hasMore || isLoadingMore)
            SliverToBoxAdapter(
              child: LoadMoreIndicator(
                isLoadingMore: hasMore && isLoadingMore,
                padding: EdgeInsets.symmetric(vertical: LayoutConstants.space4),
              ),
            ),
        ],
      ),
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
