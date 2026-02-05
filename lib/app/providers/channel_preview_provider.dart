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

  /// Cached flattened list of all items for the channel (for loadMore).
  List<PlaylistItem>? _cachedFlattened;

  @override
  ChannelPreviewState build() {
    _log = Logger('ChannelPreviewNotifier($_channelId)');
    return ChannelPreviewState.initial();
  }

  /// Load first page of preview works.
  /// Flattens items from all playlists in the channel (playlist order).
  Future<void> load() async {
    final id = _channelId;
    if (id.isEmpty) return;

    if (state.isLoading) return;

    state = ChannelPreviewState.loading();

    try {
      final db = ref.read(databaseServiceProvider);
      final playlists = await db.getPlaylistsByChannel(id);
      final flattened = <PlaylistItem>[];
      for (final playlist in playlists) {
        final items = await db.getPlaylistItems(playlist.id);
        flattened.addAll(items);
      }
      _cachedFlattened = flattened;

      final pageItems = flattened.take(channelPreviewPageSize).toList();
      final hasMore = flattened.length > channelPreviewPageSize;

      state = ChannelPreviewState.loaded(works: pageItems, hasMore: hasMore);
    } catch (e, stack) {
      _log.severe('Failed to load channel preview for $id', e, stack);
      state = ChannelPreviewState.error(e.toString());
    }
  }

  /// Load next page and append to works.
  Future<void> loadMore() async {
    final id = _channelId;
    if (id.isEmpty) return;
    if (state.isLoadingMore || !state.hasMore) return;

    final cached = _cachedFlattened;
    if (cached == null || cached.isEmpty) {
      state = state.copyWith(hasMore: false);
      return;
    }

    state = state.copyWith(isLoadingMore: true);

    try {
      final currentLength = state.works.length;
      if (currentLength >= cached.length) {
        state = state.copyWith(hasMore: false, isLoadingMore: false);
        return;
      }

      final nextStart = currentLength;
      final nextEnd = (nextStart + channelPreviewPageSize).clamp(0, cached.length);
      final nextPage = cached.sublist(nextStart, nextEnd);
      final hasMore = nextEnd < cached.length;

      state = ChannelPreviewState.loaded(
        works: [...state.works, ...nextPage],
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
final channelPreviewProvider =
    NotifierProvider.autoDispose.family<ChannelPreviewNotifier,
        ChannelPreviewState, String>(ChannelPreviewNotifier.new);
