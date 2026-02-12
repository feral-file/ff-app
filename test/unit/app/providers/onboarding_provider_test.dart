import 'package:app/app/providers/onboarding_provider.dart';
import 'package:app/infra/config/app_state_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'provider_test_helpers.dart';

void main() {
  test('onboarding action invalidates completion provider', () async {
    // Unit test: verifies completeOnboarding updates state service and refreshes query provider.
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
}
