import 'dart:async';

import 'package:app/app/now_displaying/now_displaying_enrichment.dart';
import 'package:app/app/providers/database_service_provider.dart';
import 'package:app/app/providers/ff1_bluetooth_device_providers.dart';
import 'package:app/app/providers/ff1_wifi_providers.dart';
import 'package:app/app/providers/services_provider.dart';
import 'package:app/domain/models/dp1/dp1_playlist_item.dart';
import 'package:app/domain/models/ff1_device.dart';
import 'package:app/domain/models/now_displaying_object.dart';
import 'package:app/domain/models/playlist_item.dart';
import 'package:app/infra/ff1/wifi_protocol/ff1_wifi_messages.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Half-size of the now-displaying items window (index ± this value).
/// Only items in this window are loaded from cache and enriched; the rest use
/// DP1 fallback to avoid loading thousands of items at once.
const int nowDisplayingWindowHalfSize = 50;

/// Playlist + ordered item ids from [FF1PlayerStatus], used to detect when the
/// playing list changed vs index-only / transport-only updates (pause, sleep).
typedef _PlaylistIdentity = ({
  String? playlistId,
  List<String> itemIds,
});

enum _NowDisplayingRecomputeCause {
  /// Player/device/connection/connecting or initial build.
  generic,
  /// User expanded scroll range in the bar; window may need new cache/enrichment.
  requestedRange,
}

_PlaylistIdentity? _playlistIdentityFromStatus(FF1PlayerStatus? status) {
  if (status == null) return null;
  final items = status.items;
  if (items == null) return null;
  return (
    playlistId: status.playlistId,
    itemIds: [for (final i in items) i.id],
  );
}

bool _playlistIdentitiesEqual(_PlaylistIdentity? a, _PlaylistIdentity? b) {
  if (a == null || b == null) return false;
  if (a.playlistId != b.playlistId) return false;
  if (a.itemIds.length != b.itemIds.length) return false;
  for (var i = 0; i < a.itemIds.length; i++) {
    if (a.itemIds[i] != b.itemIds[i]) return false;
  }
  return true;
}

bool _windowsEqual(
  ({int start, int end}) a,
  ({int start, int end}) b,
) {
  return a.start == b.start && a.end == b.end;
}

_NowDisplayingRecomputeCause _mergeRecomputeCauses(
  _NowDisplayingRecomputeCause a,
  _NowDisplayingRecomputeCause b,
) {
  if (a == _NowDisplayingRecomputeCause.requestedRange ||
      b == _NowDisplayingRecomputeCause.requestedRange) {
    return _NowDisplayingRecomputeCause.requestedRange;
  }
  return _NowDisplayingRecomputeCause.generic;
}

String? _deviceIdFromAsync(AsyncValue<FF1Device?>? asyncValue) {
  return asyncValue?.when(
    data: (device) => device?.deviceId,
    loading: () => null,
    error: (_, _) => null,
  );
}

/// Item IDs from current FF1 player status (for cache lookup).
final nowDisplayingItemIdsProvider = Provider<List<String>>((ref) {
  final status = ref.watch(ff1CurrentPlayerStatusProvider);
  final items = status?.items;
  if (items == null || items.isEmpty) return [];
  return items.map((e) => e.id).toList();
});

/// User-requested range from scrolling in the expanded bar.
/// When set, the effective window is merged with the base window
/// (around current index).
final nowDisplayingRequestedRangeProvider =
    NotifierProvider<
      NowDisplayingRequestedRangeNotifier,
      ({int start, int end})?
    >(
      NowDisplayingRequestedRangeNotifier.new,
    );

