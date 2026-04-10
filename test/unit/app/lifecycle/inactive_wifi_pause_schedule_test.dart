import 'package:app/app/lifecycle/inactive_wifi_pause_schedule.dart';
import 'package:app/infra/logging/structured_logger.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logging/logging.dart';

void main() {
  group('wifiPauseDebouncerActionFor', () {
    test('maps resumed to cancel timer only', () {
      expect(
        wifiPauseDebouncerActionFor(AppLifecycleState.resumed),
        WifiPauseDebouncerAction.cancelTimerOnly,
      );
    });

    test('maps inactive to schedule debounce', () {
      expect(
        wifiPauseDebouncerActionFor(AppLifecycleState.inactive),
        WifiPauseDebouncerAction.scheduleInactiveTimerIfNone,
      );
    });

    test('maps paused detached hidden to immediate pause', () {
      for (final s in [
        AppLifecycleState.paused,
        AppLifecycleState.detached,
        AppLifecycleState.hidden,
      ]) {
        expect(
          wifiPauseDebouncerActionFor(s),
          WifiPauseDebouncerAction.cancelTimerAndPauseWifiNow,
        );
      }
    });
  });

  group('shouldRunDebouncedInactiveWifiPause', () {
    test('false when resumed', () {
      expect(
        shouldRunDebouncedInactiveWifiPause(AppLifecycleState.resumed),
        isFalse,
      );
    });

    test('true when not resumed', () {
      for (final s in [
        AppLifecycleState.inactive,
        AppLifecycleState.paused,
        AppLifecycleState.detached,
        AppLifecycleState.hidden,
      ]) {
        expect(shouldRunDebouncedInactiveWifiPause(s), isTrue);
      }
    });
  });

  group('InactiveRelayerWifiPauseCoordinator', () {
    test('inactive schedules one pause after debounce', () {
      FakeAsync().run((async) {
        final coord = InactiveRelayerWifiPauseCoordinator(
          debounce: const Duration(milliseconds: 100),
          structuredLog: AppStructuredLog.forLogger(
            Logger('test'),
            context: const {'component': 'test'},
          ),
        );
        var pauseCount = 0;
        AppLifecycleState current = AppLifecycleState.inactive;

        coord.onLifecycle(
          state: AppLifecycleState.inactive,
          readLifecycle: () => current,
          pauseRelayerWifi: () => pauseCount++,
        );

        expect(pauseCount, 0);
        async.elapse(const Duration(milliseconds: 99));
        expect(pauseCount, 0);
        async.elapse(const Duration(milliseconds: 2));
        expect(pauseCount, 1);

        coord.dispose();
      });
    });

    test('resumed cancels pending inactive pause', () {
      FakeAsync().run((async) {
        final coord = InactiveRelayerWifiPauseCoordinator(
          debounce: const Duration(milliseconds: 100),
          structuredLog: AppStructuredLog.forLogger(
            Logger('test'),
            context: const {'component': 'test'},
          ),
        );
        var pauseCount = 0;
        AppLifecycleState current = AppLifecycleState.inactive;

        coord.onLifecycle(
          state: AppLifecycleState.inactive,
          readLifecycle: () => current,
          pauseRelayerWifi: () => pauseCount++,
        );

        async.elapse(const Duration(milliseconds: 50));
        current = AppLifecycleState.resumed;
        coord.onLifecycle(
          state: AppLifecycleState.resumed,
          readLifecycle: () => current,
          pauseRelayerWifi: () => pauseCount++,
        );

        async.elapse(const Duration(milliseconds: 200));
        expect(pauseCount, 0);

        coord.dispose();
      });
    });

    test('duplicate inactive does not reschedule timer', () {
      FakeAsync().run((async) {
        final coord = InactiveRelayerWifiPauseCoordinator(
          debounce: const Duration(milliseconds: 100),
          structuredLog: AppStructuredLog.forLogger(
            Logger('test'),
            context: const {'component': 'test'},
          ),
        );
        var pauseCount = 0;
        final current = AppLifecycleState.inactive;

        coord.onLifecycle(
          state: AppLifecycleState.inactive,
          readLifecycle: () => current,
          pauseRelayerWifi: () => pauseCount++,
        );
        coord.onLifecycle(
          state: AppLifecycleState.inactive,
          readLifecycle: () => current,
          pauseRelayerWifi: () => pauseCount++,
        );

        async.elapse(const Duration(milliseconds: 100));
        expect(pauseCount, 1);

        coord.dispose();
      });
    });

    test('timer fire skips pause when lifecycle is resumed', () {
      FakeAsync().run((async) {
        final coord = InactiveRelayerWifiPauseCoordinator(
          debounce: const Duration(milliseconds: 100),
          structuredLog: AppStructuredLog.forLogger(
            Logger('test'),
            context: const {'component': 'test'},
          ),
        );
        var pauseCount = 0;
        AppLifecycleState current = AppLifecycleState.inactive;

        coord.onLifecycle(
          state: AppLifecycleState.inactive,
          readLifecycle: () => current,
          pauseRelayerWifi: () => pauseCount++,
        );

        async.elapse(const Duration(milliseconds: 50));
        // Simulate race: timer still pending but readLifecycle returns resumed
        // (e.g. user returned to app; next tick sees resumed).
        current = AppLifecycleState.resumed;
        async.elapse(const Duration(milliseconds: 60));
        expect(pauseCount, 0);

        coord.dispose();
      });
    });
  });
}
