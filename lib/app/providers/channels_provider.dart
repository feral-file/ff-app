import 'dart:async';

import 'package:app/app/providers/database_error_utils.dart';
import 'package:app/app/providers/database_service_provider.dart';
import 'package:app/app/providers/seed_database_ready_provider.dart';
import 'package:app/domain/models/channel.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:riverpod/src/providers/future_provider.dart';
import 'package:riverpod/src/providers/notifier.dart';

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
  ChannelsNotifier(this._type)
    : _log = Logger('ChannelsNotifier(${_type.name})');

  static const int _pageSize = 10;

  final ChannelType _type;
  final Logger _log;
  StreamSubscription<List<Channel>>? _watchSub;

  @override
  ChannelsState build() {
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
    if (!ref.mounted) return;
    if (!ref.read(isSeedDatabaseReadyProvider)) return;
    _watchSub?.cancel();
    final databaseService = ref.read(databaseServiceProvider);
    // Use watchChannelsByType so we react to playlist_entries changes
    // (remove address, unfavorite). watchChannels only watches channels table.
    if (_type == ChannelType.localVirtual) {
      _watchSub = databaseService
          .watchChannelsByType(ChannelType.localVirtual)
          .listen(_onChannelsChanged, onError: _onWatchError);
    } else {
      final listenSize = (_pageSize > state.channels.length)
          ? _pageSize
          : state.channels.length;
      _watchSub = databaseService
          .watchChannelsByType(ChannelType.dp1, limit: listenSize)
          .listen(_onChannelsChanged, onError: _onWatchError);
    }
  }

  void _onWatchError(Object error, StackTrace stack) {
    _log.warning('Database watch error', error, stack);
    if (!ref.mounted || !isDatabaseUnavailableError(error)) return;
    state = ChannelsState.loaded(
      channels: const <Channel>[],
      hasMore: false,
      cursor: null,
      total: 0,
    );
  }

  void _onChannelsChanged(List<Channel> next) {
    if (!ref.mounted) return;
    if (_type == ChannelType.localVirtual) {
      // Stream already returns filtered channels (with items). Use directly.
      state = ChannelsState.loaded(
        channels: next,
        hasMore: false,
        cursor: null,
        total: next.length,
      );
      return;
    }
    // dp1: use emission as trigger to refresh (pagination).
    if (state.channels.isEmpty && !state.isLoading) {
      unawaited(refresh());
      return;
    }
    final current = state.channels;
    final loadedLength = current.length;
    final listenSize = loadedLength > _pageSize ? loadedLength : _pageSize;
    final slice = next.take(listenSize).toList();
    final hasChanged =
        current.length != slice.length || !listEquals(current, slice);
    if (hasChanged) {
      unawaited(refresh());
    }
  }

  /// Load channels for this type.
  /// Pagination applies to dp1 (curated); localVirtual loads all.
  Future<void> loadChannels({int? size, bool showLoading = true}) async {
    try {
      final effectiveSize = size ?? _pageSize;
      _log.info(
        'Loading channels from database (type: ${_type.name}, size: $effectiveSize)...',
      );
      if (showLoading) {
        state = state.copyWith(isLoading: true, clearError: true);
      }

      final databaseService = ref.read(databaseServiceProvider);

      if (_type == ChannelType.dp1) {
        final result = await databaseService.getChannelsByType(
          ChannelType.dp1,
          limit: effectiveSize + 1,
        );
        if (!ref.mounted) return;
        final hasMore = result.length > effectiveSize;
        final page = hasMore ? result.take(effectiveSize).toList() : result;
        final nextCursor = hasMore ? effectiveSize.toString() : null;
        state = ChannelsState.loaded(
          channels: page,
          hasMore: hasMore,
          cursor: nextCursor,
        );
        _log.info(
          'Curated channels: ${page.length}, hasMore: $hasMore, cursor: $nextCursor',
        );
      } else {
        final personalAll = await databaseService.getChannelsByType(
          ChannelType.localVirtual,
        );
        if (!ref.mounted) return;
        state = ChannelsState.loaded(
          channels: personalAll,
          hasMore: false,
          cursor: null,
          total: personalAll.length,
        );
        _log.info('Personal channels: ${personalAll.length}');
      }
    } catch (e, stack) {
      if (!ref.mounted) return;
      if (isDatabaseUnavailableError(e)) {
        state = ChannelsState.loaded(
          channels: const <Channel>[],
          hasMore: false,
          cursor: null,
          total: 0,
        );
        return;
      }
      if (_isOperationCancelled(e)) {
        _log.info('Channels load cancelled');
        state = state.copyWith(isLoading: false, clearError: true);
        return;
      }
      _log.severe('Failed to load channels', e, stack);
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Refresh channels.
  Future<void> refresh() async {
    final size = state.channels.isEmpty ? _pageSize : state.channels.length;
    await loadChannels(
      size: _type == ChannelType.dp1 ? size : null,
      showLoading: false,
    );
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

      if (!ref.mounted) return;
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
      if (!ref.mounted) return;
      if (isDatabaseUnavailableError(e)) {
        state = state.copyWith(
          channels: const <Channel>[],
          isLoadingMore: false,
          hasMore: false,
          clearCursor: true,
          clearError: true,
        );
        return;
      }
      if (_isOperationCancelled(e)) {
        _log.info('Load more channels cancelled');
        state = state.copyWith(isLoadingMore: false, clearError: true);
        return;
      }
      _log.severe('Failed to load more channels', e, stack);
      state = state.copyWith(isLoadingMore: false, error: e.toString());
    }
  }
}

bool _isOperationCancelled(Object error) {
  return error.runtimeType.toString() == 'CancellationException' ||
      error.toString().contains('Operation was cancelled');
}

/// Provider for channels state by type (dp1 = curated, localVirtual = personal).
final NotifierProviderFamily<ChannelsNotifier, ChannelsState, ChannelType>
channelsProvider =
    NotifierProvider.family<ChannelsNotifier, ChannelsState, ChannelType>(
      ChannelsNotifier.new,
    );

/// Provider for a specific channel by ID.
final FutureProviderFamily<Channel?, String> channelByIdProvider =
    FutureProvider.family<Channel?, String>((
      ref,
      channelId,
    ) async {
      final databaseService = ref.watch(databaseServiceProvider);
      try {
        return await databaseService.getChannelById(channelId);
      } on Object catch (e) {
        if (isDatabaseUnavailableError(e)) {
          return null;
        }
        rethrow;
      }
    });
