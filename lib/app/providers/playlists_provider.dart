import 'dart:async';

import 'package:app/app/providers/database_error_utils.dart';
import 'package:app/app/providers/database_service_provider.dart';
import 'package:app/app/providers/seed_database_ready_provider.dart';
import 'package:app/domain/models/playlist.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:riverpod/src/providers/future_provider.dart';
import 'package:riverpod/src/providers/notifier.dart';
import 'package:sentry/sentry.dart';

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
    required List<Playlist> playlists,
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

  /// Playlists for this type (domain).
  final List<Playlist> playlists;

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

  /// Copy with new values.
  PlaylistsState copyWith({
    List<Playlist>? playlists,
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
  PlaylistsNotifier(this._type)
    : _log = Logger('PlaylistsNotifier(${_type.name})');

  static const int _pageSize = 10;
  static const Duration _slowQueryThreshold = Duration(seconds: 3);

  final PlaylistType _type;
  final Logger _log;
  StreamSubscription<List<Playlist>>? _watchSub;

  @override
  PlaylistsState build() {
    ref.onDispose(() async {
      _log.info('Disposing PlaylistsNotifier, cancelling subscription');
      await _watchSub?.cancel();
      _watchSub = null;
    });

    unawaited(Future.microtask(_setupDatabaseWatch));
    return PlaylistsState.initial();
  }

  /// Watch full playlist list for this type (no limit). Aligns with old repo
  /// PlaylistsBloc: watch emits entire list so we detect new data after reload.
  void _setupDatabaseWatch() {
    if (!ref.mounted) return;
    if (!ref.read(isSeedDatabaseReadyProvider)) return;
    _watchSub?.cancel();
    final databaseService = ref.read(databaseServiceProvider);
    _watchSub = databaseService
        .watchPlaylists(type: _type)
        .listen(_onPlaylistsChanged, onError: _onWatchError);
  }

  void _onWatchError(Object error, StackTrace stack) {
    _log.warning('Database watch error', error, stack);
    if (!ref.mounted || !isDatabaseUnavailableError(error)) return;
    state = PlaylistsState.loaded(
      playlists: const <Playlist>[],
      hasMore: false,
      cursor: null,
      total: 0,
    );
  }

  /// Reacts to DB changes. [next] is the full list (watch has no limit).
  /// Aligns with old repo: hasChanged = length/prefix diff or (more in DB and !hasMore).
  void _onPlaylistsChanged(List<Playlist> next) {
    if (!ref.mounted) return;
    if (state.playlists.isEmpty && !state.isLoading) {
      unawaited(loadPlaylists(size: _pageSize));
      return;
    }
    final current = state.playlists;
    final loadedLength = current.length;
    final listenSize = loadedLength > _pageSize ? loadedLength : _pageSize;
    final slice = next.take(listenSize).toList();

    final hasChanged =
        current.length != slice.length || !listEquals(current, slice);
    if (hasChanged) {
      unawaited(loadPlaylists(size: listenSize));
    }
  }

  /// Load playlists for this type.
  /// dp1 (curated): Load all from database. addressBased: database, all.
  Future<void> loadPlaylists({int? size}) async {
    if (state.isLoading) return;
    if (!ref.read(isSeedDatabaseReadyProvider)) return;
    try {
      _log.info('Loading playlists (type: ${_type.name})...');
      state = state.copyWith(isLoading: true, clearError: true);

      switch (_type) {
        case PlaylistType.dp1:
          final result = await _loadDp1Playlists();
          if (!ref.mounted) return;
          state = PlaylistsState.loaded(
            playlists: result,
            hasMore: false,
            cursor: null,
            total: result.length,
          );
          _log.info('Curated playlists: ${result.length}');
        case PlaylistType.addressBased:
          await _loadAddressBasedPlaylists();
        case PlaylistType.favorite:
          await _loadFavoritePlaylists();
      }
    } catch (e, stack) {
      if (!ref.mounted) return;
      if (isDatabaseUnavailableError(e)) {
        state = PlaylistsState.loaded(
          playlists: const <Playlist>[],
          hasMore: false,
          cursor: null,
          total: 0,
        );
        return;
      }
      if (_isOperationCancelled(e)) {
        _log.info('Playlist load cancelled');
        state = state.copyWith(isLoading: false, clearError: true);
        return;
      }
      _log.severe('Failed to load playlists', e, stack);
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Load all curated (dp1) playlists from database.
  /// Caller sets state; watch will emit updates when DB changes.
  Future<List<Playlist>> _loadDp1Playlists() async {
    final startTime = DateTime.now();
    final databaseService = ref.read(databaseServiceProvider);
    final refs = await databaseService.getAllPlaylists(type: PlaylistType.dp1);
    final duration = DateTime.now().difference(startTime);
    if (duration > _slowQueryThreshold) {
      _log.warning(
        'Slow getAllPlaylists(type: dp1): ${duration.inMilliseconds}ms '
        '(returned: ${refs.length})',
      );
      unawaited(
        Sentry.captureEvent(
          SentryEvent(
            message: SentryMessage(
              'Slow getAllPlaylists(type: dp1): ${duration.inMilliseconds}ms '
              '(returned: ${refs.length})',
            ),
            level: SentryLevel.warning,
          ),
        ),
      );
    }
    return refs.map((r) => r).toList();
  }

  /// Load favorite playlists from database; no pagination.
  Future<void> _loadFavoritePlaylists() async {
    final databaseService = ref.read(databaseServiceProvider);
    final favorites = await databaseService.getAllPlaylists(
      type: PlaylistType.favorite,
    );
    if (!ref.mounted) return;
    state = PlaylistsState.loaded(
      playlists: favorites,
      hasMore: false,
      cursor: null,
      total: favorites.length,
    );
    _log.info('Favorite playlists: ${favorites.length}');
  }

  /// Load address-based (personal) playlists from database; no pagination.
  Future<void> _loadAddressBasedPlaylists() async {
    final databaseService = ref.read(databaseServiceProvider);
    final personal = await databaseService.getAddressPlaylists();
    if (!ref.mounted) return;
    state = PlaylistsState.loaded(
      playlists: personal,
      hasMore: false,
      cursor: null,
      total: personal.length,
    );
    _log.info('Personal playlists: ${personal.length}');
  }

  /// Refresh playlists.
  Future<void> refresh() async {
    await loadPlaylists();
  }

  /// Load more playlists (no-op; all data is already loaded).
  Future<void> loadMore() async {
    // All data is loaded upfront; database watch triggers redraws
    // when new playlists are available.
  }
}

/// Provider for playlists state by type (dp1 = curated, addressBased = personal).
final NotifierProviderFamily<PlaylistsNotifier, PlaylistsState, PlaylistType>
playlistsProvider =
    NotifierProvider.family<PlaylistsNotifier, PlaylistsState, PlaylistType>(
      PlaylistsNotifier.new,
    );

bool _isOperationCancelled(Object error) {
  return error.runtimeType.toString() == 'CancellationException' ||
      error.toString().contains('Operation was cancelled');
}

/// Provider for playlists in a specific channel.
final FutureProviderFamily<List<Playlist>, String> playlistsByChannelProvider =
    FutureProvider.family<List<Playlist>, String>((ref, channelId) async {
      final databaseService = ref.watch(databaseServiceProvider);
      try {
        return await databaseService.getPlaylistsByChannel(channelId);
      } on Object catch (e) {
        if (isDatabaseUnavailableError(e)) {
          return const <Playlist>[];
        }
        rethrow;
      }
    });

/// Provider for a specific playlist by ID.
final FutureProviderFamily<Playlist?, String> playlistByIdProvider =
    FutureProvider.family<Playlist?, String>((
      ref,
      playlistId,
    ) async {
      final databaseService = ref.watch(databaseServiceProvider);
      try {
        return await databaseService.getPlaylistById(playlistId);
      } on Object catch (e) {
        if (isDatabaseUnavailableError(e)) {
          return null;
        }
        rethrow;
      }
    });