/// Notifier for scroll-requested window range; updated when user scrolls in the
/// expanded bar.
class NowDisplayingRequestedRangeNotifier
    extends Notifier<({int start, int end})?> {
  _PlaylistIdentity? _lastConfirmedIdentity;

  @override
  ({int start, int end})? build() {
    _lastConfirmedIdentity = _playlistIdentityFromStatus(
      ref.read(ff1CurrentPlayerStatusProvider),
    );

    // Drop monotonic scroll expansion when the playing list identity changes
    // (new playlist / ordered items) or playback clears, so playlist B does
    // not inherit A's widened range.
    ref.listen<FF1PlayerStatus?>(
      ff1CurrentPlayerStatusProvider,
      (prev, next) {
        // Clear when playback is explicitly cleared (playlistId == null).
        // A transient provider null (loading/error/reconnect) does not map to
        // a real playback clear and must not clear the expanded range.
        if (next != null && next.playlistId == null) {
          _lastConfirmedIdentity = null;
          state = null;
          return;
        }

        // Only clear on confirmed playing-list identity change. Identity is
        // considered "confirmed" only when FF1 provides an item list; gaps
        // where items are null (device still fetching) or provider is null
        // (reconnect) should not clear on their own.
        final after = _playlistIdentityFromStatus(next);
        if (after == null) return;

        final last = _lastConfirmedIdentity;
        if (last != null && !_playlistIdentitiesEqual(last, after)) {
          state = null;
        }
        _lastConfirmedIdentity = after;
      },
    );
    return null;
  }

  /// Merges `[start,end)` into the current requested range (expands to include
  /// the new range).
  void expandTo(int start, int end) {
    final prev = state;
    if (prev == null) {
      state = (start: start, end: end);
      return;
    }
    final mergedStart = start < prev.start ? start : prev.start;
    final mergedEnd = end > prev.end ? end : prev.end;
    state = (start: mergedStart, end: mergedEnd);
  }

  /// Clears scroll expansion so the next window is only around the current
  /// work index.
  /// Call when the playing list identity changes (new playlist / items from FF1).
  void clear() {
    state = null;
  }
}

/// Window of indices `[start,end)` around currentWorkIndex, merged with
/// scroll-requested range.
/// Only items in this range are fetched from cache and enriched.
final nowDisplayingWindowProvider = Provider<({int start, int end})?>((ref) {
  final status = ref.watch(ff1CurrentPlayerStatusProvider);
  final items = status?.items;
  final index = status?.currentWorkIndex;
  final requested = ref.watch(
    nowDisplayingRequestedRangeProvider,
  );
  if (items == null ||
      items.isEmpty ||
      index == null ||
      index < 0 ||
      index >= items.length) {
    return null;
  }
  final baseStart = (index - nowDisplayingWindowHalfSize).clamp(
    0,
    items.length,
  );
  final baseEnd = (index + nowDisplayingWindowHalfSize + 1).clamp(
    0,
    items.length,
  );
  if (requested == null) {
    return (start: baseStart, end: baseEnd);
  }
  final start = (requested.start < baseStart ? requested.start : baseStart)
      .clamp(0, items.length);
  final end = (requested.end > baseEnd ? requested.end : baseEnd).clamp(
    0,
    items.length,
  );
  return (start: start, end: end);
});

/// Item IDs in the current window only (for cache and enrichment).
final nowDisplayingWindowItemIdsProvider = Provider<List<String>>((ref) {
  final ids = ref.watch(nowDisplayingItemIdsProvider);
  final window = ref.watch(nowDisplayingWindowProvider);
  if (ids.isEmpty || window == null) return [];
  return ids.sublist(window.start, window.end);
});

/// Cached [PlaylistItem]s for the current now-displaying item IDs in window
/// only.
/// Used to show enriched data (e.g. thumbnail, artists) when available locally.
final nowDisplayingCachedPlaylistItemsProvider =
    FutureProvider<List<PlaylistItem>>((ref) async {
      final ids = ref.watch(nowDisplayingWindowItemIdsProvider);
      if (ids.isEmpty) return [];
      return ref.read(databaseServiceProvider).getPlaylistItemsByIds(ids);
    });

/// Now displaying state derived from FF1 device + player status.
///
/// This replaces the legacy `NowDisplayingManager` stream-based implementation.
final nowDisplayingProvider =
    NotifierProvider<NowDisplayingNotifier, NowDisplayingStatus>(
      NowDisplayingNotifier.new,
    );

