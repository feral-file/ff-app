import 'dart:async';

import 'package:app/app/providers/channel_preview_provider.dart' show ChannelPreviewNotifier, ChannelPreviewState;
import 'package:app/app/providers/mutations.dart';
import 'package:app/app/providers/playlist_details_provider.dart' show PlaylistDetailsNotifier;
import 'package:app/app/providers/services_provider.dart';
import 'package:app/domain/extensions/playlist_item_ext.dart';
import 'package:app/domain/models/dp1/dp1_provenance.dart';
import 'package:app/domain/models/indexer/asset_token.dart';
import 'package:app/domain/models/playlist_item.dart';
import 'package:app/infra/database/database_provider.dart';
import 'package:app/util/content_type_resolver.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:riverpod/src/providers/future_provider.dart';
import 'package:riverpod/src/providers/notifier.dart';

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
  static const Duration _dbChangeDebounce = Duration(seconds: 1);
  static const int _defaultVisibleWindowSize = 24;

  late final Logger _log;
  StreamSubscription<List<PlaylistItem>>? _watchSub;
  Timer? _refreshDebounceTimer;
  bool _isActive = false;
  bool _isApplyingDbChanges = false;
  int _visibleStartIndex = 0;
  int _visibleEndIndex = _defaultVisibleWindowSize - 1;

  @override
  WorksState build() {
    _log = Logger('WorksNotifier');
    ref.onDispose(() {
      _log.info('Disposing WorksNotifier, cancelling listeners');
      _stopWatching();
    });

    return WorksState.initial();
  }

  /// Toggle active/inactive mode for the works tab.
  ///
  /// Inactive mode keeps current UI state but stops database subscriptions.
  void setActive(bool active) {
    if (_isActive == active) {
      return;
    }
    _isActive = active;
    if (_isActive) {
      _setupDatabaseWatch();
      if (state.works.isEmpty) {
        unawaited(loadWorks());
      } else {
        _scheduleDebouncedRefresh();
      }
    } else {
      _stopWatching();
    }
  }

  /// Update current visible range in the grid. Used to patch only visible rows.
  void updateVisibleRange({
    required int startIndex,
    required int endIndex,
  }) {
    if (startIndex < 0 || endIndex < 0) return;
    if (endIndex < startIndex) return;
    _visibleStartIndex = startIndex;
    _visibleEndIndex = endIndex;
  }

  void _setupDatabaseWatch() {
    if (!ref.mounted) return;
    _stopWatching();

    final databaseService = ref.read(databaseServiceProvider);
    _watchSub = databaseService.watchAllItems().listen(
      _onItemsChanged,
      onError: _onWatchError,
    );
  }

  void _onWatchError(Object error, StackTrace stack) {
    _log.warning('Database watch error', error, stack);
  }

  void _stopWatching() {
    _refreshDebounceTimer?.cancel();
    _refreshDebounceTimer = null;
    unawaited(_watchSub?.cancel());
    _watchSub = null;
  }

  void _onItemsChanged(List<PlaylistItem> next) {
    if (!_isActive) return;
    _scheduleDebouncedRefresh();
  }

  void _scheduleDebouncedRefresh() {
    _refreshDebounceTimer?.cancel();
    _refreshDebounceTimer = Timer(_dbChangeDebounce, () {
      unawaited(_applyDatabaseChanges());
    });
  }

  Future<void> _applyDatabaseChanges() async {
    if (!_isActive || state.isLoading || state.isLoadingMore) return;
    if (_isApplyingDbChanges) return;
    _isApplyingDbChanges = true;
    try {
      if (state.works.isEmpty) {
        await loadWorks();
        return;
      }

      final db = ref.read(databaseServiceProvider);
      final loadedCount = state.works.length;
      final latestIds = await db.getItemIds(limit: loadedCount, offset: 0);
      final currentIds = state.works.map((item) => item.id).toList();

      if (latestIds.length != currentIds.length) {
        await _reloadLoadedWindow();
        return;
      }

      if (listEquals(currentIds, latestIds)) {
        await _refreshVisibleRangeOnly();
        await _syncHasMore();
        return;
      }

      final diffWindow = _findDiffWindow(currentIds, latestIds);
      if (diffWindow == null) {
        await _reloadLoadedWindow();
        return;
      }

      await _refreshRange(
        start: diffWindow.$1,
        end: diffWindow.$2,
      );
      await _syncHasMore();
    } catch (e, stack) {
      _log.warning('Failed to apply debounced DB changes', e, stack);
    } finally {
      _isApplyingDbChanges = false;
    }
  }

  (int, int)? _findDiffWindow(List<String> currentIds, List<String> latestIds) {
    if (currentIds.length != latestIds.length || currentIds.isEmpty) {
      return null;
    }
    var firstDiff = -1;
    for (var i = 0; i < currentIds.length; i++) {
      if (currentIds[i] != latestIds[i]) {
        firstDiff = i;
        break;
      }
    }
    if (firstDiff < 0) return null;

    var lastDiff = currentIds.length - 1;
    while (lastDiff > firstDiff &&
        currentIds[lastDiff] == latestIds[lastDiff]) {
      lastDiff--;
    }
    return (firstDiff, lastDiff);
  }

  Future<void> _reloadLoadedWindow() async {
    final currentCount = state.works.length;
    final targetSize = currentCount > worksPageSize
        ? currentCount
        : worksPageSize;
    final page = await _fetchPage(offset: 0, pageSize: targetSize);
    if (!ref.mounted) return;
    state = state.copyWith(
      works: page.$1,
      hasMore: page.$2,
      isLoading: false,
      isLoadingMore: false,
      clearError: true,
    );
  }

  Future<void> _refreshVisibleRangeOnly() async {
    final worksCount = state.works.length;
    if (worksCount == 0) return;

    var start = _visibleStartIndex;
    var end = _visibleEndIndex;
    if (start >= worksCount || end < start) {
      start = 0;
      end = (_defaultVisibleWindowSize - 1).clamp(0, worksCount - 1);
    } else {
      start = start.clamp(0, worksCount - 1);
      end = end.clamp(start, worksCount - 1);
    }

    await _refreshRange(start: start, end: end);
  }

  Future<void> _refreshRange({
    required int start,
    required int end,
  }) async {
    final worksCount = state.works.length;
    if (worksCount == 0 || start < 0 || end < start) return;

    final safeStart = start.clamp(0, worksCount - 1);
    final safeEnd = end.clamp(safeStart, worksCount - 1);
    final size = safeEnd - safeStart + 1;
    if (size <= 0) return;

    final db = ref.read(databaseServiceProvider);
    final refreshedSlice = await db.getItems(limit: size, offset: safeStart);
    if (!ref.mounted) return;
    if (refreshedSlice.length != size) {
      await _reloadLoadedWindow();
      return;
    }

    final nextWorks = [...state.works];
    nextWorks.replaceRange(safeStart, safeEnd + 1, refreshedSlice);
    state = state.copyWith(
      works: nextWorks,
      clearError: true,
    );
  }

  Future<void> _syncHasMore() async {
    final loadedCount = state.works.length;
    if (loadedCount == 0) return;
    final db = ref.read(databaseServiceProvider);
    final ids = await db.getItemIds(limit: loadedCount + 1, offset: 0);
    if (!ref.mounted) return;
    final hasMore = ids.length > loadedCount;
    if (hasMore != state.hasMore) {
      state = state.copyWith(hasMore: hasMore);
    }
  }

  Future<(List<PlaylistItem>, bool)> _fetchPage({
    required int offset,
    required int pageSize,
  }) async {
    final db = ref.read(databaseServiceProvider);
    final raw = await db.getItems(limit: pageSize + 1, offset: offset);
    final hasMore = raw.length > pageSize;
    final pageItems = hasMore ? raw.take(pageSize).toList() : raw;
    return (pageItems, hasMore);
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
      state = state.copyWith(isLoading: true, clearError: true);
    }

    try {
      final page = await _fetchPage(offset: offset, pageSize: limit);
      if (!ref.mounted) return;
      state = state.copyWith(
        works: page.$1,
        hasMore: page.$2,
        isLoading: false,
        isLoadingMore: false,
        clearError: true,
      );
    } catch (e, stack) {
      if (!ref.mounted) return;
      if (_isOperationCancelled(e)) {
        _log.info('Works load cancelled');
        state = state.copyWith(
          isLoading: false,
          isLoadingMore: false,
          clearError: true,
        );
        return;
      }
      _log.severe('Failed to load works', e, stack);
      state = state.copyWith(
        isLoading: false,
        isLoadingMore: false,
        error: e.toString(),
      );
    }
  }

  /// Load next page and append (offset-based), like [ChannelPreviewNotifier.loadMore].
  Future<void> loadMore() async {
    if (!_isActive ||
        state.isLoading ||
        state.isLoadingMore ||
        !state.hasMore) {
      return;
    }

    state = state.copyWith(isLoadingMore: true, clearError: true);

    try {
      final page = await _fetchPage(
        offset: state.works.length,
        pageSize: worksPageSize,
      );
      if (!ref.mounted) return;
      state = state.copyWith(
        works: [...state.works, ...page.$1],
        hasMore: page.$2,
        isLoading: false,
        isLoadingMore: false,
        clearError: true,
      );
    } catch (e, stack) {
      if (!ref.mounted) return;
      if (_isOperationCancelled(e)) {
        _log.info('Load more works cancelled');
        state = state.copyWith(isLoadingMore: false, clearError: true);
        return;
      }
      _log.severe('Failed to load more works', e, stack);
      state = state.copyWith(
        isLoadingMore: false,
        error: e.toString(),
      );
    }
  }

  /// Load first page; used by works tab. Caller passes offset and limit.
  Future<void> loadWorks() async => load(offset: 0, limit: worksPageSize);

  /// Refresh works (reload first page). Does not show loading state.
  Future<void> refresh() async {
    if (!_isActive) return;
    final sizeToLoad = worksPageSize > state.works.length
        ? worksPageSize
        : state.works.length;
    await load(offset: 0, limit: sizeToLoad, showLoading: false);
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
final FutureProviderFamily<List<PlaylistItem>, String> playlistItemsProvider = FutureProvider.family<List<PlaylistItem>, String>(
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
    if (!ref.mounted) return;
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
    if (!ref.mounted) return;
    state = AsyncValue.error(error, stack);
  }

  void _onItemChanged(PlaylistItem? item) {
    if (!ref.mounted) return;
    if (item == null) {
      state = const AsyncValue.data(null);
      return;
    }
    final hasChanged = item != state.value?.item;
    state = AsyncValue.data(
      WorkDetailData(item: item),
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

    if (!ref.mounted) return;
    state = AsyncValue.data(
      WorkDetailData(item: item, mimeType: mimeType),
    );

    AssetToken? token;
    try {
      final cid = item.provenance?.cid;
      if (cid != null) {
        final indexerService = ref.read(indexerServiceProvider);
        token = await indexerService.getTokenByCid(cid);
        if (!ref.mounted) return;
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
final NotifierProviderFamily<WorkDetailNotifier, AsyncValue<WorkDetailData?>, String> workDetailStateProvider = NotifierProvider.autoDispose
    .family<WorkDetailNotifier, AsyncValue<WorkDetailData?>, String>(
      WorkDetailNotifier.new,
    );

/// Provider for current user's owner addresses (from AddressService).
/// Used by work detail to show token ownership.
final ownerAddressesProvider = FutureProvider<List<String>>((ref) async {
  final addressService = ref.watch(addressServiceProvider);
  return addressService.getAllAddresses();
});

bool _isOperationCancelled(Object error) {
  return error.runtimeType.toString() == 'CancellationException' ||
      error.toString().contains('Operation was cancelled');
}
