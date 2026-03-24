import 'package:app/app/providers/ff1_wifi_providers.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

/// Test-only toggles for [ff1WifiTransportConnectedProvider] override.
class _TestTransportFlagNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void setValue(bool value) => state = value;
}

/// Test-only toggles for [ff1DeviceConnectedProvider] override.
class _TestDeviceFlagNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void setValue(bool value) => state = value;
}

final _testTransportConnected = NotifierProvider<_TestTransportFlagNotifier, bool>(
  _TestTransportFlagNotifier.new,
);

final _testDeviceConnected = NotifierProvider<_TestDeviceFlagNotifier, bool>(
  _TestDeviceFlagNotifier.new,
);

void main() {
  group('FF1ConnectionDiscrepancyWatcher', () {
    late List<SentryEvent> capturedEvents;

    Future<void> initSentryHarness() async {
      await Sentry.close();
      capturedEvents = <SentryEvent>[];
      await Sentry.init(
        (options) {
          options.dsn = 'https://key@o.ingest.sentry.io/1';
          options.beforeSend = (event, hint) {
            capturedEvents.add(event);
            return null;
          };
        },
      );
    }

    ProviderContainer createContainer() {
      return ProviderContainer.test(
        overrides: [
          ff1WifiTransportConnectedProvider.overrideWith(
            (ref) => ref.watch(_testTransportConnected),
          ),
          ff1DeviceConnectedProvider.overrideWith(
            (ref) => ref.watch(_testDeviceConnected),
          ),
        ],
      );
    }

    void setFlags(
      ProviderContainer c, {
      required bool transport,
      required bool device,
    }) {
      c.read(_testTransportConnected.notifier).setValue(transport);
      c.read(_testDeviceConnected.notifier).setValue(device);
    }

    tearDown(() async {
      await Sentry.close();
    });

    test(
      'cancels armed timer when gap closes before threshold — no Sentry',
      () async {
        await initSentryHarness();

        FakeAsync().run((async) {
          final container = createContainer();
          addTearDown(container.dispose);

          container.listen(
            ff1ConnectionDiscrepancyWatcherProvider,
            (_, __) {},
            fireImmediately: true,
          );

          setFlags(container, transport: true, device: false);
          async.flushMicrotasks();

          async.elapse(const Duration(seconds: 5));
          setFlags(container, transport: false, device: false);
          async.flushMicrotasks();

          async.elapse(const Duration(seconds: 30));
          async.flushMicrotasks();

          expect(capturedEvents, isEmpty);
        });
      },
    );

    test(
      'reports one warning Sentry event when gap persists through threshold',
      () async {
        await initSentryHarness();

        FakeAsync().run((async) {
          final container = createContainer();
          addTearDown(container.dispose);

          container.listen(
            ff1ConnectionDiscrepancyWatcherProvider,
            (_, __) {},
            fireImmediately: true,
          );

          setFlags(container, transport: true, device: false);
          async.flushMicrotasks();

          async.elapse(ff1ConnectionDiscrepancyThreshold);
          async.flushMicrotasks();

          expect(capturedEvents, hasLength(1));
          expect(capturedEvents.single.level, SentryLevel.warning);
          expect(
            capturedEvents.single.message?.formatted,
            contains('FF1 connection discrepancy'),
          );
        });
      },
    );

    test(
      'does not arm timer when transport is down or device already connected',
      () async {
        await initSentryHarness();

        FakeAsync().run((async) {
          final container = createContainer();
          addTearDown(container.dispose);

          container.listen(
            ff1ConnectionDiscrepancyWatcherProvider,
            (_, __) {},
            fireImmediately: true,
          );

          setFlags(container, transport: false, device: false);
          async.flushMicrotasks();
          async.elapse(ff1ConnectionDiscrepancyThreshold);
          async.flushMicrotasks();
          expect(capturedEvents, isEmpty);

          setFlags(container, transport: true, device: true);
          async.flushMicrotasks();
          async.elapse(ff1ConnectionDiscrepancyThreshold);
          async.flushMicrotasks();
          expect(capturedEvents, isEmpty);
        });
      },
    );

    test('does not send a second Sentry event after timer has already fired', () async {
      await initSentryHarness();

      FakeAsync().run((async) {
        final container = createContainer();
        addTearDown(container.dispose);

        container.listen(
          ff1ConnectionDiscrepancyWatcherProvider,
          (_, __) {},
          fireImmediately: true,
        );

        setFlags(container, transport: true, device: false);
        async.flushMicrotasks();

        async.elapse(ff1ConnectionDiscrepancyThreshold);
        async.flushMicrotasks();
        expect(capturedEvents, hasLength(1));

        async.elapse(ff1ConnectionDiscrepancyThreshold);
        async.flushMicrotasks();
        expect(capturedEvents, hasLength(1));
      });
    });
  });
}