/// Computes [NowDisplayingStatus] from FF1 device + player status signals.
class NowDisplayingNotifier extends Notifier<NowDisplayingStatus> {
  /// Bumped on every [_enqueueRecompute]; each loop iteration captures an
  /// epoch snapshot so a slow async pass does not publish after newer FF1 data.
  int _recomputeToken = 0;

  /// Identity of the last **full** compute (cache + enrich). Used to skip
  /// loading UI and the heavy path when only index / pause / sleep changes.
  _PlaylistIdentity? _lastFullComputeIdentity;

  /// Items from the last successful full compute; used for fast path when
  /// [state] is briefly [LoadingNowDisplaying] between microtask phases.
  List<PlaylistItem>? _lastFullSuccessPlaylistItems;

  /// Index from the last successful full compute.
  ///
  /// Why: ff1CurrentPlayerStatusProvider intentionally maps stream
  /// loading/error to null. A reconnect/resubscribe can briefly produce:
  /// `data -> null -> same data` without any playlist identity change.
  ///
  /// We keep showing the last known now-displaying state across that transient
  /// gap so the UI does not flash loading or clear the expanded window.
  int? _lastFullSuccessIndex;

  /// Sleep/paused flag from the last successful full compute.
  bool? _lastFullSuccessIsSleeping;

  /// Device id associated with the last successful playback snapshot.
  ///
  /// Why: reconnect-style fallback must only reuse the last success state for
  /// the same FF1 device. Reusing device A's snapshot for device B would show
  /// stale playback from the wrong screen.
  String? _lastFullSuccessDeviceId;

  /// [nowDisplayingWindowProvider] snapshot from the last full compute.
  /// Fast path is invalid if the index window shifts (new slice needs cache/enrich).
  ({int start, int end})? _lastFullComputeWindow;

  _NowDisplayingRecomputeCause _pendingRecomputeCause =
      _NowDisplayingRecomputeCause.generic;

  /// Whether a recompute request is queued for the loop to process.
  ///
  /// Why: `generic` is a real recompute cause, so it cannot also mean
  /// "nothing queued" without risking dropped updates.
  bool _hasPendingRecompute = false;

  /// True while [_runRecomputeLoop] is running; further [_enqueueRecompute]
  /// calls only merge into the pending queue and are drained by the loop.
  bool _recomputeLoopRunning = false;

  void _clearPlaybackIdentity() {
    _lastFullComputeIdentity = null;
    _lastFullSuccessPlaylistItems = null;
    _lastFullSuccessIndex = null;
    _lastFullSuccessIsSleeping = null;
    _lastFullSuccessDeviceId = null;
    _lastFullComputeWindow = null;
  }

  /// Merges [incoming] into [_pendingRecomputeCause] and runs a single async
  /// loop so newer FF1 updates can invalidate stale async work without being
  /// blocked behind it.
  ///
  /// Increments [_recomputeToken] on every call so any in-flight compute that
  /// started with an older epoch is discarded after await (newer FF1 updates
  /// must not lose to a slow cache/enrichment pass).
  void _enqueueRecompute(_NowDisplayingRecomputeCause incoming) {
    if (_hasPendingRecompute) {
      _pendingRecomputeCause = _mergeRecomputeCauses(
        _pendingRecomputeCause,
        incoming,
      );
    } else {
      _pendingRecomputeCause = incoming;
      _hasPendingRecompute = true;
    }
    _recomputeToken++;
    if (_recomputeLoopRunning) {
      return;
    }
    _recomputeLoopRunning = true;
    unawaited(_runRecomputeLoop());
  }

