import 'dart:async';

import 'package:app/app/providers/ff1_wifi_providers.dart';
import 'package:app/domain/models/ff1_device.dart';
import 'package:app/infra/ff1/wifi_control/ff1_wifi_control.dart';
import 'package:app/infra/ff1/wifi_protocol/ff1_wifi_messages.dart';
import 'package:app/infra/ff1/wifi_transport/ff1_wifi_transport.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logging/logging.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

/// Minimal transport for Sentry routing tests: optional network error on stream
/// before `connect` throws.
class _ThrowingConnectTransport implements FF1WifiTransport {
  _ThrowingConnectTransport({required this.emitNetworkErrorBeforeThrow});

  final bool emitNetworkErrorBeforeThrow;

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
  }) async {
    if (emitNetworkErrorBeforeThrow) {
      _errors.add(const FF1WifiNetworkError('simulated transport failure'));
    }
    throw Exception('connect failed');
  }

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
    unawaited(_errors.close());
  }
}

/// First `connect` succeeds; second `connect` (e.g. `forceReconnect: true`)
/// emits a network error and throws — mirrors resume/reconnect failure after a
/// good initial session.
class _ReconnectSecondCallFailsTransport implements FF1WifiTransport {
  _ReconnectSecondCallFailsTransport();

  final _notifications = StreamController<FF1NotificationMessage>.broadcast();
  final _connections = StreamController<bool>.broadcast();
  final _errors = StreamController<FF1WifiTransportError>.broadcast();

  var _connectCount = 0;

  @override
  Stream<bool> get connectionStateStream => _connections.stream;

  @override
  Stream<FF1NotificationMessage> get notificationStream =>
      _notifications.stream;

  @override
  Stream<FF1WifiTransportError> get errorStream => _errors.stream;

  @override
  bool get isConnected => _connectCount >= 1;

  @override
  bool get isConnecting => false;

  @override
  Future<void> connect({
    required FF1Device device,
    required String userId,
    required String apiKey,
    bool forceReconnect = false,
  }) async {
    _connectCount++;
    if (_connectCount == 1) {
      return;
    }
    _errors.add(const FF1WifiNetworkError('reconnect transport failure'));
    throw Exception('reconnect failed');
  }

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
    unawaited(_errors.close());
  }
}

void main() {
  const device = FF1Device(
    name: 'FF1',
    remoteId: 'r',
    deviceId: 'd',
    topicId: 'topic',
  );

  group('FF1 WiFi connect / reconnect Sentry split', () {
    late List<SentryEvent> capturedEvents;

    Future<void> initSentryHarness() async {
      await Sentry.close();
      capturedEvents = <SentryEvent>[];
      await Sentry.init(
        (options) {
          options
            ..dsn = 'https://key@o.ingest.sentry.io/1'
            ..beforeSend = (event, hint) {
              capturedEvents.add(event);
              return null;
            };
        },
      );
    }

    tearDown(() async {
      await Sentry.close();
    });

    test(
      'FF1WifiControl: network error on stream before connect throws → one '
      'warning (not duplicate exception reports)',
      () async {
        await initSentryHarness();

        final transport = _ThrowingConnectTransport(
          emitNetworkErrorBeforeThrow: true,
        );
        final control = FF1WifiControl(
          transport: transport,
          logger: Logger('test'),
        );
        addTearDown(() {
          control.dispose();
          transport.dispose();
        });

        await expectLater(
          control.connect(
            device: device,
            userId: 'u',
            apiKey: 'k',
          ),
          throwsException,
        );
        await Future<void>.delayed(Duration.zero);

        expect(capturedEvents, hasLength(1));
        expect(capturedEvents.single.level, SentryLevel.warning);
        expect(
          capturedEvents.single.tags?['component'],
          'ff1_wifi_transport',
        );
      },
    );

    test(
      'FF1WifiControl: connect throws without network error → no Sentry '
      '(notifier also does not add a second layer)',
      () async {
        await initSentryHarness();

        final transport = _ThrowingConnectTransport(
          emitNetworkErrorBeforeThrow: false,
        );
        final control = FF1WifiControl(
          transport: transport,
          logger: Logger('test'),
        );
        addTearDown(() {
          control.dispose();
          transport.dispose();
        });

        await expectLater(
          control.connect(
            device: device,
            userId: 'u',
            apiKey: 'k',
          ),
          throwsException,
        );
        await Future<void>.delayed(Duration.zero);

        expect(capturedEvents, isEmpty);
      },
    );

    test(
      'FF1WifiConnectionNotifier.connect failure: no extra Sentry when '
      'transport already reported a network warning',
      () async {
        await initSentryHarness();

        final transport = _ThrowingConnectTransport(
          emitNetworkErrorBeforeThrow: true,
        );

        final container = ProviderContainer.test(
          overrides: [
            ff1WifiControlProvider.overrideWith((ref) {
              final control = FF1WifiControl(
                transport: transport,
                logger: Logger('test'),
              );
              ref.onDispose(control.dispose);
              return control;
            }),
            ff1WifiConnectionProvider.overrideWith(
              FF1WifiConnectionNotifier.new,
            ),
          ],
        );
        addTearDown(container.dispose);
        addTearDown(transport.dispose);

        await expectLater(
          container
              .read(ff1WifiConnectionProvider.notifier)
              .connect(
                device: device,
                userId: 'u',
                apiKey: 'k',
              ),
          throwsException,
        );
        await Future<void>.delayed(Duration.zero);

        expect(capturedEvents, hasLength(1));
        expect(capturedEvents.single.level, SentryLevel.warning);
      },
    );

    test(
      'FF1WifiConnectionNotifier.reconnect failure: same single-layer Sentry',
      () async {
        await initSentryHarness();

        final transport = _ReconnectSecondCallFailsTransport();

        final container = ProviderContainer.test(
          overrides: [
            ff1WifiControlProvider.overrideWith((ref) {
              final control = FF1WifiControl(
                transport: transport,
                logger: Logger('test'),
              );
              ref.onDispose(control.dispose);
              return control;
            }),
            ff1WifiConnectionProvider.overrideWith(
              FF1WifiConnectionNotifier.new,
            ),
          ],
        );
        addTearDown(container.dispose);
        addTearDown(transport.dispose);

        await container
            .read(ff1WifiConnectionProvider.notifier)
            .connect(device: device, userId: 'u', apiKey: 'k');
        expect(container.read(ff1WifiConnectionProvider).isConnected, isTrue);

        await container.read(ff1WifiConnectionProvider.notifier).reconnect();
        await Future<void>.delayed(Duration.zero);

        expect(capturedEvents, hasLength(1));
        expect(capturedEvents.single.level, SentryLevel.warning);
      },
    );
  });
}
