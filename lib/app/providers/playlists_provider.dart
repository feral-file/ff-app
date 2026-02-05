import 'dart:async';

import 'package:app/domain/models/playlist.dart';
import 'package:app/infra/database/app_database.dart';
import 'package:app/infra/database/database_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:sentry/sentry.dart';

import 'package:app/app/providers/mutations.dart';

/// State for a single playlist type (curated or personal).
/// Aligns with old repo: one list per PlaylistType,
/// pagination for curated only.
class PlaylistsState {
  /// Creates a PlaylistsState.
  const PlaylistsState({
    required this.playlists,
    required this.isLoading,
    required this.isLoadingMore,
    required this.hasMore,
    required this.cursor,
    this.total,
    this.error,
  });

  /// Playlists for this type (Drift data).
  final List<PlaylistData> playlists;

  /// Whether playlists are being loaded.
  final bool isLoading;

  /// Whether more playlists are being loaded (pagination).
  final bool isLoadingMore;

  /// Whether there are more playlists to load (pagination).
  final bool hasMore;

  /// Cursor for pagination (stringified offset).
  final String? cursor;

  /// Total count when known (optional, from DB/API).
  final int? total;

  /// Error if loading failed.
  final String? error;

  /// Initial state.
  factory PlaylistsState.initial() {
    return const PlaylistsState(
      playlists: [],
      isLoading: false,
      isLoadingMore: false,
      hasMore: true,
      cursor: null,
    );
  }

  /// Loading state.
  factory PlaylistsState.loading() {
    return const PlaylistsState(
      playlists: [],
      isLoading: true,
      isLoadingMore: false,
      hasMore: true,
      cursor: null,
    );
  }

  /// Loaded state.
  factory PlaylistsState.loaded({
    required List<PlaylistData> playlists,
    required bool hasMore,
    required String? cursor,
    int? total,
  }) {
    return PlaylistsState(
      playlists: playlists,
      isLoading: false,
      isLoadingMore: false,
      hasMore: hasMore,
      cursor: cursor,
      total: total,
    );
  }

  /// Error state.
  factory PlaylistsState.error(String error) {
    return PlaylistsState(
      playlists: [],
      isLoading: false,
      isLoadingMore: false,
      hasMore: false,
      cursor: null,
      error: error,
    );
  }

  /// Copy with new values.
  PlaylistsState copyWith({
    List<PlaylistData>? playlists,
    bool? isLoading,
    bool? isLoadingMore,
    bool? hasMore,
    String? cursor,
    bool clearCursor = false,
    int? total,
    bool clearTotal = false,
    String? error,
    bool clearError = false,
  }) {
    return PlaylistsState(
      playlists: playlists ?? this.playlists,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasMore: hasMore ?? this.hasMore,
      cursor: clearCursor ? null : (cursor ?? this.cursor),
      total: clearTotal ? null : (total ?? this.total),
      error: clearError ? null : (error ?? this.error),
    );
  }
}

/// Notifier for one playlist type (curated = dp1, personal = addressBased).
/// Aligns with old repo: PlaylistsBloc(playlistType, total?, pageSize).
class PlaylistsNotifier extends Notifier<PlaylistsState> {
  PlaylistsNotifier(this._type);

  static const int _pageSize = 10;
  static const Duration _slowQueryThreshold = Duration(seconds: 3);

  final PlaylistType _type;
  late final Logger _log;
  StreamSubscription<List<PlaylistData>>? _watchSub;

  @override
  PlaylistsState build() {
    _log = Logger('PlaylistsNotifier(${_type.name})');
    ref.onDispose(() async {
      _log.info('Disposing PlaylistsNotifier, cancelling subscription');
      await _watchSub?.cancel();
      _watchSub = null;
    });

    _setupDatabaseWatch();
    return PlaylistsState.initial();
  }