  Future<void> _runRecomputeLoop() async {
    try {
      while (true) {
        if (!ref.mounted) {
          return;
        }
        if (!_hasPendingRecompute) {
          break;
        }
        final cause = _pendingRecomputeCause;
        _pendingRecomputeCause = _NowDisplayingRecomputeCause.generic;
        _hasPendingRecompute = false;
        // Epoch is bumped on every [_enqueueRecompute], not here, so a newer
        // player/device update during await invalidates this iteration.
        final epoch = _recomputeToken;
        await Future<void>.microtask(() {});
        if (!ref.mounted) {
          return;
        }
        if (epoch != _recomputeToken) {
          continue;
        }
        final status = ref.read(ff1CurrentPlayerStatusProvider);
        final identity = _playlistIdentityFromStatus(status);
        final showLoadingOverlay = _shouldShowLoadingOverlay(identity);
        if (showLoadingOverlay) {
          state = const LoadingNowDisplaying();
        }
        final computed = await _computeStatus(cause: cause);
        if (!ref.mounted) {
          return;
        }
        if (epoch != _recomputeToken) {
          continue;
        }
        state = computed;
        if (!_hasPendingRecompute) {
          break;
        }
      }
    } finally {
      _recomputeLoopRunning = false;
    }
    if (!ref.mounted) {
      return;
    }
    // Wake up another loop pass if a listener queued work while we were
    // tearing down this loop instance.
    if (_hasPendingRecompute && !_recomputeLoopRunning) {
      _recomputeLoopRunning = true;
      unawaited(_runRecomputeLoop());
    }
  }

  @override
  NowDisplayingStatus build() {
    // Trigger recompute whenever these sources change.
    //
    // Note: ff1CurrentPlayerStatusProvider and ff1DeviceConnectedProvider are
    // plain Providers over values stored inside FF1WifiControl. We listen to
    // the
    // corresponding stream providers to ensure updates are observed.
    // Defer _recompute to next microtask so dependent providers (e.g.
    // ff1DeviceConnectedProvider) are rebuilt before we read them.
    ref
      ..listen<AsyncValue<FF1Device?>>(
        activeFF1BluetoothDeviceProvider,
        (previous, next) {
          final previousDeviceId = _deviceIdFromAsync(previous);
          final nextDeviceId = _deviceIdFromAsync(next);
          if (previousDeviceId != nextDeviceId) {
            _clearPlaybackIdentity();
          }
          _enqueueRecompute(_NowDisplayingRecomputeCause.generic);
        },
      )
      ..listen<AsyncValue<FF1PlayerStatus>>(
        ff1PlayerStatusStreamProvider,
        (_, _) => _enqueueRecompute(_NowDisplayingRecomputeCause.generic),
      )
      ..listen<AsyncValue<FF1ConnectionStatus>>(
        ff1ConnectionStatusStreamProvider,
        (_, _) => _enqueueRecompute(_NowDisplayingRecomputeCause.generic),
      )
      ..listen<bool>(
        ff1WifiConnectingProvider,
        (_, _) => _enqueueRecompute(_NowDisplayingRecomputeCause.generic),
      )
      ..listen<({int start, int end})?>(
        nowDisplayingRequestedRangeProvider,
        (_, _) =>
            _enqueueRecompute(_NowDisplayingRecomputeCause.requestedRange),
      );

    // Match the previous manager contract: start at an explicit initial state,
    // then compute derived status on the next microtask.
    _enqueueRecompute(_NowDisplayingRecomputeCause.generic);
    return const InitialNowDisplayingStatus();
  }

  /// Loading overlay only when the playing list identity changed (playlistId or
  /// ordered item ids), not when only index / pause / sleep changes.
  ///
  /// When [currentIdentity] is null because the stream is briefly between
  /// values (AsyncLoading) but we already have a successful full compute,
  /// do not set [LoadingNowDisplaying] here — that would hide
  /// [NowDisplayingSuccess] and break the fast path that reuses the last built
  /// item list.
  bool _shouldShowLoadingOverlay(_PlaylistIdentity? currentIdentity) {
    if (_lastFullComputeIdentity == null) {
      return true;
    }
    if (currentIdentity == null) {
      return false;
    }
    return !_playlistIdentitiesEqual(
      currentIdentity,
      _lastFullComputeIdentity,
    );
  }

