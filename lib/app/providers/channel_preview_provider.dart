import 'dart:async';

import 'package:app/domain/models/playlist_item.dart';
import 'package:app/infra/database/database_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';
import 'package:riverpod/src/providers/notifier.dart';

/// Page size for channel preview items (aligns with old repo ChannelPreviewBloc).
const int channelPreviewPageSize = 10;

/// State for channel preview (works carousel for one channel).
/// Uses domain [PlaylistItem] only.
class ChannelPreviewState {
  /// Creates ChannelPreviewState.
  const ChannelPreviewState({
    required this.works,
    required this.hasMore,
    required this.isLoading,
    required this.isLoadingMore,
    this.error,
  });

  /// Initial state.
  factory ChannelPreviewState.initial() {
    return const ChannelPreviewState(
      works: [],
      hasMore: true,
      isLoading: false,
      isLoadingMore: false,
    );
  }

  /// Loading state (initial load).
  factory ChannelPreviewState.loading() {
    return const ChannelPreviewState(
      works: [],
      hasMore: true,
      isLoading: true,
      isLoadingMore: false,
    );
  }

  /// Loaded state.
  factory ChannelPreviewState.loaded({
    required List<PlaylistItem> works,
    required bool hasMore,
  }) {
    return ChannelPreviewState(
      works: works,
      hasMore: hasMore,
      isLoading: false,
      isLoadingMore: false,
    );
  }

  /// Error state.
  factory ChannelPreviewState.error(String error) {
    return ChannelPreviewState(
      works: [],
      hasMore: false,
      isLoading: false,
      isLoadingMore: false,
      error: error,
    );
  }

  /// Preview works (domain) for the channel.
  final List<PlaylistItem> works;

  /// Whether there are more works to load.
  final bool hasMore;

  /// Whether initial load is in progress.
  final bool isLoading;

  /// Whether load-more is in progress.
  final bool isLoadingMore;

  /// Error message if load failed.
  final String? error;

  ChannelPreviewState copyWith({
    List<PlaylistItem>? works,
    bool? hasMore,
    bool? isLoading,
    bool? isLoadingMore,
    String? error,
    bool clearError = false,
  }) {
    return ChannelPreviewState(
      works: works ?? this.works,
      hasMore: hasMore ?? this.hasMore,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

/// Notifier for channel preview: loads and pages works from channel playlists.
class ChannelPreviewNotifier extends Notifier<ChannelPreviewState> {
  /// Creates ChannelPreviewNotifier with family argument [channelId].
  ChannelPreviewNotifier(this._channelId);

  final String _channelId;
  late final Logger _log;
  static const Duration _updatesDebounce = Duration(seconds: 1);
  StreamSubscription<List<PlaylistItem>>? _watchSub;
  Timer? _updateDebounceTimer;

  @override
  ChannelPreviewState build() {
    _log = Logger('ChannelPreviewNotifier($_channelId)');
    ref.onDispose(() {
      _log.info('Disposing ChannelPreviewNotifier, cancelling subscription');
      _updateDebounceTimer?.cancel();
      _updateDebounceTimer = null;
      unawaited(_watchSub?.cancel());
      _watchSub = null;
    });

    unawaited(Future.microtask(_setupDatabaseWatch));
    return ChannelPreviewState.initial();
  }

  void _setupDatabaseWatch() {
    if (!ref.mounted) return;
    _updateDebounceTimer?.cancel();
    _updateDebounceTimer = null;
    unawaited(_watchSub?.cancel());
    _watchSub = null;
    if (_channelId.isEmpty) return;

    final databaseService = ref.read(databaseServiceProvider);
    _watchSub = databaseService
        .watchPlaylistItemsByChannel(
          _channelId,
          offset: 0,
        )
        .listen(_onPlaylistItemsChanged, onError: _onWatchError);
  }

  void _onWatchError(Object error, StackTrace stack) {
    _log.warning('Database watch error', error, stack);
  }

  void _onPlaylistItemsChanged(List<PlaylistItem> next) {
    // No debounce when there is no UI data yet: paint first items immediately.
    if (state.works.isEmpty) {
      _applyPlaylistItems(next);
      return;
    }
    _updateDebounceTimer?.cancel();
    _updateDebounceTimer = Timer(_updatesDebounce, () {
      _applyPlaylistItems(next);
    });
  }

  void _applyPlaylistItems(List<PlaylistItem> next) {
    if (!ref.mounted) return;
    final loadedLength = state.works.length;
    final listenSize = loadedLength > channelPreviewPageSize
        ? loadedLength
        : channelPreviewPageSize;
    final pageItems = next.take(listenSize).toList();
    final current = state.works;
    final hasMore = next.length > pageItems.length;
    final hasChanged =
        current.length != pageItems.length ||
        !listEquals(current, pageItems) ||
        state.hasMore != hasMore;
    if (hasChanged) {
      state = ChannelPreviewState.loaded(
        works: pageItems,
        hasMore: hasMore,
      );
    }
  }

  /// Load preview works for the given [limit] and [offset].
  /// Use limit = pageSize+1 to detect hasMore; display count is limit-1.
  /// Updates the watched slice to (limit, offset) and refetches on DB change if slice changed.
  Future<void> load({int? limit, int? offset, bool showLoading = true}) async {
    final id = _channelId;
    if (id.isEmpty) return;

    if (state.isLoading) return;

    final requestedLimit = limit ?? channelPreviewPageSize + 1;
    final requestedOffset = offset ?? 0;
    if (showLoading) {
      state = ChannelPreviewState.loading();
    }

    try {
      final db = ref.read(databaseServiceProvider);
      final result = await db.getPlaylistItemsByChannel(
        id,
        limit: requestedLimit,
        offset: requestedOffset,
      );
      if (!ref.mounted) return;
      final hasMore = result.length > channelPreviewPageSize;
      final pageItems = hasMore
          ? result.take(channelPreviewPageSize).toList()
          : result;

      state = ChannelPreviewState.loaded(works: pageItems, hasMore: hasMore);
    } catch (e, stack) {
      if (!ref.mounted) return;
      _log.severe('Failed to load channel preview for $id', e, stack);
      state = ChannelPreviewState.error(e.toString());
    }
  }

  /// Load next page and append to works (offset-based query).
  Future<void> loadMore() async {
    final id = _channelId;
    if (id.isEmpty) return;
    if (state.isLoadingMore || !state.hasMore) return;

    state = state.copyWith(isLoadingMore: true);

    try {
      final db = ref.read(databaseServiceProvider);
      final result = await db.getPlaylistItemsByChannel(
        id,
        limit: channelPreviewPageSize,
        offset: state.works.length,
      );
      if (!ref.mounted) return;
      final hasMore = result.length >= channelPreviewPageSize;
      state = ChannelPreviewState.loaded(
        works: [...state.works, ...result],
        hasMore: hasMore,
      );
    } catch (e, stack) {
      if (!ref.mounted) return;
      _log.severe('Failed to load more channel preview for $id', e, stack);
      state = state.copyWith(
        isLoadingMore: false,
        error: e.toString(),
      );
    }
  }
}

/// Provider for channel preview state (family by channelId).
/// Auto-dispose when no longer watched.
final NotifierProviderFamily<
  ChannelPreviewNotifier,
  ChannelPreviewState,
  String
>
channelPreviewProvider = NotifierProvider.autoDispose
    .family<ChannelPreviewNotifier, ChannelPreviewState, String>(
      ChannelPreviewNotifier.new,
    );
