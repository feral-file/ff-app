import 'dart:async';

import 'package:app/app/providers/ff1_bluetooth_device_providers.dart';
import 'package:app/app/providers/ff1_wifi_providers.dart';
import 'package:app/domain/models/ff1_device.dart';
import 'package:app/domain/models/now_displaying_object.dart';
import 'package:app/domain/models/playlist_item.dart';
import 'package:app/infra/ff1/wifi_protocol/ff1_wifi_messages.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

    // Match the previous manager contract: start at an explicit initial state,
    // then compute derived status on the next microtask.
    unawaited(Future<void>.microtask(_recompute));
    return const InitialNowDisplayingStatus();
  }

  void _recompute() {
    state = _computeStatus();
  }

  NowDisplayingStatus _computeStatus() {
    final activeDevice = ref.read(activeFF1BluetoothDeviceProvider);
    return activeDevice.when(
      data: (device) => _computeForDevice(device),
      loading: () => const LoadingNowDisplaying(),
      error: (error, _) => NowDisplayingError(error),
    );
  }

  NowDisplayingStatus _computeForDevice(FF1Device? device) {
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

    final playlistItems = items
        .map(
          (e) => PlaylistItem(
            id: e.id,
            kind: PlaylistItemKind.dp1Item,
            title: e.title,
            duration: e.duration,
          ),
        )
        .toList(growable: false);

    return NowDisplayingSuccess(
      DP1NowDisplayingObject(
        connectedDevice: device,
        index: index,
        items: playlistItems,
        isSleeping: status.isPaused,
      ),
    );
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

