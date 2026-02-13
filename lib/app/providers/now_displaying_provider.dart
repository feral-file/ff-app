import 'dart:async';

import 'package:app/app/now_displaying/now_displaying_enrichment.dart';
import 'package:app/app/providers/ff1_bluetooth_device_providers.dart';
import 'package:app/app/providers/ff1_wifi_providers.dart';
import 'package:app/app/providers/indexer_provider.dart';
import 'package:app/domain/models/dp1/dp1_playlist_item.dart';
import 'package:app/domain/models/ff1_device.dart';
import 'package:app/domain/models/now_displaying_object.dart';
import 'package:app/domain/models/playlist_item.dart';
import 'package:app/infra/database/database_provider.dart';
import 'package:app/infra/ff1/wifi_protocol/ff1_wifi_messages.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Item IDs from current FF1 player status (for cache lookup).
final nowDisplayingItemIdsProvider = Provider<List<String>>((ref) {
  final status = ref.watch(ff1CurrentPlayerStatusProvider);
  final items = status?.items;
  if (items == null || items.isEmpty) return [];
  return items.map((e) => e.id).toList();
});

/// Cached [PlaylistItem]s for the current now-displaying item IDs.
/// Used to show enriched data (e.g. thumbnail, artists) when available locally.
final nowDisplayingCachedPlaylistItemsProvider =
    FutureProvider<List<PlaylistItem>>((ref) async {
      final ids = ref.watch(nowDisplayingItemIdsProvider);
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

class NowDisplayingNotifier extends Notifier<NowDisplayingStatus> {
  @override
  NowDisplayingStatus build() {
    // Trigger recompute whenever these sources change.
    //
    // Note: ff1CurrentPlayerStatusProvider and ff1DeviceConnectedProvider are
    // plain Providers over values stored inside FF1WifiControl. We listen to the
    // corresponding stream providers to ensure updates are observed.
    // Defer _recompute to next microtask so dependent providers (e.g.
    // ff1DeviceConnectedProvider) are rebuilt before we read them.
    ref.listen<AsyncValue<FF1Device?>>(
      activeFF1BluetoothDeviceProvider,
      (_, __) => unawaited(Future.microtask(_recompute)),
    );
    ref.listen<AsyncValue<FF1PlayerStatus>>(
      ff1PlayerStatusStreamProvider,
      (_, __) => unawaited(Future.microtask(_recompute)),
    );
    ref.listen<AsyncValue<FF1ConnectionStatus>>(
      ff1ConnectionStatusStreamProvider,
      (_, __) => unawaited(Future.microtask(_recompute)),
    );
    ref.listen<AsyncValue<List<PlaylistItem>>>(
      nowDisplayingCachedPlaylistItemsProvider,
      (_, __) => unawaited(Future.microtask(_recompute)),
    );

    // Match the previous manager contract: start at an explicit initial state,
    // then compute derived status on the next microtask.
    unawaited(Future<void>.microtask(_recompute));
    return const InitialNowDisplayingStatus();
  }

  void _recompute() {
    unawaited(
      Future.microtask(() async {
        final status = await _computeStatus();
        state = status;
      }),
    );
  }

  Future<NowDisplayingStatus> _computeStatus() async {
    final activeDevice = ref.read(activeFF1BluetoothDeviceProvider);
    return activeDevice.when(
      data: (device) =>
          _computeForDevice(device).then((value) => state = value),
      loading: () => const LoadingNowDisplaying(),
      error: (error, _) => NowDisplayingError(error),
    );
  }

  Future<NowDisplayingStatus> _computeForDevice(FF1Device? device) async {
    if (device == null) {
      return const NoDevicePaired();
    }

    final isConnected = ref.read(ff1DeviceConnectedProvider);
    if (!isConnected) {
      return DeviceDisconnected(device);
    }

    final status = ref.read(ff1CurrentPlayerStatusProvider);
    if (status == null) {
      return LoadingNowDisplaying(device: device);
    }

    // Explicit loading state when a playlist is selected but items are still
    // being fetched on the device side.
    if (status.playlistId != null && status.items == null) {
      return LoadingNowDisplaying(
        device: device,
        playlistId: status.playlistId,
      );
    }

    final items = status.items;
    final index = status.currentWorkIndex;
    if (items == null || items.isEmpty || index == null) {
      return NowDisplayingError(
        StateError('No items to display'),
      );
    }
    if (index < 0 || index >= items.length) {
      return NowDisplayingError(
        RangeError.index(index, items, 'currentWorkIndex'),
      );
    }

    // Use cached PlaylistItems when available; otherwise fall back to device payload.
    final cachedAsync = ref.read(nowDisplayingCachedPlaylistItemsProvider);
    final cachedById = <String, PlaylistItem>{};
    if (cachedAsync.hasValue && cachedAsync.value != null) {
      for (final p in cachedAsync.value!) {
        cachedById[p.id] = p;
      }
    }

    // Trigger background enrichment for items not yet in cache.
    final missing = items
        .where((dp1) => !cachedById.containsKey(dp1.id))
        .toList();
    final enriched = missing.isNotEmpty
        ? await _enrichMissingNowDisplayingItems(missing)
        : <String, PlaylistItem>{};

    final playlistItems = [
      for (var i = 0; i < items.length; i++)
        enriched[items[i].id] ??
            cachedById[items[i].id] ??
            PlaylistItem(
              id: items[i].id,
              kind: PlaylistItemKind.dp1Item,
              title: items[i].title,
              duration: items[i].duration,
            ),
    ];

    return NowDisplayingSuccess(
      DP1NowDisplayingObject(
        connectedDevice: device,
        index: index,
        items: playlistItems,
        isSleeping: status.isPaused,
      ),
    );
  }

  /// Fetches tokens for missing DP1 items from the indexer, builds enriched
  /// [PlaylistItem]s (only for items that have a token), and persists them.
  /// Does not invalidate the cache to avoid an infinite recompute loop.
  /// Returns a map of item id to enriched [PlaylistItem] for the saved items.
  Future<Map<String, PlaylistItem>> _enrichMissingNowDisplayingItems(
    List<DP1PlaylistItem> missing,
  ) async {
    final databaseService = ref.read(databaseServiceProvider);
    final indexerService = ref.read(indexerServiceProvider);

    final cids = databaseService.extractDP1ItemCids(missing);
    if (cids.isEmpty) return <String, PlaylistItem>{};

    final tokens = await indexerService.fetchTokensByCIDs(tokenCids: cids);
    final toSave = buildEnrichedPlaylistItemsToSave(
      missingItems: missing,
      tokens: tokens,
    );
    if (toSave.isEmpty) return <String, PlaylistItem>{};

    await databaseService.upsertPlaylistItemsEnriched(toSave);
    return {for (final p in toSave) p.id: p};
  }
}

/// Base interface for now displaying states.
abstract class NowDisplayingStatus {
  const NowDisplayingStatus();
}

/// Initial state before any signal is received.
class InitialNowDisplayingStatus extends NowDisplayingStatus {
  const InitialNowDisplayingStatus();
}

/// Loading state (waiting for device/player status data).
class LoadingNowDisplaying extends NowDisplayingStatus {
  const LoadingNowDisplaying({
    this.device,
    this.playlistId,
  });

  final FF1Device? device;
  final String? playlistId;
}

class DeviceDisconnected extends NowDisplayingStatus {
  const DeviceDisconnected(this.device);

  final FF1Device device;
}

class NowDisplayingSuccess extends NowDisplayingStatus {
  const NowDisplayingSuccess(this.object);

  final NowDisplayingObjectBase object;
}

class NowDisplayingError extends NowDisplayingStatus {
  const NowDisplayingError(this.error);

  final Object error;
}

class NoDevicePaired extends NowDisplayingStatus {
  const NoDevicePaired();
}
