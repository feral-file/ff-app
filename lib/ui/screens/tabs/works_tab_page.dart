import 'package:app/app/providers/works_provider.dart';
import 'package:app/app/routing/routes.dart';
import 'package:app/design/app_typography.dart';
import 'package:app/design/layout_constants.dart';
import 'package:app/domain/models/playlist_item.dart';
import 'package:app/theme/app_color.dart';
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
        slivers: const [
          SliverToBoxAdapter(child: _LoadingView()),
        ],
      );
    }

    if (state.error != null && state.works.isEmpty) {
      return CustomScrollView(
        physics: const NeverScrollableScrollPhysics(),
        shrinkWrap: true,
        slivers: [
          SliverToBoxAdapter(
            child: _ErrorView(
              error: 'Error loading works: ${state.error}',
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
          // Works grid - matching old app aspect ratio and spacing
          SliverGrid.builder(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 188 / 307, // Old app ratio
              crossAxisSpacing: 17,
            ),
            itemBuilder: (context, index) => _WorkCard(work: works[index]),
            itemCount: works.length,
          ),
          
          // Load more indicator
          if (hasMore || isLoadingMore)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: hasMore && isLoadingMore
                      ? const CircularProgressIndicator(color: AppColor.white)
                      : const SizedBox.shrink(),
                ),
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

/// Simple loading widget matching old app design.
class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: CircularProgressIndicator(
        color: AppColor.white,
      ),
    );
  }
}

/// Simple error widget matching old app design.
class _ErrorView extends StatelessWidget {
  const _ErrorView({
    required this.error,
    this.onRetry,
  });

  final String error;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: LayoutConstants.pageHorizontalDefault,
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              error,
              style: AppTypography.body(context).grey,
              textAlign: TextAlign.center,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: onRetry,
                child: Text(
                  'Retry',
                  style: AppTypography.body(context).white,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _WorkCard extends StatelessWidget {
  const _WorkCard({required this.work});

  final PlaylistItem work;

  @override
  Widget build(BuildContext context) {
    final title = work.title;
    final artistName = work.artistName ?? '';

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        context.go('${Routes.works}/${work.id}');
      },
      child: Container(
        color: Colors.transparent,
        padding: const EdgeInsets.all(12),
        child: IgnorePointer(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.max,
            children: [
              // Thumbnail
              Flexible(
                fit: FlexFit.tight,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return ClipRect(
                      child: SizedBox(
                        width: constraints.maxWidth,
                        height: constraints.maxHeight,
                        child: Center(
                          child: _buildThumbnail(),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 10),
              // Title
              Text(
                title,
                style: AppTypography.bodySmall(context).white,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              // Artist
              if (artistName.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  artistName,
                  style: AppTypography.bodySmall(context).grey.italic,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildThumbnail() {
    if (work.thumbnailUrl != null && work.thumbnailUrl!.isNotEmpty) {
      return Image.network(
        work.thumbnailUrl!,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) => _buildPlaceholder(),
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return _buildPlaceholder();
        },
      );
    }
    return _buildPlaceholder();
  }

  Widget _buildPlaceholder() {
    return Container(
      color: AppColor.auQuickSilver.withValues(alpha: 0.3),
      child: const Center(
        child: Icon(
          Icons.image,
          color: AppColor.auQuickSilver,
          size: 48,
        ),
      ),
    );
  }
}
