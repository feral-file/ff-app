import 'package:app/app/providers/ff1_bluetooth_device_providers.dart';
import 'package:app/app/providers/ff1_wifi_providers.dart';
import 'package:app/domain/models/ff1/canvas_cast_request_reply.dart';
import 'package:app/infra/ff1/wifi_protocol/ff1_wifi_messages.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';

final Logger _log = Logger('FF1DeviceProvider');

/// FF1 Device Data Provider
///
/// Combines device status, player status, and connection state
/// into a single provider for UI consumption.
class FF1DeviceData {
  /// Creates a FF1 Device Data.
  const FF1DeviceData({
    required this.deviceStatus,
    required this.playerStatus,
    required this.isConnected,
  });

  /// Device status.
  final FF1DeviceStatus? deviceStatus;

  /// Player status.
  final FF1PlayerStatus? playerStatus;

  /// Whether device is connected.
  final bool isConnected;
}

/// Polls a relayer-backed value without tearing down the stream on one bad
/// read.
///
/// FF1 control fetches are best-effort and transient failures are common while
/// the app/background state or transport is settling. Swallowing a single
/// failed read here keeps the previous UI state visible and lets the next poll
/// recover without forcing the whole subtree to resubscribe.
Stream<T> pollWithRecovery<T>({
  required Future<T> Function() load,
  required Duration interval,
  void Function(Object error, StackTrace stackTrace)? onError,
}) async* {
  while (true) {
    try {
      yield await load();
    } on Object catch (error, stackTrace) {
      onError?.call(error, stackTrace);
    }
    await Future<void>.delayed(interval);
  }
}

/// FF1 Device Data Provider.
///
/// Combines [ff1CurrentPlayerStatusProvider], [ff1CurrentDeviceStatusProvider]
/// and [ff1DeviceConnectedProvider] into a single, synchronous value for UI.
final Provider<FF1DeviceData> ff1DeviceDataProvider = Provider<FF1DeviceData>(
  (ref) {
    final playerStatus = ref.watch(ff1CurrentPlayerStatusProvider);
    final deviceStatus = ref.watch(ff1CurrentDeviceStatusProvider);
    final isConnected = ref.watch(ff1DeviceConnectedProvider);

    return FF1DeviceData(
      deviceStatus: deviceStatus,
      playerStatus: playerStatus,
      isConnected: isConnected,
    );
  },
);

/// Polls realtime metrics for an active topic while connected and awake.
// ignore: specify_nonobvious_property_types
final ff1DeviceRealtimeMetricsStreamProvider = StreamProvider.autoDispose
    .family<DeviceRealtimeMetrics, String>((
      ref,
      topicId,
    ) {
      if (topicId.isEmpty) {
        return const Stream<DeviceRealtimeMetrics>.empty();
      }

      final isConnected = ref.watch(ff1DeviceConnectedProvider);
      final isSleeping = ref.watch(
        ff1CurrentPlayerStatusProvider.select((s) => s?.isSleeping ?? false),
      );
      if (!isConnected || isSleeping) {
        return const Stream<DeviceRealtimeMetrics>.empty();
      }

      final control = ref.watch(ff1WifiControlProvider);
      return pollWithRecovery<DeviceRealtimeMetrics>(
        load: () => control.getDeviceRealtimeMetrics(topicId: topicId),
        interval: const Duration(seconds: 5),
        onError: (error, stackTrace) {
          _log.warning(
            'Device realtime metrics poll failed for topic $topicId',
            error,
            stackTrace,
          );
        },
      );
    });

/// Latest realtime metrics for the current active device.
final ff1LatestDeviceRealtimeMetricsProvider = Provider<DeviceRealtimeMetrics?>(
  (ref) {
    final activeDeviceAsync = ref.watch(activeFF1BluetoothDeviceProvider);
    final topicId = activeDeviceAsync.maybeWhen(
      data: (device) => device?.topicId ?? '',
      orElse: () => '',
    );
    if (topicId.isEmpty) {
      return null;
    }

    final metricsAsync = ref.watch(
      ff1DeviceRealtimeMetricsStreamProvider(topicId),
    );
    return metricsAsync.when(
      data: (metrics) => metrics,
      loading: () => null,
      error: (_, _) => null,
    );
  },
);
