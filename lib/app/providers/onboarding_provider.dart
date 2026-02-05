import 'package:app/infra/config/app_flags_store.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Key for the onboarding flag in AppFlagsStore.
const _hasSeenOnboardingKey = 'hasSeenOnboarding';

/// Provider that checks if the user has seen onboarding.
/// Returns true if the user has completed onboarding, false otherwise.
final hasSeenOnboardingProvider = FutureProvider<bool>((ref) async {
  final flagsStore = ref.watch(appFlagsStoreProvider);
  return flagsStore.getBool(_hasSeenOnboardingKey);
});

/// Imperative action helper for onboarding.
///
/// Use this from UI to mark onboarding as complete:
/// `ref.read(onboardingActionsProvider).completeOnboarding()`.
final onboardingActionsProvider = Provider<OnboardingActions>((ref) {
  final flagsStore = ref.watch(appFlagsStoreProvider);
  return OnboardingActions(ref: ref, flagsStore: flagsStore);
});

/// Thin helper around [AppFlagsStore] for onboarding operations.
class OnboardingActions {
  /// Creates an [OnboardingActions].
  OnboardingActions({
    required this.ref,
    required this.flagsStore,
  });

  /// Reference to the Riverpod [Ref].
  final Ref ref;

  /// Reference to the [AppFlagsStore].
  final AppFlagsStore flagsStore;

  /// Mark onboarding as complete and refresh [hasSeenOnboardingProvider].
  Future<void> completeOnboarding() async {
    await flagsStore.setBool(_hasSeenOnboardingKey, true);
    ref.invalidate(hasSeenOnboardingProvider);
  }
}
