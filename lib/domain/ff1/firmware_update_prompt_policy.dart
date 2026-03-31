/// Rules for when Device Configuration may show the automatic firmware
/// update prompt. Session-level dedupe (same [latestVersion] already prompted)
/// stays in the screen state; this function covers product gates only.
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
  final installed = installedVersion;
  final latest = latestVersion;
  if (installed == null || latest == null) {
    return false;
  }
  if (latest == installed) {
    return false;
  }
  if (dismissedLatestVersionForDevice == latest) {
    return false;
  }
  return true;
}
