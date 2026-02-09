import 'dart:async';

import 'package:app/domain/models/playlist.dart';
import 'package:app/domain/models/playlist_item.dart';
import 'package:app/infra/database/database_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';

/// Data-only state for playlist details (loading/error from AsyncValue).
class PlaylistDetailsState {
  const PlaylistDetailsState({
    required this.playlist,
    required this.items,
    required this.total,
    required this.hasMore,
    required this.offset,
    this.isLoadingMore = false,
  });

  /// Playlist being viewed (domain).
  final Playlist? playlist;

  /// Works in the playlist (domain), paginated.
  final List<PlaylistItem> items;

  /// Total count (number of items loaded so far; or from DB count if added later).
  final int total;

  /// Whether more items can be loaded.
  final bool hasMore;

  /// Next fetch start index.
  final int offset;

  /// True while loadMore is in progress (for UI spinner).
  final bool isLoadingMore;

  PlaylistDetailsState copyWith({
    Playlist? playlist,
    List<PlaylistItem>? items,
    int? total,
    bool? hasMore,
    int? offset,
    bool? isLoadingMore,
  }) {
    return PlaylistDetailsState(
      playlist: playlist ?? this.playlist,
      items: items ?? this.items,
      total: total ?? this.total,
      hasMore: hasMore ?? this.hasMore,
      offset: offset ?? this.offset,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    );
  }
}

/// Page size for pagination (matches old PlaylistDetailsBloc).
const int _pageSize = 10;

/// Notifier for playlist details with pagination.
class PlaylistDetailsNotifier
    extends Notifier<AsyncValue<PlaylistDetailsState>> {
  PlaylistDetailsNotifier(this._playlistId);

  final String _playlistId;
  static final _log = Logger('PlaylistDetailsNotifier');
  StreamSubscription<List<PlaylistItem>>? _dbSubscription;

  @override
  AsyncValue<PlaylistDetailsState> build() {
    ref.onDispose(() {
      _log.info(
        'Disposing PlaylistDetailsNotifier, cancelling DB subscription for '
        '$_playlistId',
      );
      unawaited(_dbSubscription?.cancel());
      _dbSubscription = null;
    });
    _setupDatabaseListener();
    unawaited(_loadInitial(limit: _pageSize, offset: 0));
    return const AsyncValue.loading();
  }

  /// Watch playlist items in DB; on change reload or update total (like old Bloc).
  void _setupDatabaseListener() {
    unawaited(_dbSubscription?.cancel());
    _dbSubscription = null;
    try {
      final databaseService = ref.read(databaseServiceProvider);
      _dbSubscription = databaseService
          .watchPlaylistItems(_playlistId)
          .listen(_onDatabaseChanged, onError: _onWatchError);
    } catch (e, s) {
      _log.warning('Failed to setup database listener for $_playlistId', e, s);
    }
  }

  void _onWatchError(Object error, StackTrace stack) {
    _log.warning('Database listener error for $_playlistId', error, stack);
  }

  void _onDatabaseChanged(List<PlaylistItem> fullList) {
    final current = switch (state) {
      AsyncData(value: final v) => v,
      _ => null,
    };
    if (current == null || current.items.isEmpty) {
      final limit = _pageSize > fullList.length ? _pageSize : fullList.length;
      unawaited(_loadInitial(limit: limit, offset: 0));
      return;
    }
    // Same as Bloc: use loaded count for comparison and reload slice size.
    final loadedCount = _pageSize > current.items.length
        ? _pageSize
        : current.items.length;
    final newSlice = fullList.take(loadedCount).toList();
    final currentSlice = current.items.take(loadedCount).toList();
    final sameIds = listEquals(
      newSlice.map((e) => e.id).toList(),
      currentSlice.map((e) => e.id).toList(),
    );
    if (!sameIds) {
      state = AsyncValue.data(
        PlaylistDetailsState(
          playlist: current.playlist,
          items: newSlice,
          total: fullList.length,
          hasMore: fullList.length > loadedCount,
          offset: loadedCount,
          isLoadingMore: false,
        ),
      );
    } else {
      if (current.total != fullList.length) {
        state = AsyncValue.data(current.copyWith(total: fullList.length));
      }
    }
  }

  Future<void> _loadInitial({
    required int limit,
    required int offset,
  }) async {
    try {
      final databaseService = ref.read(databaseServiceProvider);
      final playlist = await databaseService.getPlaylistById(_playlistId);
      final items = await databaseService.getPlaylistItems(
        _playlistId,
        limit: limit,
        offset: offset,
      );
      final nextOffset = offset + items.length;
      state = AsyncValue.data(
        PlaylistDetailsState(
          playlist: playlist,
          items: items,
          total: items.length,
          hasMore: items.length >= limit,
          offset: nextOffset,
          isLoadingMore: false,
        ),
      );
    } catch (e, stack) {
      _log.severe('Failed to load playlist details for $_playlistId', e, stack);
      state = AsyncValue.error(e, stack);
    }
  }

  /// Loads the next page of items. No-op if already loading more or no more.
  Future<void> loadMore() async {
    final current = switch (state) {
      AsyncData(value: final v) => v,
      _ => null,
    };
    if (current == null || current.isLoadingMore || !current.hasMore) {
      return;
    }
    state = AsyncValue.data(current.copyWith(isLoadingMore: true));
    try {
      final databaseService = ref.read(databaseServiceProvider);
      final newItems = await databaseService.getPlaylistItems(
        _playlistId,
        limit: _pageSize,
        offset: current.offset,
      );
      if (newItems.isEmpty) {
        state = AsyncValue.data(
          current.copyWith(hasMore: false, isLoadingMore: false),
        );
        return;
      }
      final newItemsList = [...current.items, ...newItems];
      state = AsyncValue.data(
        PlaylistDetailsState(
          playlist: current.playlist,
          items: newItemsList,
          total: newItemsList.length,
          hasMore: newItems.length >= _pageSize,
          offset: current.offset + newItems.length,
          isLoadingMore: false,
        ),
      );
    } catch (e, stack) {
      _log.severe('Failed to load more for $_playlistId', e, stack);
      state = AsyncValue.data(current.copyWith(isLoadingMore: false));
    }
  }
}

/// Provider for playlist details state (single source; includes items, total, pagination).
final playlistDetailsProvider =
    NotifierProvider.family<
      PlaylistDetailsNotifier,
      AsyncValue<PlaylistDetailsState>,
      String
    >(PlaylistDetailsNotifier.new);
