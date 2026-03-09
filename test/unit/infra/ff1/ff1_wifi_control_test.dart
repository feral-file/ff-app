import 'dart:async';

import 'package:app/domain/models/ff1_device.dart';
import 'package:app/infra/ff1/wifi_control/ff1_wifi_control.dart';
import 'package:app/infra/ff1/wifi_transport/ff1_wifi_transport.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FF1WifiControl.getDeviceRealtimeMetrics', () {
    test('uses 30 second timeout for realtime metrics request', () async {
      final restClient = _RecordingRestClient();
      final control = FF1WifiControl(
        transport: _FakeWifiTransport(),
        restClient: restClient,
      );

      addTearDown(control.dispose);

      await control.getDeviceRealtimeMetrics(topicId: 'topic_1');

      expect(restClient.lastTopicId, 'topic_1');
      expect(restClient.lastCommand, 'metrics');
      expect(restClient.lastTimeout, const Duration(seconds: 30));
    });

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
}

class _RecordingRestClient {
  String? lastTopicId;
  String? lastCommand;
  Duration? lastTimeout;

  Future<Map<String, dynamic>> sendCommand({
    required String topicId,
    required String command,
    required Map<String, dynamic> params,
    Duration timeout = const Duration(seconds: 10),
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
    Duration timeout = const Duration(seconds: 10),
  }) async {
    throw TimeoutException('Future not completed');
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
  }) async {}

  @override
  Future<void> disconnect() async {}

  @override
  Future<void> sendCommand(Map<String, dynamic> command) async {}

  @override
  void dispose() {}
}
