import 'package:app/domain/ff1/firmware_update_prompt_policy.dart';
import 'package:flutter/foundation.dart';

/// Session state for the Device Configuration automatic firmware-update prompt.
///
/// Widgets apply tick results and clear in-flight when the modal completes.
@immutable
class Ff1FirmwarePromptSessionState {
  /// Creates session state.
  const Ff1FirmwarePromptSessionState({
    this.lastDeviceId,
    this.sessionPromptedForLatestVersion,
    this.isPromptInFlight = false,
  });

  /// Last device id we aligned session fields to.
  final String? lastDeviceId;

  /// Latest version string we already opened the auto-prompt for this visit.
  final String? sessionPromptedForLatestVersion;

  /// True while a center dialog is open or scheduled for this flow.
  final bool isPromptInFlight;

  /// Copy with replaced fields. Null bool leaves in-flight unchanged.
  Ff1FirmwarePromptSessionState copyWith({
    String? lastDeviceId,
    String? sessionPromptedForLatestVersion,
    bool? isPromptInFlight,
  }) {
    return Ff1FirmwarePromptSessionState(
      lastDeviceId: lastDeviceId ?? this.lastDeviceId,
      sessionPromptedForLatestVersion: sessionPromptedForLatestVersion ??
          this.sessionPromptedForLatestVersion,
      isPromptInFlight: isPromptInFlight ?? this.isPromptInFlight,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is Ff1FirmwarePromptSessionState &&
        other.lastDeviceId == lastDeviceId &&
        other.sessionPromptedForLatestVersion ==
            sessionPromptedForLatestVersion &&
        other.isPromptInFlight == isPromptInFlight;
  }

  @override
  int get hashCode => Object.hash(
        lastDeviceId,
        sessionPromptedForLatestVersion,
        isPromptInFlight,
      );
}

/// When non-null, the UI should show the auto-prompt for these versions.
@immutable
class Ff1FirmwareUpdatePromptShowRequest {
  /// Installed and latest version strings for the dialog copy.
  const Ff1FirmwareUpdatePromptShowRequest({
    required this.installedVersion,
    required this.latestVersion,
  });

  /// Currently installed firmware version.
  final String installedVersion;

  /// Latest available version from device/relayer status.
  final String latestVersion;
}

/// Result of one orchestration tick (read providers → maybe schedule prompt).
@immutable
class Ff1FirmwareUpdatePromptTickResult {
  /// New session state to store on the screen/notifier.
  const Ff1FirmwareUpdatePromptTickResult({
    required this.session,
    this.show,
  });

  /// Updated session after this tick.
  final Ff1FirmwarePromptSessionState session;

  /// When non-null, show one modal with these version strings.
  final Ff1FirmwareUpdatePromptShowRequest? show;
}

/// Clears the in-flight flag after the prompt dialog completes.
Ff1FirmwarePromptSessionState clearFirmwareUpdatePromptInFlight(
  Ff1FirmwarePromptSessionState session,
) {
  return session.copyWith(isPromptInFlight: false);
}

/// Decides whether to schedule the auto-prompt and updates session.
///
/// Call this whenever device id, relayer connection, or device status versions
/// may have changed. Prevents stacked dialogs while the prompt is in flight.
Ff1FirmwareUpdatePromptTickResult computeFirmwareUpdatePromptTick({
  required Ff1FirmwarePromptSessionState session,
  required String? activeDeviceId,
  required bool isInSetupProcess,
  required bool isRelayerConnected,
  required String? installedVersion,
  required String? latestVersion,
  required String dismissedLatestVersionForDevice,
}) {
  if (activeDeviceId == null) {
    return const Ff1FirmwareUpdatePromptTickResult(
      session: Ff1FirmwarePromptSessionState(),
    );
  }

  var next = session;
  if (session.lastDeviceId != activeDeviceId) {
    next = Ff1FirmwarePromptSessionState(
      lastDeviceId: activeDeviceId,
    );
  }

  final normalizedInstalled =
      normalizeFirmwareUpdateVersion(installedVersion);
  final normalizedLatest = normalizeFirmwareUpdateVersion(latestVersion);
  final normalizedDismissed = normalizeFirmwareUpdateVersion(
    dismissedLatestVersionForDevice,
  );

  if (!shouldOfferFirmwareUpdateAutoPrompt(
    isInSetupProcess: isInSetupProcess,
    isRelayerConnected: isRelayerConnected,
    installedVersion: normalizedInstalled,
    latestVersion: normalizedLatest,
    dismissedLatestVersionForDevice: normalizedDismissed ?? '',
  )) {
    return Ff1FirmwareUpdatePromptTickResult(session: next);
  }

  if (normalizedLatest == null || normalizedInstalled == null) {
    return Ff1FirmwareUpdatePromptTickResult(session: next);
  }

  if (next.isPromptInFlight) {
    return Ff1FirmwareUpdatePromptTickResult(session: next);
  }

  if (next.sessionPromptedForLatestVersion == normalizedLatest) {
    return Ff1FirmwareUpdatePromptTickResult(session: next);
  }

  return Ff1FirmwareUpdatePromptTickResult(
    session: next.copyWith(
      sessionPromptedForLatestVersion: normalizedLatest,
      isPromptInFlight: true,
    ),
    show: Ff1FirmwareUpdatePromptShowRequest(
      installedVersion: normalizedInstalled,
      latestVersion: normalizedLatest,
    ),
  );
}
