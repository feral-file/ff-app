import 'dart:async';

import 'package:app/app/providers/mutations.dart';
import 'package:app/domain/models/channel.dart';
import 'package:app/infra/database/database_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';

/// Enhanced state for channels with curated vs personal separation.
class ChannelsState {
  /// Creates a ChannelsState.
  const ChannelsState({
    required this.curatedChannels,
    required this.personalChannels,
    required this.isLoading,
    required this.isLoadingMore,
    required this.hasMore,
    required this.cursor,
    this.error,
  });

  /// Curated channels from DP1 feeds.
  final List<Channel> curatedChannels;

  /// Personal channels (e.g., My Collection).
  final List<Channel> personalChannels;

  /// Whether channels are being loaded.
  final bool isLoading;

  /// Whether more channels are being loaded (pagination).
  final bool isLoadingMore;

  /// Whether there are more curated channels to load.
  ///
  /// Note: pagination currently applies to curated channels only.
  final bool hasMore;

  /// Cursor for curated channels pagination (stringified offset).
  final String? cursor;

  /// Error if loading failed.
  final String? error;

  /// Initial state.
  factory ChannelsState.initial() {
    return const ChannelsState(
      curatedChannels: [],
      personalChannels: [],
      isLoading: false,
      isLoadingMore: false,
      hasMore: true,
      cursor: null,
    );
  }

  /// Loading state.
  factory ChannelsState.loading() {
    return const ChannelsState(
      curatedChannels: [],
      personalChannels: [],
      isLoading: true,
      isLoadingMore: false,
      hasMore: true,
      cursor: null,
    );
  }

  /// Loaded state.
  factory ChannelsState.loaded({
    required List<Channel> curated,
    required List<Channel> personal,
    required bool hasMore,
    required String? cursor,
  }) {
    return ChannelsState(
      curatedChannels: curated,
      personalChannels: personal,
      isLoading: false,
      isLoadingMore: false,
      hasMore: hasMore,
      cursor: cursor,
    );
  }

  /// Error state.
  factory ChannelsState.error(String error) {
    return ChannelsState(
      curatedChannels: [],
      personalChannels: [],
      isLoading: false,
      isLoadingMore: false,
      hasMore: false,
      cursor: null,
      error: error,
    );
  }

  /// Copy with new values.
  ChannelsState copyWith({
    List<Channel>? curatedChannels,
    List<Channel>? personalChannels,
    bool? isLoading,
    bool? isLoadingMore,
    bool? hasMore,
    String? cursor,
    bool clearCursor = false,
    String? error,
    bool clearError = false,
  }) {
    return ChannelsState(
      curatedChannels: curatedChannels ?? this.curatedChannels,
      personalChannels: personalChannels ?? this.personalChannels,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasMore: hasMore ?? this.hasMore,
      cursor: clearCursor ? null : (cursor ?? this.cursor),
      error: clearError ? null : (error ?? this.error),
    );
  }
}

/// Notifier for channels list.
/// Provides reactive access to channels from the database.
class ChannelsNotifier extends Notifier<ChannelsState> {
  static const int _pageSize = 5;

  late final Logger _log;
  StreamSubscription<List<Channel>>? _curatedSub;
  StreamSubscription<List<Channel>>? _personalSub;
  int? _curatedWatchLimit;

  @override
  ChannelsState build() {
    _log = Logger('ChannelsNotifier');
    ref.onDispose(() async {
      _log.info('Disposing ChannelsNotifier, cancelling subscriptions');
      await _curatedSub?.cancel();
      await _personalSub?.cancel();
      _curatedSub = null;
      _personalSub = null;
    });

    // Start watching the database immediately (old repo semantics).
    _setupDatabaseWatch();

    return ChannelsState.initial();
  }

  void _setupDatabaseWatch() {
    _ensureCuratedWatch(limit: _pageSize);

    // Personal channels are typically small; watch all localVirtual channels.
    _personalSub?.cancel();
    final databaseService = ref.read(databaseServiceProvider);
    _personalSub = databaseService
        .watchChannels(type: ChannelType.localVirtual)
        .listen(_onPersonalChannelsChanged, onError: _onWatchError);
  }

  void _ensureCuratedWatch({required int limit}) {
    if (_curatedWatchLimit == limit) return;
    _curatedWatchLimit = limit;

    _curatedSub?.cancel();
    final databaseService = ref.read(databaseServiceProvider);
    _curatedSub = databaseService
        .watchChannels(type: ChannelType.dp1, limit: limit)
        .listen(_onCuratedChannelsChanged, onError: _onWatchError);
  }

  void _onWatchError(Object error, StackTrace stack) {
    _log.warning('Database watch error', error, stack);
    // Do not force an error state here; keep UI usable and rely on explicit loads.
  }

