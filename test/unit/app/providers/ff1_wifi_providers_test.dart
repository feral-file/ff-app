import 'dart:async';

import 'package:app/app/providers/ff1_bluetooth_device_providers.dart';
import 'package:app/app/providers/ff1_wifi_providers.dart';
import 'package:app/domain/models/ff1_device.dart';
import 'package:app/infra/ff1/wifi_control/ff1_wifi_control.dart';
import 'package:app/infra/ff1/wifi_protocol/ff1_wifi_messages.dart';
import 'package:app/infra/ff1/wifi_transport/ff1_wifi_transport.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'provider_test_helpers.dart';

void main() {
  test('ff1 wifi params equality and default notifier state', () {
    // Unit test: verifies FF1 WiFi connect params equality and initial
    // connection state.
    const p1 = FF1WifiConnectParams(
      device: FF1Device(
        name: 'D',
        remoteId: 'r',
        deviceId: 'id',
        topicId: 'topic',
      ),
      userId: 'u1',
      apiKey: 'k1',
    );
    const p2 = FF1WifiConnectParams(
      device: FF1Device(
        name: 'D',
        remoteId: 'r',
        deviceId: 'id',
        topicId: 'topic',
      ),
      userId: 'u1',
      apiKey: 'k2',
    );
    expect(p1, p2);

    final container = ProviderContainer.test(
      overrides: [
        ff1WifiControlProvider.overrideWithValue(FakeWifiControl()),
      ],
    );
    addTearDown(container.dispose);
    expect(container.read(ff1WifiConnectionProvider).isConnected, isFalse);
  });

  test(
    'ff1AutoConnectWatcherProvider connects when active device is set',
    () async {
      // Unit test: verifies auto-connect watcher triggers connection
      // when active device changes.
      await ensureDotEnvLoaded();

      final deviceService = MockFF1BluetoothDeviceService();
      final wifiControl = FakeWifiControl();
      const device = FF1Device(
        name: 'FF1',
        remoteId: 'remote-1',
        deviceId: 'device-1',
        topicId: 'topic-1',
      );

      final container = ProviderContainer.test(
        overrides: [
          ff1BluetoothDeviceServiceProvider.overrideWithValue(deviceService),
          ff1WifiControlProvider.overrideWithValue(wifiControl),
          ff1WifiConnectionProvider.overrideWith(
            FF1WifiConnectionNotifier.new,
          ),
        ],
      );
      addTearDown(container.dispose);

      // Initially no active device
      deviceService
        ..devices = []
        ..activeDeviceId = null;

      // Watch the auto-connect provider to keep it alive
      container.listen(
        ff1AutoConnectWatcherProvider,
        (previous, next) {},
      );

      // Wait for initial state
      await container.read(activeFF1BluetoothDeviceProvider.future);

      // Verify no connection attempt yet
      expect(wifiControl.connectCalled, isFalse);

      // Set active device
      deviceService
        ..devices = [device]
        ..activeDeviceId = device.deviceId;
      container.invalidate(activeFF1BluetoothDeviceProvider);

      // Wait for active device to update
      await container.read(activeFF1BluetoothDeviceProvider.future);

      // Small delay to allow async connection to trigger
      await Future<void>.delayed(const Duration(milliseconds: 200));

      // Verify connection was attempted
      expect(wifiControl.connectCalled, isTrue);
      expect(wifiControl.lastConnectedDevice?.deviceId, device.deviceId);
    },
  );

  test(
    'ff1AutoConnectWatcherProvider disconnects when active device is removed',
    () async {
      // Unit test: verifies auto-connect watcher triggers disconnection
      // when active device is removed.
      await ensureDotEnvLoaded();

      final deviceService = MockFF1BluetoothDeviceService();
      final wifiControl = FakeWifiControl();
      const device = FF1Device(
        name: 'FF1',
        remoteId: 'remote-1',
        deviceId: 'device-1',
        topicId: 'topic-1',
      );

      final container = ProviderContainer.test(
        overrides: [
          ff1BluetoothDeviceServiceProvider.overrideWithValue(deviceService),
          ff1WifiControlProvider.overrideWithValue(wifiControl),
          ff1WifiConnectionProvider.overrideWith(
            FF1WifiConnectionNotifier.new,
          ),
        ],
      );
      addTearDown(container.dispose);

      // Start with active device
      deviceService
        ..devices = [device]
        ..activeDeviceId = device.deviceId;

      // Watch the auto-connect provider to keep it alive
      container.listen(
        ff1AutoConnectWatcherProvider,
        (previous, next) {},
      );

      // Wait for initial connection
      await container.read(activeFF1BluetoothDeviceProvider.future);
      await Future<void>.delayed(const Duration(milliseconds: 200));

      expect(wifiControl.connectCalled, isTrue);

      // Remove active device
      deviceService.activeDeviceId = null;
      container.invalidate(activeFF1BluetoothDeviceProvider);

      // Wait for active device to update
      await container.read(activeFF1BluetoothDeviceProvider.future);
      await Future<void>.delayed(const Duration(milliseconds: 200));

      // Verify disconnection was attempted
      expect(wifiControl.disconnectCalled, isTrue);
    },
  );

  test(
    'ff1AutoConnectWatcherProvider clears stale realtime state before '
    'connecting to a new device',
    () async {
      await ensureDotEnvLoaded();

      final deviceService = MockFF1BluetoothDeviceService();
      final transport = _InspectableWifiTransport();
      final wifiControl = _InspectableWifiControl(
        transport: transport,
        switchDeviceId: 'device-2',
      );
      const device1 = FF1Device(
        name: 'FF1-A',
        remoteId: 'remote-1',
        deviceId: 'device-1',
        topicId: 'topic-1',
      );
      const device2 = FF1Device(
        name: 'FF1-B',
        remoteId: 'remote-2',
        deviceId: 'device-2',
        topicId: 'topic-2',
      );

      final container = ProviderContainer.test(
        overrides: [
          ff1BluetoothDeviceServiceProvider.overrideWithValue(deviceService),
          ff1WifiControlProvider.overrideWithValue(wifiControl),
          ff1WifiConnectionProvider.overrideWith(
            FF1WifiConnectionNotifier.new,
          ),
        ],
      );
      addTearDown(container.dispose);

      deviceService
        ..devices = [device1, device2]
        ..activeDeviceId = device1.deviceId;

      container.listen(
        ff1AutoConnectWatcherProvider,
        (previous, next) {},
      );

      await container.read(activeFF1BluetoothDeviceProvider.future);
      await Future<void>.delayed(const Duration(milliseconds: 200));

      transport
        ..emitNotification(_connectionNotification(isConnected: true))
        ..emitNotification(
          _deviceStatusNotification(
            installedVersion: '1.0.0',
            latestVersion: '2.0.0',
          ),
        )
        ..emitNotification(
          _playerStatusNotification(playlistId: 'playlist-a'),
        );
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(wifiControl.currentDeviceStatus, isNotNull);
      expect(wifiControl.currentPlayerStatus, isNotNull);
      expect(wifiControl.isDeviceConnected, isTrue);

      deviceService.activeDeviceId = device2.deviceId;
      container.invalidate(activeFF1BluetoothDeviceProvider);

      await container.read(activeFF1BluetoothDeviceProvider.future);
      await Future<void>.delayed(const Duration(milliseconds: 200));

      expect(wifiControl.switchConnectDeviceStatus, isNull);
      expect(wifiControl.switchConnectPlayerStatus, isNull);
      expect(wifiControl.switchConnectIsDeviceConnected, isFalse);
      expect(wifiControl.lastConnectedDevice?.deviceId, device2.deviceId);
    },
  );
}

