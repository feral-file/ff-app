import 'package:app/app/providers/onboarding_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// UI policy for startup seed sync based on onboarding completion state.
class StartupSeedSyncUiPolicy {
  /// Creates startup seed sync UI policy.
  const StartupSeedSyncUiPolicy({
    required this.showUpdatingToast,
    required this.showSeedLoadingInUi,
  });

  /// Whether startup should show the top-level "Updating art library" toast.
  final bool showUpdatingToast;

  /// Whether startup should emit seed loading state to UI consumers.
  final bool showSeedLoadingInUi;

  /// Default startup behavior if policy resolution fails.
  static const visibleByDefault = StartupSeedSyncUiPolicy(
    showUpdatingToast: true,
    showSeedLoadingInUi: true,
  );
}

/// Contract for startup seed-sync UI behavior.
///
/// When onboarding is incomplete, startup seed sync must stay background-only
/// so onboarding interactions are not visually contested by seed status UI.
final startupSeedSyncUiPolicyProvider = FutureProvider<StartupSeedSyncUiPolicy>(
  (ref) async {
    final hasDoneOnboarding = await ref.watch(hasDoneOnboardingProvider.future);

    if (!hasDoneOnboarding) {
      return const StartupSeedSyncUiPolicy(
        showUpdatingToast: false,
        showSeedLoadingInUi: false,
      );
    }

    return StartupSeedSyncUiPolicy.visibleByDefault;
  },
);

/// Startup seed sync runner signature.
typedef StartupSeedSyncRunner =
    Future<bool> Function({
      required bool showUpdatingToast,
      required bool showLoadingInUI,
      required bool failSilently,
    });

/// Resolves startup seed-sync UI policy and executes [runSync].
///
/// Ensures startup sync still runs in all onboarding states; only the UI flags
/// vary by policy.
Future<bool> runStartupSeedSyncWithPolicy({
  required Future<StartupSeedSyncUiPolicy> Function() loadPolicy,
  required StartupSeedSyncRunner runSync,
  bool failSilently = true,
}) async {
  StartupSeedSyncUiPolicy uiPolicy;
  try {
    uiPolicy = await loadPolicy();
  } on Object {
    uiPolicy = StartupSeedSyncUiPolicy.visibleByDefault;
  }
  return runSync(
    showUpdatingToast: uiPolicy.showUpdatingToast,
    showLoadingInUI: uiPolicy.showSeedLoadingInUi,
    failSilently: failSilently,
  );
}
