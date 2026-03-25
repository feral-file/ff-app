import 'package:app/app/providers/bootstrap_provider.dart';
import 'package:app/app/providers/onboarding_provider.dart';
import 'package:app/infra/config/app_state_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'provider_test_helpers.dart';

void main() {
  test('onboarding action invalidates completion provider', () async {
    // Verifies completeOnboarding updates persisted state and refreshes the
    // completion query provider.
    final appState = MockAppStateService();
    final container = ProviderContainer.test(
      overrides: [
        appStateServiceProvider.overrideWithValue(appState),
      ],
    );
    addTearDown(container.dispose);

    expect(await container.read(hasDoneOnboardingProvider.future), isFalse);
    await container.read(onboardingActionsProvider).completeOnboarding();
    expect(await container.read(hasDoneOnboardingProvider.future), isTrue);
  });

  test('onboarding add-address gate waits while seed sync is active', () {
    final container = ProviderContainer.test(
      overrides: [
        bootstrapSeedSyncGatePhaseProvider.overrideWithValue(
          BootstrapSeedSyncGatePhase.syncInProgress,
        ),
      ],
    );
    addTearDown(container.dispose);

    final gate = container.read(onboardingAddAddressActionGateProvider);

    expect(
      gate.status,
      OnboardingAddAddressActionGateStatus.waitingForSeedSync,
    );
    expect(gate.actionsEnabled, isFalse);
    expect(gate.message, contains('Preparing your library'));
  });

  test('onboarding add-address gate stays open during deferred recovery', () {
    final container = ProviderContainer.test(
      overrides: [
        bootstrapSeedSyncGatePhaseProvider.overrideWithValue(
          BootstrapSeedSyncGatePhase.deferredRecovery,
        ),
      ],
    );
    addTearDown(container.dispose);

    final gate = container.read(onboardingAddAddressActionGateProvider);

    expect(gate.status, OnboardingAddAddressActionGateStatus.ready);
    expect(gate.actionsEnabled, isTrue);
    expect(gate.message, isNull);
  });
}