FF1NotificationMessage _connectionNotification({required bool isConnected}) {
  return FF1NotificationMessage(
    type: FF1WifiMessageType.notification,
    message: {'isConnected': isConnected},
    notificationType: FF1NotificationType.connection,
    timestamp: DateTime.fromMillisecondsSinceEpoch(0),
  );
}

FF1NotificationMessage _deviceStatusNotification({
  required String installedVersion,
  required String latestVersion,
}) {
  return FF1NotificationMessage(
    type: FF1WifiMessageType.notification,
    message: {
      'installedVersion': installedVersion,
      'latestVersion': latestVersion,
    },
    notificationType: FF1NotificationType.deviceStatus,
    timestamp: DateTime.fromMillisecondsSinceEpoch(0),
  );
}

FF1NotificationMessage _playerStatusNotification({
  required String playlistId,
}) {
  return FF1NotificationMessage(
    type: FF1WifiMessageType.notification,
    message: {'playlistId': playlistId},
    notificationType: FF1NotificationType.playerStatus,
    timestamp: DateTime.fromMillisecondsSinceEpoch(0),
  );
}

class _InspectableWifiTransport implements FF1WifiTransport {
  _InspectableWifiTransport()
      : _notifications = StreamController<FF1NotificationMessage>.broadcast(),
        _connections = StreamController<bool>.broadcast(),
        _errors = StreamController<FF1WifiTransportError>.broadcast();

  final StreamController<FF1NotificationMessage> _notifications;
  final StreamController<bool> _connections;
  final StreamController<FF1WifiTransportError> _errors;

  bool _isConnected = false;

  void emitNotification(FF1NotificationMessage message) {
    _notifications.add(message);
  }

  @override
  Stream<bool> get connectionStateStream => _connections.stream;

  @override
  Stream<FF1NotificationMessage> get notificationStream =>
      _notifications.stream;

  @override
  Stream<FF1WifiTransportError> get errorStream => _errors.stream;

  @override
  bool get isConnected => _isConnected;

  @override
  bool get isConnecting => false;

  @override
  Future<void> connect({
    required FF1Device device,
    required String userId,
    required String apiKey,
    bool forceReconnect = false,
  }) async {
    _isConnected = true;
    _connections.add(true);
  }

  @override
  void pauseConnection() {}

  @override
  Future<void> disconnect() async {
    _isConnected = false;
    _connections.add(false);
  }

  @override
  Future<void> sendCommand(Map<String, dynamic> command) async {}

  @override
  void dispose() {
    unawaited(_notifications.close());
    unawaited(_connections.close());
    unawaited(_errors.close());
  }

  @override
  Future<void> disposeFuture() async {
    dispose();
  }
}

class _InspectableWifiControl extends FF1WifiControl {
  _InspectableWifiControl({
    required super.transport,
    required this.switchDeviceId,
  });

  final String switchDeviceId;
  FF1DeviceStatus? switchConnectDeviceStatus;
  FF1PlayerStatus? switchConnectPlayerStatus;
  bool? switchConnectIsDeviceConnected;
  FF1Device? lastConnectedDevice;

  @override
  Future<void> connect({
    required FF1Device device,
    required String userId,
    required String apiKey,
  }) async {
    lastConnectedDevice = device;
    if (device.deviceId == switchDeviceId) {
      switchConnectDeviceStatus = currentDeviceStatus;
      switchConnectPlayerStatus = currentPlayerStatus;
      switchConnectIsDeviceConnected = isDeviceConnected;
    }
    await super.connect(device: device, userId: userId, apiKey: apiKey);
  }
}
