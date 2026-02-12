import 'package:app/infra/config/app_state_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Provider that checks if the user has seen onboarding.
/// Returns true if the user has completed onboarding, false otherwise.
final hasDoneOnboardingProvider = FutureProvider<bool>((ref) async {
  final appStateService = ref.watch(appStateServiceProvider);
  return appStateService.hasSeenOnboarding();
});

/// Imperative action helper for onboarding.
///
/// Use this from UI to mark onboarding as complete:
/// `ref.read(onboardingActionsProvider).completeOnboarding()`.
final onboardingActionsProvider = Provider<OnboardingService>((ref) {
  final appStateService = ref.watch(appStateServiceProvider);
  return OnboardingService(ref: ref, appStateService: appStateService);
});

/// Thin helper around [AppStateService] for onboarding operations.
class OnboardingService {
  /// Creates an [OnboardingService].
  OnboardingService({
    required this.ref,
    required this.appStateService,
  });

  /// Reference to the Riverpod [Ref].
  final Ref ref;

  /// Reference to the [AppStateService].
  final AppStateService appStateService;

  /// Mark onboarding as complete and refresh [hasDoneOnboardingProvider].
  Future<void> completeOnboarding() async {
    await appStateService.setHasSeenOnboarding(hasSeen: true);
    ref.invalidate(hasDoneOnboardingProvider);
  }
}
