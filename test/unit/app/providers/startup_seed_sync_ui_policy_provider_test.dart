import 'package:app/app/providers/onboarding_provider.dart';
import 'package:app/app/providers/startup_seed_sync_ui_policy_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'startup seed sync UI policy is silent when onboarding incomplete',
    () async {
      final container = ProviderContainer.test(
        overrides: [
          hasDoneOnboardingProvider.overrideWith((ref) async => false),
        ],
      );
      addTearDown(container.dispose);

      final policy = await container.read(
        startupSeedSyncUiPolicyProvider.future,
      );
      expect(policy.showUpdatingToast, isFalse);
      expect(policy.showSeedLoadingInUi, isFalse);
    },
  );

  test(
    'startup seed sync UI policy is visible after onboarding completion',
    () async {
      final container = ProviderContainer.test(
        overrides: [
          hasDoneOnboardingProvider.overrideWith((ref) async => true),
        ],
      );
      addTearDown(container.dispose);

      final policy = await container.read(
        startupSeedSyncUiPolicyProvider.future,
      );
      expect(policy.showUpdatingToast, isTrue);
      expect(policy.showSeedLoadingInUi, isTrue);
    },
  );

  test(
    'runStartupSeedSyncWithPolicy runs sync with silent UI flags '
    'when onboarding incomplete',
    () async {
      final container = ProviderContainer.test(
        overrides: [
          hasDoneOnboardingProvider.overrideWith((ref) async => false),
        ],
      );
      addTearDown(container.dispose);

      var called = false;
      final result = await runStartupSeedSyncWithPolicy(
        loadPolicy: () =>
            container.read(startupSeedSyncUiPolicyProvider.future),
        runSync:
            ({
              required showUpdatingToast,
              required showLoadingInUI,
              required failSilently,
            }) async {
              called = true;
              expect(showUpdatingToast, isFalse);
              expect(showLoadingInUI, isFalse);
              expect(failSilently, isTrue);
              return true;
            },
      );

      expect(called, isTrue);
      expect(result, isTrue);
    },
  );

  test(
    'runStartupSeedSyncWithPolicy runs sync with visible UI flags '
    'after onboarding completion',
    () async {
      final container = ProviderContainer.test(
        overrides: [
          hasDoneOnboardingProvider.overrideWith((ref) async => true),
        ],
      );
      addTearDown(container.dispose);

      var called = false;
      final result = await runStartupSeedSyncWithPolicy(
        loadPolicy: () =>
            container.read(startupSeedSyncUiPolicyProvider.future),
        runSync:
            ({
              required showUpdatingToast,
              required showLoadingInUI,
              required failSilently,
            }) async {
              called = true;
              expect(showUpdatingToast, isTrue);
              expect(showLoadingInUI, isTrue);
              expect(failSilently, isTrue);
              return false;
            },
      );

      expect(called, isTrue);
      expect(result, isFalse);
    },
  );
}
