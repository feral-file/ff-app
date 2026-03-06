import 'package:app/app/providers/ff1_ble_lifecycle_policy.dart';
import 'package:app/app/providers/ff1_bluetooth_device_providers.dart';
import 'package:app/app/providers/ff1_providers.dart';
import 'package:app/domain/models/ff1_device.dart';
import 'package:app/infra/ff1/ble_transport/ff1_ble_transport.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:synchronized/synchronized.dart';

class FF1BleLifecycleState {
  const FF1BleLifecycleState({
    required this.lifecycleState,
    required this.routePath,
    required this.isConnected,
    this.connectedRemoteId,
  });

  final AppLifecycleState lifecycleState;
  final String routePath;
  final bool isConnected;
  final String? connectedRemoteId;

  FF1BleLifecycleState copyWith({
    AppLifecycleState? lifecycleState,
    String? routePath,
    bool? isConnected,
    Object? connectedRemoteId = _keepRemoteId,
  }) {
    return FF1BleLifecycleState(
      lifecycleState: lifecycleState ?? this.lifecycleState,
      routePath: routePath ?? this.routePath,
      isConnected: isConnected ?? this.isConnected,
      connectedRemoteId: connectedRemoteId == _keepRemoteId
          ? this.connectedRemoteId
          : connectedRemoteId as String?,
    );
  }
}

const Object _keepRemoteId = Object();

class FF1BleLifecycleCoordinator extends Notifier<FF1BleLifecycleState> {
  late final Logger _log;
  final Lock _lock = Lock();

  @override
  FF1BleLifecycleState build() {
    _log = Logger('FF1BleLifecycleCoordinator');
    return const FF1BleLifecycleState(
      lifecycleState: AppLifecycleState.resumed,
      routePath: '',
      isConnected: false,
      connectedRemoteId: null,
    );
  }

  Future<void> handleRouteChanged(String routePath) async {
    state = state.copyWith(routePath: routePath);

    if (!shouldCloseBleForRoute(routePath)) {
      return;
    }

    await _disconnectAll('route changed to home');
  }

  Future<void> handleLifecycleChanged(
    AppLifecycleState lifecycleState, {
    required String routePath,
  }) async {
    state = state.copyWith(
      lifecycleState: lifecycleState,
      routePath: routePath,
    );

    if (isBackgroundLifecycleState(lifecycleState)) {
      await _disconnectAll('app moved to background');
      return;
    }

    if (!shouldReconnectBleOnLifecycle(
      state: lifecycleState,
      routePath: routePath,
    )) {
      return;
    }

    await _reconnectActiveDevice();
  }

  Future<void> _reconnectActiveDevice() async {
    await _lock.synchronized(() async {
      final transport = ref.read(ff1TransportProvider);
      if (transport.adapterState != BluetoothAdapterState.on) {
        _log.info('Bluetooth adapter is not on, skip reconnect');
        return;
      }

      final activeDevice = await _readActiveDevice();
      if (activeDevice == null) {
        _log.info('No active FF1 device, skip reconnect');
        return;
      }

      final resolved = await _resolveBluetoothDevice(activeDevice, transport);
      if (resolved == null) {
        _log.warning('Unable to resolve active FF1 Bluetooth device');
        return;
      }

      final remoteId = resolved.remoteId.str;
      if (state.isConnected && state.connectedRemoteId == remoteId) {
        return;
      }

      await transport.connect(
        blDevice: resolved,
        timeout: const Duration(seconds: 20),
        maxRetries: 0,
      );

      _log.info('Reconnected BLE device: $remoteId');
      state = state.copyWith(
        isConnected: true,
        connectedRemoteId: remoteId,
      );
    });
  }

  Future<void> _disconnectAll(String reason) async {
    await _lock.synchronized(() async {
      final transport = ref.read(ff1TransportProvider);
      await transport.disconnectAll();
      _log.info('Closed BLE session: $reason');

      state = state.copyWith(
        isConnected: false,
        connectedRemoteId: null,
      );
    });
  }

  Future<FF1Device?> _readActiveDevice() async {
    final service = ref.read(ff1BluetoothDeviceServiceProvider);
    return service.getActiveDevice();
  }

  Future<BluetoothDevice?> _resolveBluetoothDevice(
    FF1Device device,
    FF1BleTransport transport,
  ) async {
    if (device.remoteId.isNotEmpty) {
      return device.toBluetoothDevice();
    }

    return transport.scanForName(
      name: device.name,
      timeout: const Duration(seconds: 8),
    );
  }
}

final ff1BleLifecycleCoordinatorProvider =
    NotifierProvider<FF1BleLifecycleCoordinator, FF1BleLifecycleState>(
      FF1BleLifecycleCoordinator.new,
    );
