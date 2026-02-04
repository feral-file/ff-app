import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:sentry/sentry.dart';

import '../../domain/models/playlist.dart';
import '../../infra/database/database_provider.dart';
import 'mutations.dart';

/// Enhanced state for playlists with curated vs personal separation.
class PlaylistsState {
  /// Creates a PlaylistsState.
  const PlaylistsState({
    required this.curatedPlaylists,
    required this.personalPlaylists,
    required this.isLoading,
    required this.isLoadingMore,
    required this.hasMore,
    required this.cursor,
    this.error,
  });

  /// Curated playlists from DP1 feeds.
  final List<Playlist> curatedPlaylists;

  /// Personal playlists (address-based).
  final List<Playlist> personalPlaylists;

  /// Whether playlists are being loaded.
  final bool isLoading;

  /// Whether more curated playlists are being loaded (pagination).
  final bool isLoadingMore;

  /// Whether there are more curated playlists to load.
  ///
  /// Note: pagination currently applies to curated playlists only.
  final bool hasMore;

  /// Cursor for curated playlists pagination (stringified offset).
  final String? cursor;

  /// Error if loading failed.
  final String? error;

  /// Initial state.
  factory PlaylistsState.initial() {
    return const PlaylistsState(
      curatedPlaylists: [],
      personalPlaylists: [],
      isLoading: false,
      isLoadingMore: false,
      hasMore: true,
      cursor: null,
    );
  }

  /// Loading state.
  factory PlaylistsState.loading() {
    return const PlaylistsState(
      curatedPlaylists: [],
      personalPlaylists: [],
      isLoading: true,
      isLoadingMore: false,
      hasMore: true,
      cursor: null,
    );
  }

  /// Loaded state.
  factory PlaylistsState.loaded({
    required List<Playlist> curated,
    required List<Playlist> personal,
    required bool hasMore,
    required String? cursor,
  }) {
    return PlaylistsState(
      curatedPlaylists: curated,
      personalPlaylists: personal,
      isLoading: false,
      isLoadingMore: false,
      hasMore: hasMore,
      cursor: cursor,
    );
  }

  /// Error state.
  factory PlaylistsState.error(String error) {
    return PlaylistsState(
      curatedPlaylists: [],
      personalPlaylists: [],
      isLoading: false,
      isLoadingMore: false,
      hasMore: false,
      cursor: null,
      error: error,
    );
  }

  /// Copy with new values.
  PlaylistsState copyWith({
    List<Playlist>? curatedPlaylists,
    List<Playlist>? personalPlaylists,
    bool? isLoading,
    bool? isLoadingMore,
    bool? hasMore,
    String? cursor,
    bool clearCursor = false,
    String? error,
    bool clearError = false,
  }) {
    return PlaylistsState(
      curatedPlaylists: curatedPlaylists ?? this.curatedPlaylists,
      personalPlaylists: personalPlaylists ?? this.personalPlaylists,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasMore: hasMore ?? this.hasMore,
      cursor: clearCursor ? null : (cursor ?? this.cursor),
      error: clearError ? null : (error ?? this.error),
    );
  }
}

/// Notifier for managing playlists state.
class PlaylistsNotifier extends Notifier<PlaylistsState> {
  static const int _pageSize = 10;
  static const Duration _slowQueryThreshold = Duration(seconds: 3);

  late final Logger _log;
  StreamSubscription<List<Playlist>>? _curatedSub;
  StreamSubscription<List<Playlist>>? _personalSub;
  int? _curatedWatchLimit;

  @override
  PlaylistsState build() {
    _log = Logger('PlaylistsNotifier');
    ref.onDispose(() async {
      _log.info('Disposing PlaylistsNotifier, cancelling subscriptions');
      await _curatedSub?.cancel();
      await _personalSub?.cancel();
      _curatedSub = null;
      _personalSub = null;
    });

    // Start watching the database immediately (old repo semantics).
    _setupDatabaseWatch();

    return PlaylistsState.initial();
  }

  void _setupDatabaseWatch() {
    _ensureCuratedWatch(limit: _pageSize);

    // Personal (address-based) playlists can change as sync runs.
    _personalSub?.cancel();
    final databaseService = ref.read(databaseServiceProvider);
    _personalSub = databaseService
        .watchPlaylists(type: PlaylistType.addressBased)
        .listen(_onPersonalPlaylistsChanged, onError: _onWatchError);
  }

  void _ensureCuratedWatch({required int limit}) {
    if (_curatedWatchLimit == limit) return;
    _curatedWatchLimit = limit;

    _curatedSub?.cancel();
    final databaseService = ref.read(databaseServiceProvider);
    _curatedSub = databaseService
        .watchPlaylists(type: PlaylistType.dp1, limit: limit)
        .listen(_onCuratedPlaylistsChanged, onError: _onWatchError);
  }

  void _onWatchError(Object error, StackTrace stack) {
    _log.warning('Database watch error', error, stack);
  }

  void _onCuratedPlaylistsChanged(List<Playlist> curated) {
    if (state.curatedPlaylists.isEmpty && !state.isLoading) {
      unawaited(loadPlaylists(size: _pageSize));
      return;
    }

    final current = state.curatedPlaylists;
    final hasChanged = !_samePlaylistIds(current, curated);
    if (hasChanged && !state.isLoading && !state.isLoadingMore) {
      final size = current.isEmpty ? _pageSize : current.length;
      unawaited(loadPlaylists(size: size));
    }
  }

