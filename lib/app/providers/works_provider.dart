import 'dart:async';

import 'package:app/domain/models/models.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';

import 'package:app/app/providers/mutations.dart';
import 'package:app/app/providers/services_provider.dart';
import 'package:app/domain/extensions/playlist_item_ext.dart';
import 'package:app/domain/models/indexer/asset_token.dart';
import 'package:app/domain/models/playlist_item.dart';
import 'package:app/infra/database/database_provider.dart';
import 'package:app/util/content_type_resolver.dart';

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

    unawaited(Future.microtask(_setupDatabaseWatch));
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
    final loadedCount = next.length > worksPageSize
        ? worksPageSize
        : next.length;
    final newSlice = next.take(loadedCount).toList();
    final currentSlice = state.works.take(loadedCount).toList();
    final hasChanged = !listEquals(newSlice, currentSlice);
    if (hasChanged) {
      refresh();
    }
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

/// Data for the work detail screen: playlist item plus optional indexer token and mime type.
/// UI is driven by [item]; [mimeType] for back layer preview; [token] for metadata/options.
class WorkDetailData {
  const WorkDetailData({
    required this.item,
    this.token,
    this.mimeType,
  });

  final PlaylistItem item;
  final AssetToken? token;
  final String? mimeType;
}

/// Notifier for work detail: watches PlaylistItem by id and optionally
/// fetches AssetToken from indexer. Same pattern as [PlaylistDetailsNotifier].
class WorkDetailNotifier extends Notifier<AsyncValue<WorkDetailData?>> {
  WorkDetailNotifier(this._itemId);

  final String _itemId;
  static final _log = Logger('WorkDetailNotifier');
  StreamSubscription<PlaylistItem?>? _dbSubscription;

  @override
  AsyncValue<WorkDetailData?> build() {
    ref.onDispose(() {
      _log.info(
        'Disposing WorkDetailNotifier, cancelling DB subscription for $_itemId',
      );
      unawaited(_dbSubscription?.cancel());
      _dbSubscription = null;
    });
    _setupDatabaseListener();
    return const AsyncValue.loading();
  }

  void _setupDatabaseListener() {
    unawaited(_dbSubscription?.cancel());
    _dbSubscription = null;
    try {
      final databaseService = ref.read(databaseServiceProvider);
      _dbSubscription = databaseService
          .watchPlaylistItemById(_itemId)
          .listen(_onItemChanged, onError: _onWatchError);
    } catch (e, s) {
      _log.warning('Failed to setup database listener for $_itemId', e, s);
    }
  }

  void _onWatchError(Object error, StackTrace stack) {
    _log.warning('Database listener error for $_itemId', error, stack);
    state = AsyncValue.error(error, stack);
  }

  void _onItemChanged(PlaylistItem? item) {
    if (item == null) {
      state = AsyncValue.data(null);
      return;
    }
    final hasChanged = item != state.value?.item;
    state = AsyncValue.data(
      WorkDetailData(item: item, token: null, mimeType: null),
    );
    if (hasChanged) {
      unawaited(_loadAndEmit(item));
    }
  }

  Future<void> _loadAndEmit(PlaylistItem item) async {
    final previewUrl = item.sourceUrl;
    final mimeType = (previewUrl != null && previewUrl.isNotEmpty)
        ? await contentType(previewUrl)
        : null;

    state = AsyncValue.data(
      WorkDetailData(item: item, token: null, mimeType: mimeType),
    );

    AssetToken? token;
    try {
      final cid = item.cid;
      if (cid != null) {
        final indexerService = ref.read(indexerServiceProvider);
        token = await indexerService.getTokenByCid(cid);
        state = AsyncValue.data(
          WorkDetailData(item: item, token: token, mimeType: mimeType),
        );
      }
    } catch (_) {
      // Leave token null; UI shows item-only content.
    }
  }
}

/// Provider for work detail screen. Listens to the database so UI refreshes
/// when the item changes (e.g. enrichment). Auto-disposes when no longer listened.
final workDetailStateProvider = NotifierProvider.autoDispose
    .family<WorkDetailNotifier, AsyncValue<WorkDetailData?>, String>(
      WorkDetailNotifier.new,
    );

/// Provider for current user's owner addresses (from AddressService).
/// Used by work detail to show token ownership.
final ownerAddressesProvider = FutureProvider<List<String>>((ref) async {
  final addressService = ref.watch(addressServiceProvider);
  return addressService.getAllAddresses();
});
