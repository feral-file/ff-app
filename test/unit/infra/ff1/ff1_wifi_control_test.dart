import 'dart:async';

import 'package:app/domain/models/ff1/ffp_ddc_panel_status.dart';
import 'package:app/domain/models/ff1_device.dart';
import 'package:app/infra/ff1/wifi_control/ff1_wifi_control.dart';
import 'package:app/infra/ff1/wifi_protocol/ff1_wifi_messages.dart';
import 'package:app/infra/ff1/wifi_transport/ff1_wifi_transport.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FF1WifiControl notifications', () {
    test('publishes relayer-pushed FFP panel status updates', () async {
      final transport = _NotificationTestTransport();
      final control = FF1WifiControl(transport: transport);

      addTearDown(control.dispose);

      final nextStatus = control.ffpDdcPanelStatusStream.first;
      transport.emitNotification(
        FF1NotificationMessage(
          type: FF1WifiMessageType.notification,
          notificationType: FF1NotificationType.ffpDdcPanelStatus,
          message: const {
            'monitor': 'Studio Display',
            'brightness': 64,
            'power': 'on',
          },
          timestamp: DateTime.fromMillisecondsSinceEpoch(1704067200000),
        ),
      );

      final status = await nextStatus;

      expect(status.monitor, 'Studio Display');
      expect(status.brightness, 64);
      expect(status.power, 'on');
      expect(control.currentFfpDdcPanelStatus?.brightness, 64);
    });

    test('publishes FFP panel status for notification_type default (relayer)',
        () async {
      final transport = _NotificationTestTransport();
      final control = FF1WifiControl(transport: transport);

      addTearDown(control.dispose);

      final nextStatus = control.ffpDdcPanelStatusStream.first;
      transport.emitNotification(
        FF1NotificationMessage(
          type: FF1WifiMessageType.notification,
          notificationType: FF1NotificationType.ffpStatusDefault,
          message: const {
            'brightness': 82,
            'contrast': 25,
            'volume': 77,
            'power': 'on',
            'monitor': 'DEL:DELL S2721QS',
            'errors': {'mute': 'VCP reported ERR'},
          },
          timestamp: DateTime.fromMillisecondsSinceEpoch(1775038389754),
        ),
      );

      final status = await nextStatus;

      expect(status.brightness, 82);
      expect(status.errors?['mute'], 'VCP reported ERR');
      expect(control.currentFfpDdcPanelStatus?.monitor, 'DEL:DELL S2721QS');
    });

    test(
      'clears cached device and panel status when switching devices',
      () async {
        final transport = _NotificationTestTransport();
        final control = FF1WifiControl(transport: transport);
        const deviceA = FF1Device(
          name: 'FF1 A',
          remoteId: 'remote-a',
          deviceId: 'device-a',
          topicId: 'topic-a',
        );
        const deviceB = FF1Device(
          name: 'FF1 B',
          remoteId: 'remote-b',
          deviceId: 'device-b',
          topicId: 'topic-b',
        );
        final deviceStatuses = <FF1DeviceStatus>[];
        final panelStatuses = <FfpDdcPanelStatus>[];

        addTearDown(control.dispose);

        final deviceStatusSub = control.deviceStatusStream.listen(
          deviceStatuses.add,
        );
        final panelStatusSub = control.ffpDdcPanelStatusStream.listen(
          panelStatuses.add,
        );
        addTearDown(deviceStatusSub.cancel);
        addTearDown(panelStatusSub.cancel);

        await control.connect(
          device: deviceA,
          userId: 'user',
          apiKey: 'key',
        );
        transport.emitNotification(
          FF1NotificationMessage(
            type: FF1WifiMessageType.notification,
            notificationType: FF1NotificationType.deviceStatus,
            message: const {
              'volume': 40,
              'isMuted': true,
            },
            timestamp: DateTime.fromMillisecondsSinceEpoch(1704067200000),
          ),
        );
        transport.emitNotification(
          FF1NotificationMessage(
            type: FF1WifiMessageType.notification,
            notificationType: FF1NotificationType.ffpDdcPanelStatus,
            message: const {
              'brightness': 20,
              'monitor': 'Studio Display',
            },
            timestamp: DateTime.fromMillisecondsSinceEpoch(1704067200000),
          ),
        );
        await Future<void>.delayed(Duration.zero);

        expect(control.currentDeviceStatus?.volume, 40);
        expect(control.currentFfpDdcPanelStatus?.brightness, 20);

        await control.connect(
          device: deviceB,
          userId: 'user',
          apiKey: 'key',
        );
        await Future<void>.delayed(Duration.zero);

        expect(control.currentDeviceStatus, isNull);
        expect(control.currentFfpDdcPanelStatus, isNull);
        expect(deviceStatuses.last.volume, isNull);
        expect(panelStatuses.last.hasData, isFalse);
      },
    );

    test(
      'clears replayed FFP panel status after transport disconnect',
      () async {
        final transport = _NotificationTestTransport();
        final control = FF1WifiControl(transport: transport);

        addTearDown(control.dispose);

        transport.emitNotification(
          FF1NotificationMessage(
            type: FF1WifiMessageType.notification,
            notificationType: FF1NotificationType.ffpDdcPanelStatus,
            message: const {
              'monitor': 'Studio Display',
              'brightness': 64,
              'power': 'on',
            },
            timestamp: DateTime.fromMillisecondsSinceEpoch(1704067200000),
          ),
        );
        await Future<void>.delayed(Duration.zero);

        transport.emitConnectionState(false);
        await Future<void>.delayed(Duration.zero);

        final clearedStatus = await control.ffpDdcPanelStatusStream.first;

        expect(control.currentFfpDdcPanelStatus, isNull);
        expect(clearedStatus.hasData, isFalse);
      },
    );
  });

  group('FF1WifiControl.getDeviceRealtimeMetrics', () {
    test(
      'uses default 6 second timeout for realtime metrics request',
      () async {
        final restClient = _RecordingRestClient();
        final control = FF1WifiControl(
          transport: _FakeWifiTransport(),
          restClient: restClient,
        );

        addTearDown(control.dispose);

        await control.getDeviceRealtimeMetrics(topicId: 'topic_1');

        expect(restClient.lastTopicId, 'topic_1');
        expect(restClient.lastCommand, 'deviceMetrics');
        expect(restClient.lastTimeout, const Duration(seconds: 6));
      },
    );

    test('rethrows TimeoutException from metrics request', () async {
      final control = FF1WifiControl(
        transport: _FakeWifiTransport(),
        restClient: _TimeoutRestClient(),
      );

      addTearDown(control.dispose);

      await expectLater(
        () => control.getDeviceRealtimeMetrics(topicId: 'topic_1'),
        throwsA(isA<TimeoutException>()),
      );
    });
  });

  group('FF1WifiControl.dispose', () {
    test(
      'await subscription cancel before closing subjects (delayed transport '
      'connection false emit)',
      () async {
        final transport = _DelayedConnectionFalseAfterDisconnectTransport();
        final control = FF1WifiControl(
          transport: transport,
        );
        control.dispose();
        await Future<void>.delayed(const Duration(milliseconds: 200));
      },
    );

    test(
      'transport emitting delayed connectionState during dispose does not add after close',
      () async {
        final transport = _DelayedConnectionFalseAfterDisconnectTransport();
        final control = FF1WifiControl(
          transport: transport,
        );

        // Start dispose (this cancels subscriptions)
        control.dispose();

        // Wait for subscriptions to cancel but transport still has 100ms delay
        await Future<void>.delayed(const Duration(milliseconds: 50));

        // Trigger transport disconnect (which delays 100ms before emitting)
        await transport.disconnect();

        // Wait for delayed emit to occur
        await Future<void>.delayed(const Duration(milliseconds: 100));

        // Verify that no exception was thrown (connection state add after close)
        // This test passes if we reach here without an error
      },
    );

    test(
      'transport dispose is awaited before control teardown completes',
      () async {
        var transportDisposeCalled = false;
        final transport = _CustomDisposeTransport(
          onDispose: () {
            transportDisposeCalled = true;
          },
        );
        final control = FF1WifiControl(
          transport: transport,
        );

        // Start dispose
        control.dispose();

        // Wait for async dispose to complete
        await Future<void>.delayed(const Duration(milliseconds: 200));

        // Verify transport.dispose() was called
        expect(transportDisposeCalled, isTrue);
      },
    );
  });
}