  /// Watch full playlist list for this type (no limit). Aligns with old repo
  /// PlaylistsBloc: watch emits entire list so we detect new data after reload.
  void _setupDatabaseWatch() {
    _watchSub?.cancel();
    final databaseService = ref.read(databaseServiceProvider);
    _watchSub = databaseService
        .watchPlaylistsData(type: _type)
        .listen(_onPlaylistsChanged, onError: _onWatchError);
  }

  void _onWatchError(Object error, StackTrace stack) {
    _log.warning('Database watch error', error, stack);
  }

  /// Reacts to DB changes. [next] is the full list (watch has no limit).
  /// Aligns with old repo: hasChanged = length/prefix diff or (more in DB and !hasMore).
  void _onPlaylistsChanged(List<PlaylistData> next) {
    if (state.playlists.isEmpty && !state.isLoading) {
      unawaited(loadPlaylists(size: _pageSize));
      return;
    }
    final current = state.playlists;
    final loadedLength = current.length;
    final listenSize = loadedLength > _pageSize ? loadedLength : _pageSize;

    bool hasChanged = (current.length != next.length) ||
        (current.length < next.length && !state.hasMore);
    if (!hasChanged && current.isNotEmpty && next.isNotEmpty) {
      final n = current.length < next.length ? current.length : next.length;
      if (n > 0 &&
          !_samePlaylistIds(current.sublist(0, n), next.sublist(0, n))) {
        hasChanged = true;
      }
    }

    if (hasChanged && !state.isLoading && !state.isLoadingMore) {
      if (_type == PlaylistType.dp1) {
        unawaited(loadPlaylists(size: listenSize));
      } else {
        state = state.copyWith(playlists: next);
      }
    }
  }

