import 'package:app/app/bootstrap/app_startup_orchestration.dart';
import 'package:app/app/providers/bootstrap_provider.dart';
import 'package:app/app/providers/ff1_wifi_providers.dart';
import 'package:app/infra/config/app_config.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUpAll(() async {
    await AppConfig.initialize();
  });

  group('restoreOnboardingGateAfterStartupFailure', () {
    test('reopens the gate when startup fails before deferred recovery', () {
      final container = ProviderContainer.test();
      addTearDown(container.dispose);

      container.read(bootstrapProvider.notifier).markSeedSyncInProgress();

      restoreOnboardingGateAfterStartupFailure(
        container.read(bootstrapProvider.notifier),
      );

      expect(
        container.read(bootstrapSeedSyncGatePhaseProvider),
        BootstrapSeedSyncGatePhase.gateOpen,
      );
    });

    test(
      'restores deferred recovery when startup had already deferred DP-1 work',
      () async {
        final container = ProviderContainer.test(
          overrides: [
            ff1AutoConnectWatcherProvider.overrideWithValue(null),
          ],
        );
        addTearDown(container.dispose);

        final bootstrap = container.read(bootstrapProvider.notifier);
        await bootstrap.bootstrapWithoutDp1Library();
        bootstrap.markSeedSyncInProgress();

        restoreOnboardingGateAfterStartupFailure(bootstrap);

        expect(
          container.read(bootstrapSeedSyncGatePhaseProvider),
          BootstrapSeedSyncGatePhase.deferredRecovery,
        );
      },
    );
  });

  group('runSeedDownloadRetry', () {
    test('runs seed sync before deferred DP-1 bootstrap follow-up', () async {
      final calls = <String>[];

      await runSeedDownloadRetry(
        syncSeedDatabase: () async {
          calls.add('sync');
        },
        ensureDp1BootstrapAfterSeedIfPending: () async {
          calls.add('ensure');
        },
      );

      expect(calls, ['sync', 'ensure']);
    });
  });
}
