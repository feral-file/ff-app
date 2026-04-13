import 'package:app/app/providers/app_lifecycle_provider.dart';
import 'package:app/app/providers/ff1_wifi_providers.dart';
import 'package:app/app/providers/indexer_tokens_provider.dart';
import 'package:app/domain/models/ff1_device.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'provider_test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'inactive to resumed before debounce does not pause or reconnect relayer',
    (tester) async {
      final binding = tester.binding
        ..handleAppLifecycleStateChanged(AppLifecycleState.resumed);

      final wifiControl = _LifecycleAwareFakeWifiControl();
      final tokensSync = _RecordingTokensSyncCoordinator();
      final container = ProviderContainer.test(
        overrides: [
          ff1WifiControlProvider.overrideWithValue(wifiControl),
          ff1WifiConnectionProvider.overrideWith(
            FF1WifiConnectionNotifier.new,
          ),
          tokensSyncCoordinatorProvider.overrideWith(() => tokensSync),
        ],
      );
      addTearDown(() async {
        container.dispose();
        binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      });

      container.listen(appLifecycleProvider, (_, _) {});
      await tester.pump();
      tokensSync.resetCounts();

      await _connectDevice(container);
      wifiControl.resetLifecycleCounts();

      binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump(const Duration(milliseconds: 100));
      binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(wifiControl.pauseCount, 0);
      expect(wifiControl.reconnectCount, 0);
    },
  );

  testWidgets(
    'inactive that reaches debounce pauses and reconnects on resume',
    (tester) async {
      final binding = tester.binding
        ..handleAppLifecycleStateChanged(AppLifecycleState.resumed);

      final wifiControl = _LifecycleAwareFakeWifiControl();
      final tokensSync = _RecordingTokensSyncCoordinator();
      final container = ProviderContainer.test(
        overrides: [
          ff1WifiControlProvider.overrideWithValue(wifiControl),
          ff1WifiConnectionProvider.overrideWith(
            FF1WifiConnectionNotifier.new,
          ),
          tokensSyncCoordinatorProvider.overrideWith(() => tokensSync),
        ],
      );
      addTearDown(() async {
        container.dispose();
        binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      });

      container.listen(appLifecycleProvider, (_, _) {});
      await tester.pump();
      tokensSync.resetCounts();

      await _connectDevice(container);
      wifiControl.resetLifecycleCounts();

      binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump(const Duration(milliseconds: 400));
      expect(wifiControl.pauseCount, 1);
      expect(wifiControl.reconnectCount, 0);

      binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();

      expect(wifiControl.reconnectCount, 1);
    },
  );

  testWidgets(
    'paused to resumed reconnects only after lifecycle pause',
    (tester) async {
      final binding = tester.binding
        ..handleAppLifecycleStateChanged(AppLifecycleState.resumed);

      final wifiControl = _LifecycleAwareFakeWifiControl();
      final tokensSync = _RecordingTokensSyncCoordinator();
      final container = ProviderContainer.test(
        overrides: [
          ff1WifiControlProvider.overrideWithValue(wifiControl),
          ff1WifiConnectionProvider.overrideWith(
            FF1WifiConnectionNotifier.new,
          ),
          tokensSyncCoordinatorProvider.overrideWith(() => tokensSync),
        ],
      );
      addTearDown(() async {
        container.dispose();
        binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      });

      container.listen(appLifecycleProvider, (_, _) {});
      await tester.pump();
      tokensSync.resetCounts();

      await _connectDevice(container);
      wifiControl.resetLifecycleCounts();

      binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      expect(wifiControl.pauseCount, 1);
      expect(wifiControl.reconnectCount, 0);

      binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();

      expect(wifiControl.reconnectCount, 1);
    },
  );

  testWidgets(
    'hidden to resumed reconnects only after lifecycle pause',
    (tester) async {
      final binding = tester.binding
        ..handleAppLifecycleStateChanged(AppLifecycleState.resumed);

      final wifiControl = _LifecycleAwareFakeWifiControl();
      final tokensSync = _RecordingTokensSyncCoordinator();
      final container = ProviderContainer.test(
        overrides: [
          ff1WifiControlProvider.overrideWithValue(wifiControl),
          ff1WifiConnectionProvider.overrideWith(
            FF1WifiConnectionNotifier.new,
          ),
          tokensSyncCoordinatorProvider.overrideWith(() => tokensSync),
        ],
      );
      addTearDown(() async {
        container.dispose();
        binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      });

      container.listen(appLifecycleProvider, (_, _) {});
      await tester.pump();
      tokensSync.resetCounts();

      await _connectDevice(container);
      wifiControl.resetLifecycleCounts();

      binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      await tester.pump();
      expect(wifiControl.pauseCount, 1);
      expect(wifiControl.reconnectCount, 0);

      binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();

      expect(wifiControl.reconnectCount, 1);
    },
  );

  testWidgets(
    'detached to resumed reconnects only after lifecycle pause',
    (tester) async {
      final binding = tester.binding
        ..handleAppLifecycleStateChanged(AppLifecycleState.resumed);

      final wifiControl = _LifecycleAwareFakeWifiControl();
      final tokensSync = _RecordingTokensSyncCoordinator();
      final container = ProviderContainer.test(
        overrides: [
          ff1WifiControlProvider.overrideWithValue(wifiControl),
          ff1WifiConnectionProvider.overrideWith(
            FF1WifiConnectionNotifier.new,
          ),
          tokensSyncCoordinatorProvider.overrideWith(() => tokensSync),
        ],
      );
      addTearDown(() async {
        container.dispose();
        binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      });

      container.listen(appLifecycleProvider, (_, _) {});
      await tester.pump();
      tokensSync.resetCounts();

      await _connectDevice(container);
      wifiControl.resetLifecycleCounts();

      binding.handleAppLifecycleStateChanged(AppLifecycleState.detached);
      await tester.pump();
      expect(wifiControl.pauseCount, 1);
      expect(wifiControl.reconnectCount, 0);

      binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();

      expect(wifiControl.reconnectCount, 1);
    },
  );
}

