/// Rules for when Device Configuration may show the automatic firmware
/// update prompt. Session-level dedupe for the same latest version string is
/// handled in app-layer orchestration; this function covers product gates only.
///
/// Blank or whitespace-only version strings are treated as absent because the
/// relayer verifier already treats them as "no signal" rather than a valid
/// firmware version.
String? normalizeFirmwareUpdateVersion(String? version) {
  final normalized = version?.trim();
  if (normalized == null || normalized.isEmpty) {
    return null;
  }
  return normalized;
}

/// Returns true when Device Configuration may show the automatic firmware
/// update prompt for the current device snapshot.
///
/// Session-level dedupe for the same latest version string is handled in the
/// app-layer orchestrator; this function only enforces product gating rules.
bool shouldOfferFirmwareUpdateAutoPrompt({
  required bool isInSetupProcess,
  required bool isRelayerConnected,
  required String? installedVersion,
  required String? latestVersion,
  required String dismissedLatestVersionForDevice,
}) {
  if (isInSetupProcess) {
    return false;
  }
  if (!isRelayerConnected) {
    return false;
  }
  final installed = normalizeFirmwareUpdateVersion(installedVersion);
  final latest = normalizeFirmwareUpdateVersion(latestVersion);
  final dismissedLatest = normalizeFirmwareUpdateVersion(
    dismissedLatestVersionForDevice,
  );
  if (installed == null || latest == null) {
    return false;
  }
  if (latest == installed) {
    return false;
  }
  if (dismissedLatest == latest) {
    return false;
  }
  return true;
}
