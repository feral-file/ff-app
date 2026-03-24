import 'package:app/app/providers/bootstrap_provider.dart';

/// Reopens onboarding after a startup failure before bootstrap settled.
///
/// Startup closes the onboarding gate before seed sync begins so first-run
/// onboarding cannot race lightweight/full bootstrap decisions. If an
/// exception escapes before the notifier reaches one of its normal completed or
/// failed states, we must still restore the gate here or onboarding can remain
/// stuck on "Please wait" forever.
void restoreOnboardingGateAfterStartupFailure(
  BootstrapNotifier bootstrap,
) {
  if (bootstrap.pendingDp1BootstrapAfterSeed) {
    bootstrap.markDeferredRecovery();
    return;
  }

  bootstrap.markSeedSyncGateOpen();
}

/// Shared implementation for the app-level retry override.
///
/// The retry button should only rerun seed sync + deferred DP-1 bootstrap work.
/// It must not reapply the startup-only onboarding gate because by the time a
/// user manually retries, the app is already interactive and there is no cold-
/// start bootstrap race left to protect.
Future<void> runSeedDownloadRetry({
  required Future<void> Function() syncSeedDatabase,
  required Future<void> Function() ensureDp1BootstrapAfterSeedIfPending,
}) async {
  await syncSeedDatabase();
  await ensureDp1BootstrapAfterSeedIfPending();
}