  Future<NowDisplayingStatus> _computeStatus({
    required _NowDisplayingRecomputeCause cause,
  }) async {
    final activeDevice = ref.read(activeFF1BluetoothDeviceProvider);
    return activeDevice.when(
      data: (d) => _computeForDevice(d, cause: cause),
      loading: () => const LoadingNowDisplaying(),
      error: (error, _) {
        _clearPlaybackIdentity();
        return NowDisplayingError(error);
      },
    );
  }

  Future<NowDisplayingStatus> _computeForDevice(
    FF1Device? device, {
    required _NowDisplayingRecomputeCause cause,
  }) async {
    if (device == null) {
      _clearPlaybackIdentity();
      return const NoDevicePaired();
    }

    final isConnected = ref.read(ff1DeviceConnectedProvider);
    final isConnecting = ref.read(ff1WifiConnectingProvider);
    if (isConnecting) {
      return DeviceConnecting(device);
    }
    if (!isConnected) {
      return DeviceDisconnected(device);
    }

    final status = ref.read(ff1CurrentPlayerStatusProvider);
    if (status == null) {
      // ff1CurrentPlayerStatusProvider maps stream loading/error to null. A
      // reconnect/resubscribe can briefly produce:
      //   data -> null -> same data
      // This is not a playback reset and must not clear identity or flash a
      // loading overlay for the same playing list.
      final lastIdentity = _lastFullComputeIdentity;
      final lastItems = _lastFullSuccessPlaylistItems;
      final lastIndex = _lastFullSuccessIndex;
      final lastIsSleeping = _lastFullSuccessIsSleeping;
      if (lastIdentity != null &&
          lastItems != null &&
          lastIndex != null &&
          lastIsSleeping != null &&
          lastIndex >= 0 &&
          lastIndex < lastItems.length) {
        return NowDisplayingSuccess(
          DP1NowDisplayingObject(
            connectedDevice: device,
            index: lastIndex,
            items: lastItems,
            isSleeping: lastIsSleeping,
          ),
        );
      }

      _clearPlaybackIdentity();
      return LoadingNowDisplaying(device: device);
    }

    // Explicit loading state when a playlist is selected but items are still
    // being fetched on the device side.
    if (status.playlistId != null && status.items == null) {
      final lastSuccess = _buildLastSuccessStatus(device);
      final lastIdentity = _lastFullComputeIdentity;
      if (lastSuccess != null &&
          lastIdentity != null &&
          lastIdentity.playlistId == status.playlistId) {
        return lastSuccess;
      }

      _clearPlaybackIdentity();
      return LoadingNowDisplaying(
        device: device,
        playlistId: status.playlistId,
      );
    }

    final identity = _playlistIdentityFromStatus(status);

    // Fast path: same playlist + same ordered item ids, and the same visible
    // index window as the last full compute (pause / sleep / tiny index nudge
    // that does not move [start,end)). Skip SQLite + indexer.
    //
    // We do not fast-path when the window shifts (e.g. long playlist, index
    // jumps): [_lastFullSuccessPlaylistItems] may still have DP-1 fallbacks
    // outside the previous window; the new slice must reload cache + enrich.
    //
    // [requestedRange] is excluded: user expanded the bar and may need new
    // rows.
    //
    // Use [_lastFullSuccessPlaylistItems] instead of reading [state] so we are
    // not blocked when [state] is still [LoadingNowDisplaying] between loop
    // iterations or microtasks.
    final lastItems = _lastFullSuccessPlaylistItems;
    final windowNow = ref.read(nowDisplayingWindowProvider);
    final lastWindow = _lastFullComputeWindow;
    if (cause == _NowDisplayingRecomputeCause.generic &&
        identity != null &&
        _lastFullComputeIdentity != null &&
        _playlistIdentitiesEqual(identity, _lastFullComputeIdentity) &&
        lastItems != null &&
        windowNow != null &&
        lastWindow != null &&
        _windowsEqual(windowNow, lastWindow)) {
      final items = status.items!;
      final index = status.currentWorkIndex;
      if (index != null && index >= 0 && index < items.length) {
        // Keep the "last known good" snapshot aligned with the latest
        // fast-pathed device state so a transient
        // `data -> null -> same data` reconnect gap does not regress the UI to
        // an older index/sleep state.
        _lastFullSuccessIndex = index;
        _lastFullSuccessIsSleeping = status.isSleeping;
        _lastFullSuccessDeviceId = device.deviceId;
        return NowDisplayingSuccess(
          DP1NowDisplayingObject(
            connectedDevice: device,
            index: index,
            items: lastItems,
            isSleeping: status.isSleeping,
          ),
        );
      }
    }

    final items = status.items;
    final index = status.currentWorkIndex;
    if (items == null || items.isEmpty || index == null) {
      _clearPlaybackIdentity();
      return NowDisplayingError(
        StateError('No items to display'),
      );
    }
    if (index < 0 || index >= items.length) {
      _clearPlaybackIdentity();
      return NowDisplayingError(
        RangeError.index(index, items, 'currentWorkIndex'),
      );
    }

    // Window for pagination: only load cache and enrich items in [start, end).
    final window = ref.read(nowDisplayingWindowProvider);
    final start = window?.start ?? 0;
    final end = window?.end ?? items.length;

    // Await DB-backed cache: a synchronous read of the FutureProvider only
    // sees AsyncLoading while getPlaylistItemsByIds runs, which would leave
    // cachedById empty and treat every window item as missing (extra indexer
    // and enrichment work). Waiting for .future matches the actual cache state.
    List<PlaylistItem> cachedList;
    try {
      cachedList = await ref.read(
        nowDisplayingCachedPlaylistItemsProvider.future,
      );
    } on Object catch (_) {
      // Prior behavior: treat failed cache read like empty cache (no hits).
      cachedList = <PlaylistItem>[];
    }
    final cachedById = <String, PlaylistItem>{
      for (final p in cachedList) p.id: p,
    };

    // Enrich only items not already in cache to preserve offline-first
    // contract.
    // Cache misses are enriched from indexer; cache hits are served directly.
    final windowItems = items.sublist(start, end);
    final missingItems = windowItems
        .where((item) => !cachedById.containsKey(item.id))
        .toList();
    final enriched = missingItems.isNotEmpty
        ? await _enrichMissingNowDisplayingItems(missingItems)
        : <String, PlaylistItem>{};

    // Build full list: window = enriched/cached/fallback; outside window = DP1
    // fallback only.
    final playlistItems = [
      for (var i = 0; i < items.length; i++)
        (i >= start && i < end)
            ? (enriched[items[i].id] ??
                  cachedById[items[i].id] ??
                  PlaylistItem(
                    id: items[i].id,
                    kind: PlaylistItemKind.dp1Item,
                    title: items[i].title,
                    duration: items[i].duration,
                  ))
            : PlaylistItem(
                id: items[i].id,
                kind: PlaylistItemKind.dp1Item,
                title: items[i].title,
                duration: items[i].duration,
              ),
    ];

    // Full compute succeeded; record identity + items + window for loading +
    // fast-path.
    _lastFullComputeIdentity = identity;
    _lastFullSuccessPlaylistItems = playlistItems;
    _lastFullSuccessIndex = index;
    _lastFullSuccessIsSleeping = status.isSleeping;
    _lastFullSuccessDeviceId = device.deviceId;
    _lastFullComputeWindow = (start: start, end: end);

    return NowDisplayingSuccess(
      DP1NowDisplayingObject(
        connectedDevice: device,
        index: index,
        items: playlistItems,
        isSleeping: status.isSleeping,
      ),
    );
  }