  void _onPersonalPlaylistsChanged(List<Playlist> personal) {
    final current = state.personalPlaylists;
    final hasChanged = !_samePlaylistIds(current, personal);
    if (hasChanged && !state.isLoading && !state.isLoadingMore) {
      state = state.copyWith(personalPlaylists: personal);
    }
  }

  bool _samePlaylistIds(List<Playlist> a, List<Playlist> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].id != b[i].id) return false;
    }
    return true;
  }

  /// Load playlists (curated + personal).
  ///
  /// Pagination applies to curated playlists. Personal playlists are loaded fully.
  Future<void> loadPlaylists({int size = _pageSize}) async {
    try {
      _log.info('Loading playlists from database (size: $size)...');
      state = state.copyWith(isLoading: true, clearError: true);

      final databaseService = ref.read(databaseServiceProvider);

      final startTime = DateTime.now();
      final allPlaylists = await databaseService.getAllPlaylists();
      final duration = DateTime.now().difference(startTime);
      if (duration > _slowQueryThreshold) {
        _log.warning('Slow getAllPlaylists(): ${duration.inMilliseconds}ms');
        unawaited(
          Sentry.captureEvent(
            SentryEvent(
              message: SentryMessage(
                'Slow getAllPlaylists(): ${duration.inMilliseconds}ms '
                '(size: $size, total: ${allPlaylists.length})',
              ),
              level: SentryLevel.warning,
            ),
          ),
        );
      }

      _log.info('Loaded ${allPlaylists.length} total playlists from database');

      // Separate curated vs personal.
      final curatedAll =
          allPlaylists.where((p) => p.type == PlaylistType.dp1).toList()
            ..sort((a, b) {
              final aUs = (a.createdAt?.microsecondsSinceEpoch) ?? 0;
              final bUs = (b.createdAt?.microsecondsSinceEpoch) ?? 0;
              final byTime = bUs.compareTo(aUs);
              if (byTime != 0) return byTime;
              return a.id.compareTo(b.id);
            });

      final end = size.clamp(0, curatedAll.length);
      final curated = curatedAll.take(end).toList();
      final nextCursor = end < curatedAll.length ? end.toString() : null;
      final hasMore = nextCursor != null;

      final personal = await databaseService.getAddressPlaylists();

      _log.info(
        'Curated playlists: ${curated.length}/${curatedAll.length}, '
        'Personal playlists: ${personal.length}, hasMore: $hasMore, '
        'cursor: $nextCursor',
      );

      _ensureCuratedWatch(
        limit: curated.length < _pageSize ? _pageSize : curated.length,
      );

      state = PlaylistsState.loaded(
        curated: curated,
        personal: personal,
        hasMore: hasMore,
        cursor: nextCursor,
      );
    } catch (e, stack) {
      _log.severe('Failed to load playlists', e, stack);
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Refresh playlists.
  Future<void> refresh() async {
    final size = state.curatedPlaylists.isEmpty
        ? _pageSize
        : state.curatedPlaylists.length;
    await loadPlaylists(size: size);
  }

  /// Load more curated playlists.
  Future<void> loadMore() async {
    if (state.isLoading || state.isLoadingMore || !state.hasMore) {
      return;
    }

    final cursor = state.cursor;
    final start = int.tryParse(cursor ?? '') ?? state.curatedPlaylists.length;
    if (start < 0) return;

    try {
      state = state.copyWith(isLoadingMore: true, clearError: true);

      final databaseService = ref.read(databaseServiceProvider);
      final startTime = DateTime.now();
      final allPlaylists = await databaseService.getAllPlaylists();
      final duration = DateTime.now().difference(startTime);
      if (duration > _slowQueryThreshold) {
        _log.warning(
            'Slow getAllPlaylists() for loadMore: ${duration.inMilliseconds}ms');
        unawaited(
          Sentry.captureEvent(
            SentryEvent(
              message: SentryMessage(
                'Slow getAllPlaylists() for loadMore: ${duration.inMilliseconds}ms '
                '(cursor: $cursor, total: ${allPlaylists.length})',
              ),
              level: SentryLevel.warning,
            ),
          ),
        );
      }

      final curatedAll =
          allPlaylists.where((p) => p.type == PlaylistType.dp1).toList()
            ..sort((a, b) {
              final aUs = (a.createdAt?.microsecondsSinceEpoch) ?? 0;
              final bUs = (b.createdAt?.microsecondsSinceEpoch) ?? 0;
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
      final nextCurated = [...state.curatedPlaylists, ...page];
      final nextCursor = end < curatedAll.length ? end.toString() : null;
      final hasMore = nextCursor != null;

      _ensureCuratedWatch(limit: nextCurated.length);

      state = state.copyWith(
        curatedPlaylists: nextCurated,
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

/// Provider for playlists state.
final playlistsProvider = NotifierProvider<PlaylistsNotifier, PlaylistsState>(
  PlaylistsNotifier.new,
);

/// Mutation for loading playlists.
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
final playlistByIdProvider =
    FutureProvider.family<Playlist?, String>((ref, playlistId) async {
  final databaseService = ref.watch(databaseServiceProvider);
  return databaseService.getPlaylistById(playlistId);
});
