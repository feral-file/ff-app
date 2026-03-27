import 'package:app/app/providers/bootstrap_provider.dart';
import 'package:app/infra/config/app_state_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Provider that checks if the user has seen onboarding.
/// Returns true if the user has completed onboarding, false otherwise.
final hasDoneOnboardingProvider = FutureProvider<bool>((ref) async {
  final appStateService = ref.watch(appStateServiceProvider);
  return appStateService.hasSeenOnboarding();
});

/// UI-level readiness for onboarding add-address actions.
enum OnboardingAddAddressActionGateStatus {
  /// Actions may execute immediately.
  ready,

  /// Actions must wait for startup seed sync to settle.
  waitingForSeedSync,
}

/// Typed readiness contract for onboarding address actions.
class OnboardingAddAddressActionGate {
  /// Creates an onboarding action gate.
  const OnboardingAddAddressActionGate({
    required this.status,
    this.message,
  });

  /// Current readiness state.
  final OnboardingAddAddressActionGateStatus status;

  /// Optional supporting message for the waiting UI.
  final String? message;

  /// True when onboarding actions should be interactive.
  bool get actionsEnabled =>
      status == OnboardingAddAddressActionGateStatus.ready;
}

/// Handshake between onboarding actions and startup seed-sync gating.
///
/// Only an active seed sync blocks the onboarding actions. Deferred recovery
/// remains allowed because first-install address adds intentionally queue until
/// a later seed is available.
final onboardingAddAddressActionGateProvider =
    Provider<OnboardingAddAddressActionGate>((ref) {
      final bootstrapGate = ref.watch(bootstrapSeedSyncGatePhaseProvider);
      return switch (bootstrapGate) {
        BootstrapSeedSyncGatePhase.syncInProgress =>
          const OnboardingAddAddressActionGate(
            status: OnboardingAddAddressActionGateStatus.waitingForSeedSync,
            message:
                'Preparing your library. You can add addresses in a moment.',
          ),
        BootstrapSeedSyncGatePhase.gateOpen ||
        BootstrapSeedSyncGatePhase.deferredRecovery =>
          const OnboardingAddAddressActionGate(
            status: OnboardingAddAddressActionGateStatus.ready,
          ),
      };
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