  void _onCuratedChannelsChanged(List<Channel> curated) {
    // If we haven't loaded yet, do an initial load using page size.
    if (state.curatedChannels.isEmpty && !state.isLoading) {
      unawaited(loadChannels(size: _pageSize));
      return;
    }

    // If the subset we are watching changed, refresh the currently loaded size.
    final current = state.curatedChannels;
    final hasChanged = !_sameChannelIds(current, curated);
    if (hasChanged && !state.isLoading && !state.isLoadingMore) {
      final size = current.isEmpty ? _pageSize : current.length;
      unawaited(loadChannels(size: size));
    }
  }

  void _onPersonalChannelsChanged(List<Channel> personal) {
    // Personal channels are not paginated; just update if changed.
    final current = state.personalChannels;
    final hasChanged = !_sameChannelIds(current, personal);
    if (hasChanged && !state.isLoading && !state.isLoadingMore) {
      state = state.copyWith(personalChannels: personal);
    }
  }

  bool _sameChannelIds(List<Channel> a, List<Channel> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].id != b[i].id) return false;
    }
    return true;
  }

  /// Load channels from database.
  ///
  /// Pagination applies to curated channels. Personal channels are loaded fully.
  Future<void> loadChannels({int size = _pageSize}) async {
    try {
      _log.info('Loading channels from database (size: $size)...');
      state = state.copyWith(isLoading: true, clearError: true);

      final databaseService = ref.read(databaseServiceProvider);
      final allChannels = await databaseService.getChannels();

      _log.info('Loaded ${allChannels.length} total channels from database');

      // Separate curated vs personal.
      // Old repo semantics: curated = DP1; personal = localVirtual (e.g., My Collection).
      final curatedAll =
          allChannels.where((c) => c.type == ChannelType.dp1).toList();
      final personalAll =
          allChannels.where((c) => c.type == ChannelType.localVirtual).toList();

      final end = size.clamp(0, curatedAll.length);
      final curated = curatedAll.take(end).toList();

      final nextCursor = end < curatedAll.length ? end.toString() : null;
      final hasMore = nextCursor != null;

      _log.info(
        'Curated channels: ${curated.length}/${curatedAll.length}, '
        'Personal channels: ${personalAll.length}, hasMore: $hasMore, '
        'cursor: $nextCursor',
      );

      _ensureCuratedWatch(
        limit: curated.length < _pageSize ? _pageSize : curated.length,
      );

      state = ChannelsState.loaded(
        curated: curated,
        personal: personalAll,
        hasMore: hasMore,
        cursor: nextCursor,
      );
    } catch (e, stack) {
      _log.severe('Failed to load channels', e, stack);
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Refresh channels (re-load from database).
  Future<void> refresh() async {
    final size = state.curatedChannels.isEmpty
        ? _pageSize
        : state.curatedChannels.length;
    await loadChannels(size: size);
  }

  /// Load more curated channels.
  Future<void> loadMore() async {
    if (state.isLoading || state.isLoadingMore || !state.hasMore) {
      return;
    }

    final cursor = state.cursor;
    final start = int.tryParse(cursor ?? '') ?? state.curatedChannels.length;
    if (start < 0) return;

    try {
      state = state.copyWith(isLoadingMore: true, clearError: true);

      final databaseService = ref.read(databaseServiceProvider);
      final allChannels = await databaseService.getChannels();
      final curatedAll =
          allChannels.where((c) => c.type == ChannelType.dp1).toList();

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
      final nextCurated = [...state.curatedChannels, ...page];
      final nextCursor = end < curatedAll.length ? end.toString() : null;
      final hasMore = nextCursor != null;

      _ensureCuratedWatch(limit: nextCurated.length);

      state = state.copyWith(
        curatedChannels: nextCurated,
        isLoadingMore: false,
        hasMore: hasMore,
        cursor: nextCursor,
      );
    } catch (e, stack) {
      _log.severe('Failed to load more channels', e, stack);
      state = state.copyWith(isLoadingMore: false, error: e.toString());
    }
  }
}

/// Provider for channels list.
final channelsProvider = NotifierProvider<ChannelsNotifier, ChannelsState>(
  ChannelsNotifier.new,
);

/// Mutation for loading channels.
final loadChannelsMutationProvider =
    NotifierProvider<MutationNotifier<void>, MutationState<void>>(
  MutationNotifier.new,
);

/// Mutation for refreshing channels.
final refreshChannelsMutationProvider =
    NotifierProvider<MutationNotifier<void>, MutationState<void>>(
  MutationNotifier.new,
);

/// Mutation for loading more channels.
final loadMoreChannelsMutationProvider =
    NotifierProvider<MutationNotifier<void>, MutationState<void>>(
  MutationNotifier.new,
);

/// Provider for a specific channel by ID.
final channelByIdProvider =
    FutureProvider.family<Channel?, String>((ref, channelId) async {
  final databaseService = ref.watch(databaseServiceProvider);
  return databaseService.getChannelById(channelId);
});