  NowDisplayingSuccess? _buildLastSuccessStatus(FF1Device device) {
    final lastIdentity = _lastFullComputeIdentity;
    final lastItems = _lastFullSuccessPlaylistItems;
    final lastIndex = _lastFullSuccessIndex;
    final lastIsSleeping = _lastFullSuccessIsSleeping;
    final lastDeviceId = _lastFullSuccessDeviceId;
    if (lastIdentity == null ||
        lastItems == null ||
        lastIndex == null ||
        lastIsSleeping == null ||
        lastDeviceId == null ||
        lastDeviceId != device.deviceId ||
        lastIndex < 0 ||
        lastIndex >= lastItems.length) {
      return null;
    }

    return NowDisplayingSuccess(
      DP1NowDisplayingObject(
        connectedDevice: device,
        index: lastIndex,
        items: lastItems,
        isSleeping: lastIsSleeping,
      ),
    );
  }

  /// Fetches tokens for missing DP1 items from the indexer and persists only
  /// items with successful enrichment (token found) to the local cache.
  ///
  /// Only attempts enrichment for items not already in cache (cache-first
  /// contract). Items without CID or those not found by indexer are not cached;
  /// they remain as DP1 fallback in now-displaying but are not persisted to
  /// avoid stale data.
  ///
  /// On indexer failure, returns empty map; cached items are served normally,
  /// preserving offline-first contract. Does not invalidate cache to avoid
  /// infinite recompute loops.
  ///
  /// Returns a map of item id to enriched [PlaylistItem] for items successfully
  /// saved to cache.
  Future<Map<String, PlaylistItem>> _enrichMissingNowDisplayingItems(
    List<DP1PlaylistItem> missing,
  ) async {
    if (missing.isEmpty) return <String, PlaylistItem>{};

    final databaseService = ref.read(databaseServiceProvider);
    final indexerService = ref.read(indexerServiceProvider);

    final cids = databaseService.extractDP1ItemCids(missing);
    if (cids.isEmpty) return <String, PlaylistItem>{};

    try {
      final tokens = await indexerService.getManualTokens(tokenCids: cids);
      final toSave = buildEnrichedPlaylistItemsToSave(
        missingItems: missing,
        tokens: tokens,
      );
      if (toSave.isEmpty) return <String, PlaylistItem>{};

      await databaseService.upsertPlaylistItemsEnriched(
        toSave,
        shouldForce: false,
      );
      return {for (final p in toSave) p.id: p};
    } on Exception {
      // On indexer failure, return empty map; cache-first contract
      // ensures cached items are served from local state.
      return <String, PlaylistItem>{};
    }
  }
}

