import 'dart:async';

import 'package:app/domain/models/ff1_device.dart';
import 'package:app/infra/ff1/wifi_transport/ff1_relayer_transport.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('relayerDisconnectEventAppliesToSession', () {
    test('ignores stale gen vs active session', () {
      expect(
        relayerDisconnectEventAppliesToSession(
          eventConnectGen: 1,
          activeRelayerConnectGen: 2,
          expectedConnectedGen: null,
        ),
        isFalse,
      );
    });

    test('accepts disconnect for active socket gen', () {
      expect(
        relayerDisconnectEventAppliesToSession(
          eventConnectGen: 2,
          activeRelayerConnectGen: 2,
          expectedConnectedGen: null,
        ),
        isTrue,
      );
    });

    test('accepts disconnect for in-flight expected gen', () {
      expect(
        relayerDisconnectEventAppliesToSession(
          eventConnectGen: 3,
          activeRelayerConnectGen: null,
          expectedConnectedGen: 3,
        ),
        isTrue,
      );
    });

    test('legacy null gen still applies', () {
      expect(
        relayerDisconnectEventAppliesToSession(
          eventConnectGen: null,
          activeRelayerConnectGen: 2,
          expectedConnectedGen: 4,
        ),
        isTrue,
      );
    });
  });

  test(
    'dispose awaits disconnect before closing connection state stream',
    () async {
      FF1RelayerTransport(
        relayerUrl: 'wss://example.invalid/relayer',
      ).dispose();
      // disconnect() delays before connection-state emit; concurrent
      // controller.close() used to race that emit (controller already closed).
      await Future<void>.delayed(const Duration(milliseconds: 150));
    },
  );

  test(
    'concurrent disconnect calls share single teardown completer '
    '(cycle 1 and 2)',
    () async {
      final transport = FF1RelayerTransport(
        relayerUrl: 'wss://example.invalid/relayer',
      );

      // Cycle 1: both concurrent calls should complete
      final cycle1Start = DateTime.now();
      final f1 = transport.disconnect();
      final f2 = transport.disconnect();

      await Future.wait([f1, f2]);
      final cycle1Duration = DateTime.now().difference(cycle1Start);

      // Verify cycle 1 had meaningful delay (100ms disconnect delay + overhead)
      expect(cycle1Duration.inMilliseconds, greaterThan(80));

      // Cycle 2: verify completer resets and single-flight works independently
      final cycle2Start = DateTime.now();
      final f3 = transport.disconnect();
      final f4 = transport.disconnect();

      await Future.wait([f3, f4]);
      final cycle2Duration = DateTime.now().difference(cycle2Start);

      // If completer wasn't reset, cycle 2 would complete immediately (< 50ms).
      // With proper reset, cycle 2 should also have the 100ms delay from
      // teardown.
      expect(cycle2Duration.inMilliseconds, greaterThan(80),
          reason: 'Cycle 2 must execute full teardown, not reuse completed '
              'completer from cycle 1 (proves completer was reset)');
    },
  );

  test(
    'dispose waits for all subscriptions before closing controllers',
    () async {
      final transport = FF1RelayerTransport(
        relayerUrl: 'wss://example.invalid/relayer',
      )..dispose();

      // Wait for any pending async operations
      await Future<void>.delayed(const Duration(milliseconds: 200));

      // Verify that the transport is fully torn down without exceptions
      expect(transport.isConnected, isFalse);
    },
  );

  test(
    'connectionStateStream does not throw when added to after close '
    'during dispose',
    () async {
      final transport = FF1RelayerTransport(
        relayerUrl: 'wss://example.invalid/relayer',
      )..dispose();

      // Wait to allow async dispose to complete
      await Future<void>.delayed(const Duration(milliseconds: 200));

      // Try to listen to the stream after disposal (should not throw)
      expect(
        () {
          transport.connectionStateStream.listen((_) {});
        },
        returnsNormally,
      );
    },
  );

  test(
    'pause skips queued connect control before it reaches isolate',
    () async {
      final reachedDispatchBoundary = Completer<void>();
      final releaseDispatch = Completer<void>();
      final transport = FF1RelayerTransport(
        relayerUrl: 'wss://example.invalid/relayer',
        debugBeforeConnectControlDispatch: () {
          reachedDispatchBoundary.complete();
          return releaseDispatch.future;
        },
      );
      final events = <bool>[];
      final sub = transport.connectionStateStream.listen(events.add);

      addTearDown(() async {
        await sub.cancel();
        await transport.disposeFuture();
      });

      final connectFuture = transport.connect(
        device: const FF1Device(
          name: 'FF1',
          remoteId: 'remote-1',
          deviceId: 'device-1',
          topicId: 'topic-1',
        ),
        userId: 'user-1',
        apiKey: 'api-key-1',
      );

      await reachedDispatchBoundary.future;
      transport.pauseConnection();
      releaseDispatch.complete();
      final connectOk = await connectFuture;
      await Future<void>.delayed(const Duration(milliseconds: 250));

      expect(connectOk, isFalse);
      expect(events.where((isConnected) => isConnected), isEmpty);
      expect(transport.isConnected, isFalse);
    },
  );

  test(
    'connect(forceReconnect: true) after live socket dispatches replacement '
    'session (no self-suppression)',
    () async {
      final transport = FF1RelayerTransport(
        relayerUrl: 'wss://example.invalid/relayer',
      );
      const device = FF1Device(
        name: 'FF1',
        remoteId: 'remote-1',
        deviceId: 'device-1',
        topicId: 'topic-1',
      );

      final firstConnected = Completer<void>();
      final sub = transport.connectionStateStream.listen((connected) {
        if (connected && !firstConnected.isCompleted) {
          firstConnected.complete();
        }
      });
      addTearDown(() async {
        await sub.cancel();
        await transport.disposeFuture();
      });

      final ok1 = await transport.connect(
        device: device,
        userId: 'user-1',
        apiKey: 'api-key-1',
      );
      expect(ok1, isTrue);
      await firstConnected.future.timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          fail(
            'expected relayer isolate to emit connected (live socket) before '
            'forceReconnect regression assertions',
          );
        },
      );
      expect(transport.isConnected, isTrue);

      final ok2 = await transport.connect(
        device: device,
        userId: 'user-1',
        apiKey: 'api-key-1',
        forceReconnect: true,
      );
      expect(
        ok2,
        isTrue,
        reason: 'forceReconnect must open a new session after disconnect; '
            'must not return false solely because disconnect() set suppression',
      );
    },
  );

  test(
    'connect(forceReconnect) returns false when pause wins during disconnect '
    'teardown (PR #361 review 4098103277)',
    () async {
      late FF1RelayerTransport transport;
      transport = FF1RelayerTransport(
        relayerUrl: 'wss://example.invalid/relayer',
        debugBeforeDisconnectGraceDelay: () async {
          transport.pauseConnection();
        },
      );
      const device = FF1Device(
        name: 'FF1',
        remoteId: 'remote-1',
        deviceId: 'device-1',
        topicId: 'topic-1',
      );

      final firstConnected = Completer<void>();
      final sub = transport.connectionStateStream.listen((connected) {
        if (connected && !firstConnected.isCompleted) {
          firstConnected.complete();
        }
      });
      addTearDown(() async {
        await sub.cancel();
        await transport.disposeFuture();
      });

      final ok1 = await transport.connect(
        device: device,
        userId: 'user-1',
        apiKey: 'api-key-1',
      );
      expect(ok1, isTrue);
      await firstConnected.future.timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          fail('expected live socket before pause-during-disconnect test');
        },
      );

      final ok2 = await transport.connect(
        device: device,
        userId: 'user-1',
        apiKey: 'api-key-1',
        forceReconnect: true,
      );
      expect(ok2, isFalse);
      expect(transport.isConnected, isFalse);
    },
  );

  test(
    'connect waits for in-flight disconnect teardown before proceeding '
    '(PR #361 review 4098243960)',
    () async {
      final releaseTeardown = Completer<void>();
      late FF1RelayerTransport transport;
      transport = FF1RelayerTransport(
        relayerUrl: 'wss://example.invalid/relayer',
        debugBeforeDisconnectGraceDelay: () async {
          await releaseTeardown.future;
        },
      );
      const device = FF1Device(
        name: 'FF1',
        remoteId: 'remote-1',
        deviceId: 'device-1',
        topicId: 'topic-1',
      );

      final firstConnected = Completer<void>();
      final sub = transport.connectionStateStream.listen((connected) {
        if (connected && !firstConnected.isCompleted) {
          firstConnected.complete();
        }
      });
      addTearDown(() async {
        await sub.cancel();
        await transport.disposeFuture();
      });

      await transport.connect(
        device: device,
        userId: 'user-1',
        apiKey: 'api-key-1',
      );
      await firstConnected.future.timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          fail('expected live socket before teardown-wait test');
        },
      );

      final secondReconnect = transport.connect(
        device: device,
        userId: 'user-1',
        apiKey: 'api-key-1',
        forceReconnect: true,
      );

      await Future<void>.delayed(Duration.zero);

      var thirdCompleted = false;
      final thirdConnect = transport
          .connect(
            device: device,
            userId: 'user-1',
            apiKey: 'api-key-1',
          )
          .then((_) {
        thirdCompleted = true;
      });

      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(
        thirdCompleted,
        isFalse,
        reason: 'third connect must wait for teardown, not run ahead of it',
      );

      releaseTeardown.complete();
      await secondReconnect;
      await thirdConnect;
      expect(thirdCompleted, isTrue);
    },
  );
}
