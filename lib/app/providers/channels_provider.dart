import 'dart:async';

import 'package:app/app/providers/mutations.dart';
import 'package:app/domain/models/channel.dart';
import 'package:app/infra/database/database_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';

/// State for a single channel type (curated or personal).
/// Aligns with old repo: one list per ChannelType,
/// pagination for curated only.
class ChannelsState {
  /// Creates a ChannelsState.
  const ChannelsState({
    required this.channels,
    required this.isLoading,
    required this.isLoadingMore,
    required this.hasMore,
    required this.cursor,
    this.total,
    this.error,
  });

  /// Channels for this type (domain).
  final List<Channel> channels;

  /// Whether channels are being loaded.
  final bool isLoading;

  /// Whether more channels are being loaded (pagination).
  final bool isLoadingMore;

  /// Whether there are more channels to load (pagination).
  final bool hasMore;

  /// Cursor for pagination (stringified offset).
  final String? cursor;

  /// Total count when known (optional).
  final int? total;

  /// Error if loading failed.
  final String? error;

  /// Initial state.
  factory ChannelsState.initial() {
    return const ChannelsState(
      channels: [],
      isLoading: false,
      isLoadingMore: false,
      hasMore: true,
      cursor: null,
    );
  }

  /// Loading state.
  factory ChannelsState.loading() {
    return const ChannelsState(
      channels: [],
      isLoading: true,
      isLoadingMore: false,
      hasMore: true,
      cursor: null,
    );
  }

  /// Loaded state.
  factory ChannelsState.loaded({
    required List<Channel> channels,
    required bool hasMore,
    required String? cursor,
    int? total,
  }) {
    return ChannelsState(
      channels: channels,
      isLoading: false,
      isLoadingMore: false,
      hasMore: hasMore,
      cursor: cursor,
      total: total,
    );
  }

  /// Error state.
  factory ChannelsState.error(String error) {
    return ChannelsState(
      channels: [],
      isLoading: false,
      isLoadingMore: false,
      hasMore: false,
      cursor: null,
      error: error,
    );
  }

  /// Copy with new values.
  ChannelsState copyWith({
    List<Channel>? channels,
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
    return ChannelsState(
      channels: channels ?? this.channels,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasMore: hasMore ?? this.hasMore,
      cursor: clearCursor ? null : (cursor ?? this.cursor),
      total: clearTotal ? null : (total ?? this.total),
      error: clearError ? null : (error ?? this.error),
    );
  }
}

/// Notifier for one channel type (curated = dp1, personal = localVirtual).
/// Aligns with old repo: ChannelsBloc(channelType, total?, pageSize).
class ChannelsNotifier extends Notifier<ChannelsState> {
  ChannelsNotifier(this._type);

  static const int _pageSize = 5;

  final ChannelType _type;
  late final Logger _log;
  StreamSubscription<List<Channel>>? _watchSub;

  @override
  ChannelsState build() {
    _log = Logger('ChannelsNotifier(${_type.name})');
    ref.onDispose(() async {
      _log.info('Disposing ChannelsNotifier, cancelling subscription');
      await _watchSub?.cancel();
      _watchSub = null;
    });

    // Best practice: keep build() synchronous; defer subscriptions to the next turn.
    // Stream.listen() can emit synchronously; if we set up the watch here and the
    // callback runs before build() returns, Riverpod throws "uninitialized provider".
    // Future.microtask ensures the notifier is fully initialized before any callback.
    unawaited(Future.microtask(_setupDatabaseWatch));
    return ChannelsState.initial();
  }

  void _setupDatabaseWatch() {
    _watchSub?.cancel();
    final databaseService = ref.read(databaseServiceProvider);
    final limit =
        (_pageSize > state.channels.length) ? _pageSize : state.channels.length;
    _watchSub = databaseService
        .watchChannels(type: _type, limit: limit)
        .listen(_onChannelsChanged, onError: _onWatchError);
  }

  void _onWatchError(Object error, StackTrace stack) {
    _log.warning('Database watch error', error, stack);
  }

