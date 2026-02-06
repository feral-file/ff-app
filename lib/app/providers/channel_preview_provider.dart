import 'dart:async';

import 'package:app/domain/models/playlist_item.dart';
import 'package:app/infra/database/database_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';

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
  StreamSubscription<List<PlaylistItem>>? _watchSub;

  @override
  ChannelPreviewState build() {
    _log = Logger('ChannelPreviewNotifier($_channelId)');
    ref.onDispose(() {
      _log.info('Disposing ChannelPreviewNotifier, cancelling subscription');
      unawaited(_watchSub?.cancel());
      _watchSub = null;
    });

    _setupDatabaseWatch();
    return ChannelPreviewState.initial();
  }

  void _setupDatabaseWatch() {
    unawaited(_watchSub?.cancel());
    _watchSub = null;
    if (_channelId.isEmpty) return;

    final databaseService = ref.read(databaseServiceProvider);
    _watchSub = databaseService
        .watchPlaylistItemsByChannel(
          _channelId,
          limit: channelPreviewPageSize + 1,
          offset: 0,
        )
        .listen(_onPlaylistItemsChanged, onError: _onWatchError);
  }

  void _onWatchError(Object error, StackTrace stack) {
    _log.warning('Database watch error', error, stack);
  }

  void _onPlaylistItemsChanged(List<PlaylistItem> next) {
    load();
  }

  /// Load first page of preview works.
  /// Single join query; requests limit+1 to detect hasMore.
  Future<void> load() async {
    final id = _channelId;
    if (id.isEmpty) return;

    if (state.isLoading) return;

    state = ChannelPreviewState.loading();

    try {
      final db = ref.read(databaseServiceProvider);
      final result = await db.getPlaylistItemsByChannel(
        id,
        limit: channelPreviewPageSize + 1,
        offset: 0,
      );
      final hasMore = result.length > channelPreviewPageSize;
      final pageItems =
          hasMore ? result.take(channelPreviewPageSize).toList() : result;

      state = ChannelPreviewState.loaded(works: pageItems, hasMore: hasMore);
    } catch (e, stack) {
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
      final hasMore = result.length >= channelPreviewPageSize;
      state = ChannelPreviewState.loaded(
        works: [...state.works, ...result],
        hasMore: hasMore,
      );
    } catch (e, stack) {
      _log.severe('Failed to load more channel preview for $id', e, stack);
      state = state.copyWith(
        isLoadingMore: false,
        error: e.toString(),
        clearError: false,
      );
    }
  }
}

/// Provider for channel preview state (family by channelId).
/// Auto-dispose when no longer watched.
final channelPreviewProvider = NotifierProvider.autoDispose
    .family<ChannelPreviewNotifier, ChannelPreviewState, String>(
        ChannelPreviewNotifier.new);