  bool _samePlaylistIds(List<PlaylistData> a, List<PlaylistData> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].id != b[i].id) return false;
    }
    return true;
  }

  /// Load playlists for this type.
  /// Pagination applies to dp1 (curated); addressBased loads all.
  Future<void> loadPlaylists({int? size}) async {
    try {
      final effectiveSize = size ?? _pageSize;
      _log.info(
        'Loading playlists from database (type: ${_type.name}, size: $effectiveSize)...',
      );
      state = state.copyWith(isLoading: true, clearError: true);

      final databaseService = ref.read(databaseServiceProvider);

      if (_type == PlaylistType.dp1) {
        final startTime = DateTime.now();
        final allPlaylists = await databaseService.getAllPlaylistsData();
        final duration = DateTime.now().difference(startTime);
        if (duration > _slowQueryThreshold) {
          _log.warning(
            'Slow getAllPlaylistsData(): ${duration.inMilliseconds}ms',
          );
          unawaited(
            Sentry.captureEvent(
              SentryEvent(
                message: SentryMessage(
                  'Slow getAllPlaylistsData(): ${duration.inMilliseconds}ms '
                  '(size: $effectiveSize, total: ${allPlaylists.length})',
                ),
                level: SentryLevel.warning,
              ),
            ),
          );
        }
        final curatedAll = allPlaylists.where((p) => p.type == 0).toList()
          ..sort((a, b) {
            final aUs = a.createdAtUs.toInt();
            final bUs = b.createdAtUs.toInt();
            final byTime = bUs.compareTo(aUs);
            if (byTime != 0) return byTime;
            return a.id.compareTo(b.id);
          });
        final end = effectiveSize.clamp(0, curatedAll.length);
        final page = curatedAll.take(end).toList();
        final nextCursor = end < curatedAll.length ? end.toString() : null;
        final hasMore = nextCursor != null;
        state = PlaylistsState.loaded(
          playlists: page,
          hasMore: hasMore,
          cursor: nextCursor,
          total: curatedAll.length,
        );
        _log.info(
          'Curated playlists: ${page.length}/${curatedAll.length}, '
          'hasMore: $hasMore, cursor: $nextCursor',
        );
      } else {
        final personal = await databaseService.getAddressPlaylistsData();
        state = PlaylistsState.loaded(
          playlists: personal,
          hasMore: false,
          cursor: null,
          total: personal.length,
        );
        _log.info('Personal playlists: ${personal.length}');
      }
    } catch (e, stack) {
      _log.severe('Failed to load playlists', e, stack);
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Refresh playlists.
  Future<void> refresh() async {
    final size = state.playlists.isEmpty ? _pageSize : state.playlists.length;
    await loadPlaylists(size: _type == PlaylistType.dp1 ? size : null);
  }

  /// Load more playlists. Only applies to dp1 (curated).
  Future<void> loadMore() async {
    if (_type != PlaylistType.dp1 ||
        state.isLoading ||
        state.isLoadingMore ||
        !state.hasMore) {
      return;
    }
    final cursor = state.cursor;
    final start = int.tryParse(cursor ?? '') ?? state.playlists.length;
    if (start < 0) return;

    try {
      state = state.copyWith(isLoadingMore: true, clearError: true);

      final databaseService = ref.read(databaseServiceProvider);
      final startTime = DateTime.now();
      final allPlaylists = await databaseService.getAllPlaylistsData();
      final duration = DateTime.now().difference(startTime);
      if (duration > _slowQueryThreshold) {
        _log.warning(
          'Slow getAllPlaylistsData() for loadMore: ${duration.inMilliseconds}ms',
        );
        unawaited(
          Sentry.captureEvent(
            SentryEvent(
              message: SentryMessage(
                'Slow getAllPlaylistsData() for loadMore: '
                '${duration.inMilliseconds}ms '
                '(cursor: $cursor, total: ${allPlaylists.length})',
              ),
              level: SentryLevel.warning,
            ),
          ),
        );
      }

      final curatedAll = allPlaylists.where((p) => p.type == 0).toList()
        ..sort((a, b) {
          final aUs = a.createdAtUs.toInt();
          final bUs = b.createdAtUs.toInt();
          final byTime = bUs.compareTo(aUs);
          if (byTime != 0) return byTime;
          return a.id.compareTo(b.id);
        });

      final end = (start + _pageSize).clamp(0, curatedAll.length);
      if (start >= end) {
        state = state.copyWith(
          isLoadingMore: false,
          hasMore: false,
          cursor: null,
        );
        return;
      }

      final page = curatedAll.sublist(start, end);
      final nextPlaylists = [...state.playlists, ...page];
      final nextCursor = end < curatedAll.length ? end.toString() : null;
      final hasMore = nextCursor != null;

      state = state.copyWith(
        playlists: nextPlaylists,
        isLoadingMore: false,
        hasMore: hasMore,
        cursor: nextCursor,
      );
    } catch (e, stack) {
      _log.severe('Failed to load more playlists', e, stack);
      state = state.copyWith(isLoadingMore: false, error: e.toString());
    }
  }
}

/// Provider for playlists state by type (dp1 = curated, addressBased = personal).
final playlistsProvider =
    NotifierProvider.family<PlaylistsNotifier, PlaylistsState, PlaylistType>(
      PlaylistsNotifier.new,
    );

/// Mutation for loading playlists (generic; use with specific type in UI).
final loadPlaylistsMutationProvider =
    NotifierProvider<MutationNotifier<void>, MutationState<void>>(
      MutationNotifier.new,
    );

/// Mutation for refreshing playlists.
final refreshPlaylistsMutationProvider =
    NotifierProvider<MutationNotifier<void>, MutationState<void>>(
      MutationNotifier.new,
    );

/// Mutation for loading more playlists.
final loadMorePlaylistsMutationProvider =
    NotifierProvider<MutationNotifier<void>, MutationState<void>>(
      MutationNotifier.new,
    );

/// Provider for playlists in a specific channel.
final playlistsByChannelProvider =
    FutureProvider.family<List<Playlist>, String>((ref, channelId) async {
      final databaseService = ref.watch(databaseServiceProvider);
      return databaseService.getPlaylistsByChannel(channelId);
    });

/// Provider for a specific playlist by ID.
final playlistByIdProvider = FutureProvider.family<Playlist?, String>((
  ref,
  playlistId,
) async {
  final databaseService = ref.watch(databaseServiceProvider);
  return databaseService.getPlaylistById(playlistId);
});
