import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';

import 'package:app/app/providers/mutations.dart';
import 'package:app/domain/models/playlist_item.dart';
import 'package:app/infra/database/database_provider.dart';

/// Enhanced state for works with pagination support.
/// UI uses domain [PlaylistItem] only.
class WorksState {
  /// Creates a WorksState.
  const WorksState({
    required this.works,
    required this.hasMore,
    required this.isLoading,
    this.error,
  });

  /// List of works (domain).
  final List<PlaylistItem> works;

  /// Whether there are more works to load.
  final bool hasMore;

  /// Whether works are being loaded.
  final bool isLoading;

  /// Error if loading failed.
  final String? error;

  /// Initial state.
  factory WorksState.initial() {
    return const WorksState(
      works: [],
      hasMore: true,
      isLoading: false,
    );
  }

  /// Loading state.
  factory WorksState.loading() {
    return const WorksState(
      works: [],
      hasMore: true,
      isLoading: true,
    );
  }

  /// Loaded state.
  factory WorksState.loaded({
    required List<PlaylistItem> works,
    bool hasMore = false,
  }) {
    return WorksState(
      works: works,
      hasMore: hasMore,
      isLoading: false,
    );
  }

  /// Error state.
  factory WorksState.error(String error) {
    return WorksState(
      works: [],
      hasMore: false,
      isLoading: false,
      error: error,
    );
  }

  /// Copy with new values.
  WorksState copyWith({
    List<PlaylistItem>? works,
    bool? hasMore,
    bool? isLoading,
    String? error,
  }) {
    return WorksState(
      works: works ?? this.works,
      hasMore: hasMore ?? this.hasMore,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

/// Notifier for managing works state.
class WorksNotifier extends Notifier<WorksState> {
  late final Logger _log;

  @override
  WorksState build() {
    _log = Logger('WorksNotifier');
    return WorksState.initial();
  }

  /// Load all works from database (domain only).
  Future<void> loadWorks() async {
    try {
      state = WorksState.loading();

      final databaseService = ref.read(databaseServiceProvider);
      final works = await databaseService.getAllItems();

      state = WorksState.loaded(works: works);
    } catch (e, stack) {
      _log.severe('Failed to load works', e, stack);
      state = WorksState.error(e.toString());
    }
  }

  /// Refresh works.
  Future<void> refresh() async {
    await loadWorks();
  }

  /// Load more works (pagination).
  /// In a real app, this would fetch the next page.
  Future<void> loadMore() async {
    if (!state.hasMore || state.isLoading) {
      return;
    }

    try {
      // In a real app, we'd fetch next page here
      // For now, just mark as no more items
      state = state.copyWith(hasMore: false);
    } catch (e, stack) {
      _log.severe('Failed to load more works', e, stack);
    }
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
final playlistItemsProvider =
    FutureProvider.family<List<PlaylistItem>, String>((ref, playlistId) async {
  final databaseService = ref.watch(databaseServiceProvider);
  return databaseService.getPlaylistItems(playlistId);
});

/// Provider for a specific playlist item by ID.
final playlistItemByIdProvider =
    FutureProvider.family<PlaylistItem?, String>((ref, itemId) async {
  final databaseService = ref.watch(databaseServiceProvider);
  return databaseService.getPlaylistItemById(itemId);
});