  void _onChannelsChanged(List<Channel> next) {
    if (state.channels.isEmpty && !state.isLoading) {
      unawaited(loadChannels(size: _pageSize));
      return;
    }
    final current = state.channels;
    final hasChanged = !_sameChannelIds(current, next);
    if (hasChanged && !state.isLoading && !state.isLoadingMore) {
      if (_type == ChannelType.dp1) {
        final size = current.isEmpty ? _pageSize : current.length;
        unawaited(loadChannels(size: size));
      } else {
        state = state.copyWith(channels: next);
      }
    }
  }

  bool _sameChannelIds(List<Channel> a, List<Channel> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].id != b[i].id) return false;
    }
    return true;
  }

  /// Load channels for this type.
  /// Pagination applies to dp1 (curated); localVirtual loads all.
  Future<void> loadChannels({int? size}) async {
    try {
      final effectiveSize = size ?? _pageSize;
      _log.info(
        'Loading channels from database (type: ${_type.name}, size: $effectiveSize)...',
      );
      state = state.copyWith(isLoading: true, clearError: true);

      final databaseService = ref.read(databaseServiceProvider);

      if (_type == ChannelType.dp1) {
        final result = await databaseService.getChannelsByType(
          ChannelType.dp1,
          limit: effectiveSize + 1,
        );
        final hasMore = result.length > effectiveSize;
        final page = hasMore ? result.take(effectiveSize).toList() : result;
        final nextCursor = hasMore ? effectiveSize.toString() : null;
        state = ChannelsState.loaded(
          channels: page,
          hasMore: hasMore,
          cursor: nextCursor,
          total: null,
        );
        _log.info(
          'Curated channels: ${page.length}, hasMore: $hasMore, cursor: $nextCursor',
        );
      } else {
        final personalAll = await databaseService.getChannelsByType(
          ChannelType.localVirtual,
        );
        state = ChannelsState.loaded(
          channels: personalAll,
          hasMore: false,
          cursor: null,
          total: personalAll.length,
        );
        _log.info('Personal channels: ${personalAll.length}');
      }
    } catch (e, stack) {
      _log.severe('Failed to load channels', e, stack);
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Refresh channels.
  Future<void> refresh() async {
    final size = state.channels.isEmpty ? _pageSize : state.channels.length;
    await loadChannels(size: _type == ChannelType.dp1 ? size : null);
  }

  /// Load more channels. Only applies to dp1 (curated).
  Future<void> loadMore() async {
    if (_type != ChannelType.dp1 ||
        state.isLoading ||
        state.isLoadingMore ||
        !state.hasMore) {
      return;
    }
    final cursor = state.cursor;
    final start = int.tryParse(cursor ?? '') ?? state.channels.length;
    if (start < 0) return;

    try {
      state = state.copyWith(isLoadingMore: true, clearError: true);

      final databaseService = ref.read(databaseServiceProvider);
      final result = await databaseService.getChannelsByType(
        ChannelType.dp1,
        limit: _pageSize + 1,
        offset: start,
      );

      if (result.isEmpty) {
        state = state.copyWith(
          isLoadingMore: false,
          hasMore: false,
          clearCursor: true,
        );
        return;
      }

      final hasMore = result.length > _pageSize;
      final page = hasMore ? result.take(_pageSize).toList() : result;
      final nextCursor = hasMore ? (start + _pageSize).toString() : null;
      final nextChannels = [...state.channels, ...page];

      state = state.copyWith(
        channels: nextChannels,
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

/// Provider for channels state by type (dp1 = curated, localVirtual = personal).
final channelsProvider =
    NotifierProvider.family<ChannelsNotifier, ChannelsState, ChannelType>(
  ChannelsNotifier.new,
);

/// Mutation for loading channels (generic; use with specific type in UI).
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
final channelByIdProvider = FutureProvider.family<Channel?, String>((
  ref,
  channelId,
) async {
  final databaseService = ref.watch(databaseServiceProvider);
  return databaseService.getChannelById(channelId);
});