class _RecordingRestClient {
  String? lastTopicId;
  String? lastCommand;
  Duration? lastTimeout;

  Future<Map<String, dynamic>> sendCommand({
    required String topicId,
    required String command,
    required Map<String, dynamic> params,
    Duration timeout = const Duration(seconds: 6),
  }) async {
    lastTopicId = topicId;
    lastCommand = command;
    lastTimeout = timeout;

    return <String, dynamic>{
      'data': <String, dynamic>{
        'temperature': 30,
        'fan_speed': 1200,
        'memory_usage': 45,
      },
    };
  }
}

class _TimeoutRestClient {
  Future<Map<String, dynamic>> sendCommand({
    required String topicId,
    required String command,
    required Map<String, dynamic> params,
    Duration timeout = const Duration(seconds: 6),
  }) async {
    throw TimeoutException('Future not completed');
  }
}

/// Mirrors relayer [disconnect] delaying then emitting on
/// [connectionStateStream].
class _DelayedConnectionFalseAfterDisconnectTransport
    implements FF1WifiTransport {
  final _notifications = StreamController<FF1NotificationMessage>.broadcast();
  final _connections = StreamController<bool>.broadcast();
  final _errors = StreamController<FF1WifiTransportError>.broadcast();

  @override
  Stream<bool> get connectionStateStream => _connections.stream;

  @override
  Stream<FF1NotificationMessage> get notificationStream =>
      _notifications.stream;

  @override
  Stream<FF1WifiTransportError> get errorStream => _errors.stream;

  @override
  bool get isConnected => false;

  @override
  bool get isConnecting => false;

  @override
  Future<void> connect({
    required FF1Device device,
    required String userId,
    required String apiKey,
    bool forceReconnect = false,
  }) async {}

  @override
  void pauseConnection() {}

  @override
  Future<void> disconnect() async {
    await Future<void>.delayed(const Duration(milliseconds: 100));
    if (!_connections.isClosed) {
      _connections.add(false);
    }
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

class _FakeWifiTransport implements FF1WifiTransport {
  @override
  Stream<bool> get connectionStateStream => const Stream.empty();

  @override
  Stream<FF1WifiTransportError> get errorStream => const Stream.empty();

  @override
  bool get isConnected => false;

  @override
  bool get isConnecting => false;

  @override
  Stream<FF1NotificationMessage> get notificationStream => const Stream.empty();

  @override
  Future<void> connect({
    required FF1Device device,
    required String userId,
    required String apiKey,
    bool forceReconnect = false,
  }) async {}

  @override
  void pauseConnection() {}

  @override
  Future<void> disconnect() async {}

  @override
  Future<void> sendCommand(Map<String, dynamic> command) async {}

  @override
  void dispose() {}

  @override
  Future<void> disposeFuture() async {
    dispose();
  }
}

class _NotificationTestTransport implements FF1WifiTransport {
  final _notifications = StreamController<FF1NotificationMessage>.broadcast();
  final _connections = StreamController<bool>.broadcast();

  void emitNotification(FF1NotificationMessage message) {
    _notifications.add(message);
  }

  void emitConnectionState(bool connected) {
    _connections.add(connected);
  }

  @override
  Stream<bool> get connectionStateStream => _connections.stream;

  @override
  Stream<FF1WifiTransportError> get errorStream => const Stream.empty();

  @override
  bool get isConnected => true;

  @override
  bool get isConnecting => false;

  @override
  Stream<FF1NotificationMessage> get notificationStream =>
      _notifications.stream;

  @override
  Future<void> connect({
    required FF1Device device,
    required String userId,
    required String apiKey,
    bool forceReconnect = false,
  }) async {}

  @override
  void pauseConnection() {}

  @override
  Future<void> disconnect() async {}

  @override
  Future<void> sendCommand(Map<String, dynamic> command) async {}

  @override
  void dispose() {
    unawaited(_notifications.close());
    unawaited(_connections.close());
  }

  @override
  Future<void> disposeFuture() async {
    await Future.wait<void>([
      _notifications.close(),
      _connections.close(),
    ]);
  }
}

class _CustomDisposeTransport implements FF1WifiTransport {
  _CustomDisposeTransport({required this.onDispose});

  final VoidCallback onDispose;

  @override
  Stream<bool> get connectionStateStream => const Stream.empty();

  @override
  Stream<FF1WifiTransportError> get errorStream => const Stream.empty();

  @override
  bool get isConnected => false;

  @override
  bool get isConnecting => false;

  @override
  Stream<FF1NotificationMessage> get notificationStream => const Stream.empty();

  @override
  Future<void> connect({
    required FF1Device device,
    required String userId,
    required String apiKey,
    bool forceReconnect = false,
  }) async {}

  @override
  void pauseConnection() {}

  @override
  Future<void> disconnect() async {}

  @override
  Future<void> sendCommand(Map<String, dynamic> command) async {}

  @override
  void dispose() {
    onDispose();
  }

  @override
  Future<void> disposeFuture() async {
    dispose();
  }
}