Future<void> _connectDevice(ProviderContainer container) {
  return container.read(ff1WifiConnectionProvider.notifier).connect(
    device: const FF1Device(
      name: 'FF1',
      remoteId: 'remote-1',
      deviceId: 'device-1',
      topicId: 'topic-1',
    ),
    userId: 'user-1',
    apiKey: 'api-key-1',
  );
}

class _RecordingTokensSyncCoordinator extends TokensSyncCoordinatorNotifier {
  int syncAllTrackedAddressesCount = 0;
  int startSyncCollectionPollingCount = 0;
  int pauseSyncCollectionPollingCount = 0;

  @override
  TokensSyncState build() => const TokensSyncState();

  @override
  void startSyncCollectionPolling({
    Duration interval = const Duration(minutes: 5),
  }) {
    startSyncCollectionPollingCount++;
  }

  @override
  void pauseSyncCollectionPolling() {
    pauseSyncCollectionPollingCount++;
  }

  @override
  Future<void> syncAllTrackedAddresses() async {
    syncAllTrackedAddressesCount++;
  }

  void resetCounts() {
    syncAllTrackedAddressesCount = 0;
    startSyncCollectionPollingCount = 0;
    pauseSyncCollectionPollingCount = 0;
  }
}

class _LifecycleAwareFakeWifiControl extends FakeWifiControl {
  int pauseCount = 0;
  int reconnectCount = 0;

  @override
  void pauseConnection() {
    pauseCount++;
    super.pauseConnection();
  }

  @override
  Future<bool> reconnect() async {
    reconnectCount++;
    emitTransportConnection(isConnected: true);
    return true;
  }

  void resetLifecycleCounts() {
    pauseCount = 0;
    reconnectCount = 0;
  }
}
