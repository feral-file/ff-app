import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';

import 'package:app/app/providers/mutations.dart';
import 'package:app/domain/models/playlist_item.dart';
import 'package:app/infra/database/database_provider.dart';

/// Page size for works list (aligns with [ChannelPreviewNotifier] pattern).
const int worksPageSize = 50;

/// Enhanced state for works with pagination support.
/// UI uses domain [PlaylistItem] only.
/// Pattern matches [ChannelPreviewState].
class WorksState {
  /// Creates a WorksState.
  const WorksState({
    required this.works,
    required this.hasMore,
    required this.isLoading,
    required this.isLoadingMore,
    this.error,
  });

  /// List of works (domain).
  final List<PlaylistItem> works;

  /// Whether there are more works to load.
  final bool hasMore;

  /// Whether initial load is in progress.
  final bool isLoading;

  /// Whether load-more is in progress.
  final bool isLoadingMore;

  /// Error if loading failed.
  final String? error;

  /// Initial state.
  factory WorksState.initial() {
    return const WorksState(
      works: [],
      hasMore: true,
      isLoading: false,
      isLoadingMore: false,
    );
  }

  /// Loading state (initial load).
  factory WorksState.loading() {
    return const WorksState(
      works: [],
      hasMore: true,
      isLoading: true,
      isLoadingMore: false,
    );
  }

  /// Loaded state.
  factory WorksState.loaded({
    required List<PlaylistItem> works,
    required bool hasMore,
  }) {
    return WorksState(
      works: works,
      hasMore: hasMore,
      isLoading: false,
      isLoadingMore: false,
    );
  }

  /// Error state.
  factory WorksState.error(String error) {
    return WorksState(
      works: [],
      hasMore: false,
      isLoading: false,
      isLoadingMore: false,
      error: error,
    );
  }

  /// Copy with new values.
  WorksState copyWith({
    List<PlaylistItem>? works,
    bool? hasMore,
    bool? isLoading,
    bool? isLoadingMore,
    String? error,
    bool clearError = false,
  }) {
    return WorksState(
      works: works ?? this.works,
      hasMore: hasMore ?? this.hasMore,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

/// Notifier for works list: loads and pages all items from database.
/// Pattern matches [ChannelPreviewNotifier]: database watcher + offset-based paging.
class WorksNotifier extends Notifier<WorksState> {
  late final Logger _log;
  StreamSubscription<List<PlaylistItem>>? _watchSub;

  @override
  WorksState build() {
    _log = Logger('WorksNotifier');
    ref.onDispose(() {
      _log.info('Disposing WorksNotifier, cancelling subscription');
      unawaited(_watchSub?.cancel());
      _watchSub = null;
    });

    _setupDatabaseWatch();
    return WorksState.initial();
  }

  void _setupDatabaseWatch() {
    unawaited(_watchSub?.cancel());
    _watchSub = null;

    final databaseService = ref.read(databaseServiceProvider);
    _watchSub = databaseService.watchAllItems().listen(
      _onItemsChanged,
      onError: _onWatchError,
    );
  }

  void _onWatchError(Object error, StackTrace stack) {
    _log.warning('Database watch error', error, stack);
  }

  void _onItemsChanged(List<PlaylistItem> next) {
    refresh();
  }

  /// Load a slice of works from database (no channel filter).
  /// [offset] and [limit] are passed by the caller; this method does not read from state.
  /// When [showLoading] is false (e.g. on refresh), the loading state is not set.
  Future<void> load({
    required int offset,
    required int limit,
    bool showLoading = true,
  }) async {
    if (state.isLoading) return;

    if (showLoading) {
      state = WorksState.loading();
    }

    try {
      final db = ref.read(databaseServiceProvider);
      final result = await db.getItems(limit: limit, offset: offset);
      final hasMore = result.length >= limit;

      state = WorksState.loaded(works: result, hasMore: hasMore);
    } catch (e, stack) {
      _log.severe('Failed to load works', e, stack);
      state = WorksState.error(e.toString());
    }
  }

  /// Load next page and append (offset-based), like [ChannelPreviewNotifier.loadMore].
  Future<void> loadMore() async {
    if (state.isLoadingMore || !state.hasMore) return;

    state = state.copyWith(isLoadingMore: true);

    try {
      final db = ref.read(databaseServiceProvider);
      final result = await db.getItems(
        limit: worksPageSize,
        offset: state.works.length,
      );
      final hasMore = result.length >= worksPageSize;
      state = WorksState.loaded(
        works: [...state.works, ...result],
        hasMore: hasMore,
      );
    } catch (e, stack) {
      _log.severe('Failed to load more works', e, stack);
      state = state.copyWith(
        isLoadingMore: false,
        error: e.toString(),
        clearError: false,
      );
    }
  }

  /// Load first page; used by works tab. Caller passes offset and limit.
  Future<void> loadWorks() async => load(offset: 0, limit: worksPageSize);

  /// Refresh works (reload first page). Does not show loading state.
  Future<void> refresh() async {
    final sizeToLoad = worksPageSize > state.works.length
        ? worksPageSize
        : state.works.length;
    load(offset: 0, limit: sizeToLoad, showLoading: false);
  }
}

/// Provider for works state.
final worksProvider = NotifierProvider<WorksNotifier, WorksState>(
  WorksNotifier.new,
);

/// Mutation for loading works.
final loadWorksMutationProvider =
    NotifierProvider<MutationNotifier<void>, MutationState<void>>(
      MutationNotifier.new,
    );

/// Mutation for refreshing works.
final refreshWorksMutationProvider =
    NotifierProvider<MutationNotifier<void>, MutationState<void>>(
      MutationNotifier.new,
    );

/// Mutation for loading more works.
final loadMoreWorksMutationProvider =
    NotifierProvider<MutationNotifier<void>, MutationState<void>>(
      MutationNotifier.new,
    );

/// Provider for playlist items in a specific playlist.
final playlistItemsProvider = FutureProvider.family<List<PlaylistItem>, String>(
  (ref, playlistId) async {
    final databaseService = ref.watch(databaseServiceProvider);
    return databaseService.getPlaylistItems(playlistId);
  },
);

/// Provider for a specific playlist item by ID.
final playlistItemByIdProvider = FutureProvider.family<PlaylistItem?, String>((
  ref,
  itemId,
) async {
  final databaseService = ref.watch(databaseServiceProvider);
  return databaseService.getPlaylistItemById(itemId);
});
