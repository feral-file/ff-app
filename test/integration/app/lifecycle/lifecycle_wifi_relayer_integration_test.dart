import 'package:app/app/providers/app_lifecycle_provider.dart';
import 'package:app/app/providers/ff1_wifi_providers.dart';
import 'package:app/app/providers/indexer_tokens_provider.dart';
import 'package:app/domain/models/ff1_device.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/widgets.dart';

import '../../../unit/app/providers/provider_test_helpers.dart';

/// Cross-module integration: [AppLifecycleNotifier] + [FF1WifiConnectionNotifier]
/// + [FF1WifiControl] fake — exercises lifecycle → pause → resume → reconnect
/// without a real relayer transport (see relayer isolate unit tests for I/O).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'integration: inactive debounce pauses relayer then resume reconnects',
    (tester) async {
      final binding = tester.binding;
      binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);

      final wifiControl = _IntegrationFakeWifiControl();
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

      await container.read(ff1WifiConnectionProvider.notifier).connect(
        device: const FF1Device(
          name: 'FF1',
          remoteId: 'remote-1',
          deviceId: 'device-1',
          topicId: 'topic-1',
        ),
        userId: 'user-1',
        apiKey: 'api-key-1',
      );
      wifiControl.resetCounts();

      expect(container.read(appLifecycleProvider), AppLifecycleState.resumed);

      binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump(const Duration(milliseconds: 400));

      expect(wifiControl.pauseCount, 1);
      expect(wifiControl.reconnectCount, 0);
      expect(
        container.read(appLifecycleProvider),
        AppLifecycleState.inactive,
      );

      binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();

      expect(wifiControl.reconnectCount, 1);
      expect(container.read(appLifecycleProvider), AppLifecycleState.resumed);
    },
  );
}

class _IntegrationFakeWifiControl extends FakeWifiControl {
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

  void resetCounts() {
    pauseCount = 0;
    reconnectCount = 0;
  }
}

class _RecordingTokensSyncCoordinator extends TokensSyncCoordinatorNotifier {
  @override
  TokensSyncState build() => const TokensSyncState();

  @override
  void startSyncCollectionPolling({
    Duration interval = const Duration(minutes: 5),
  }) {}

  @override
  void pauseSyncCollectionPolling() {}

  @override
  Future<void> syncAllTrackedAddresses() async {}
}
