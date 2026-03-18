import 'dart:async';

import 'package:app/domain/models/playlist.dart';
import 'package:app/domain/models/playlist_item.dart';
import 'package:app/infra/database/database_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:riverpod/src/providers/notifier.dart';

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
  bool _isPlaylistLoaded = false;
  Playlist? _loadedPlaylist;

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

    unawaited(
      Future.microtask(_setupDatabaseListener),
    );
    unawaited(
      Future.microtask(_loadPlaylistMeta),
    );
    return const AsyncValue.loading();
  }

  Future<void> _loadPlaylistMeta() async {
    if (!ref.mounted || _isPlaylistLoaded) return;
    _isPlaylistLoaded = true;
    try {
      final playlist = await ref
          .read(databaseServiceProvider)
          .getPlaylistById(_playlistId);
      _loadedPlaylist = playlist;
      if (!ref.mounted) return;
      final current = switch (state) {
        AsyncData(value: final v) => v,
        _ => null,
      };
      if (current != null) {
        state = AsyncValue.data(current.copyWith(playlist: playlist));
      }
    } catch (e, s) {
      _log.warning('Failed to load playlist metadata for $_playlistId', e, s);
    }
  }

  /// Watch playlist items in DB; on change reload or update total (like old Bloc).
  void _setupDatabaseListener() {
    if (!ref.mounted) return;
    if (!ref.read(isSeedDatabaseReadyProvider)) return;
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
    if (!ref.mounted) return;
    final current = switch (state) {
      AsyncData(value: final v) => v,
      _ => null,
    };
    if (current == null || current.items.isEmpty) {
      final initialItems = fullList.take(_pageSize).toList();
      final hasMore = fullList.length > initialItems.length;
      state = AsyncValue.data(
        PlaylistDetailsState(
          playlist: current?.playlist ?? _loadedPlaylist,
          items: initialItems,
          total: fullList.length,
          hasMore: hasMore,
          offset: initialItems.length,
        ),
      );
      return;
    }
    // Same as Bloc: use loaded count for comparison and reload slice size.
    final loadedCount = _pageSize > current.items.length
        ? _pageSize
        : current.items.length;
    final newSlice = fullList.take(loadedCount).toList();
    final currentSlice = current.items.take(loadedCount).toList();
    final hasChanged =
        newSlice.length != currentSlice.length ||
        !listEquals(newSlice, currentSlice);
    if (hasChanged) {
      state = AsyncValue.data(
        PlaylistDetailsState(
          playlist: current.playlist ?? _loadedPlaylist,
          items: newSlice,
          total: fullList.length,
          hasMore: fullList.length > loadedCount,
          offset: loadedCount,
        ),
      );
    } else {
      if (current.total != fullList.length) {
        state = AsyncValue.data(current.copyWith(total: fullList.length));
      }
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
      if (!ref.mounted) return;
      if (newItems.isEmpty) {
        state = AsyncValue.data(
          current.copyWith(hasMore: false, isLoadingMore: false),
        );
        return;
      }
      final newItemsList = [...current.items, ...newItems];
      // Preserve total from DB watcher; it must not change when loading more
      // pages (otherwise "Up to date. X works" would jump as user scrolls).
      state = AsyncValue.data(
        PlaylistDetailsState(
          playlist: current.playlist,
          items: newItemsList,
          total: current.total,
          hasMore: newItems.length >= _pageSize,
          offset: current.offset + newItems.length,
        ),
      );
    } catch (e, stack) {
      if (!ref.mounted) return;
      _log.severe('Failed to load more for $_playlistId', e, stack);
      state = AsyncValue.data(current.copyWith(isLoadingMore: false));
    }
  }
}

/// Provider for playlist details state (single source; includes items, total, pagination).
final NotifierProviderFamily<
  PlaylistDetailsNotifier,
  AsyncValue<PlaylistDetailsState>,
  String
>
playlistDetailsProvider = NotifierProvider.autoDispose
    .family<PlaylistDetailsNotifier, AsyncValue<PlaylistDetailsState>, String>(
      PlaylistDetailsNotifier.new,
    );