/// Base interface for now displaying states.
abstract class NowDisplayingStatus {
  /// Creates a now displaying status.
  const NowDisplayingStatus();
}

/// Initial state before any signal is received.
class InitialNowDisplayingStatus extends NowDisplayingStatus {
  /// Creates an initial now-displaying state.
  const InitialNowDisplayingStatus();
}

/// Loading state (waiting for device/player status data).
class LoadingNowDisplaying extends NowDisplayingStatus {
  /// Creates a loading now-displaying state.
  const LoadingNowDisplaying({
    this.device,
    this.playlistId,
  });

  /// Connected device, when known.
  final FF1Device? device;

  /// Playlist id, when known.
  final String? playlistId;
}

/// FF1 is connected and connecting to Wi-Fi/relayer is in progress.
class DeviceConnecting extends NowDisplayingStatus {
  /// Creates a connecting state.
  const DeviceConnecting(this.device);

  /// Connected device.
  final FF1Device device;
}

/// FF1 is paired but disconnected.
class DeviceDisconnected extends NowDisplayingStatus {
  /// Creates a disconnected state.
  const DeviceDisconnected(this.device);

  /// Connected device.
  final FF1Device device;
}

/// Successfully computed now-displaying state.
class NowDisplayingSuccess extends NowDisplayingStatus {
  /// Creates a success state.
  const NowDisplayingSuccess(this.object);

  /// Derived now-displaying object (DP-1-based today).
  final NowDisplayingObjectBase object;
}

/// Error state when now-displaying cannot be computed.
class NowDisplayingError extends NowDisplayingStatus {
  /// Creates an error state.
  const NowDisplayingError(this.error);

  /// Underlying error.
  final Object error;
}

/// No FF1 device is paired/active.
class NoDevicePaired extends NowDisplayingStatus {
  /// Creates a no-device-paired state.
  const NoDevicePaired();
}
