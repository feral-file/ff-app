import 'package:app/domain/ff1/firmware_update_prompt_policy.dart';
import 'package:app/infra/config/app_state_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// App-layer persistence/lookup for firmware-update prompt dismissal state.
///
/// Widgets use this service to avoid talking to [AppStateService] directly,
/// keeping prompt semantics centralized in the app layer.
class Ff1FirmwareUpdatePromptService {
  /// Creates a prompt service backed by app-state persistence.
  const Ff1FirmwareUpdatePromptService(this._appStateService);

  final AppStateServiceBase _appStateService;

  /// Returns the dismissed latest version for [deviceId], normalized.
  String getDismissedLatestVersionForDevice(String deviceId) {
    return normalizeFirmwareUpdateVersion(
          _appStateService.getDismissedUpdateVersion(deviceId),
        ) ??
        '';
  }

  /// Persists [version] as the dismissed firmware version for [deviceId].
  ///
  /// Blank values are ignored because they do not represent a usable firmware
  /// version and should not suppress future prompts.
  Future<void> dismissLatestVersionForDevice({
    required String deviceId,
    required String version,
  }) async {
    final normalized = normalizeFirmwareUpdateVersion(version);
    if (normalized == null) {
      return;
    }
    await _appStateService.setDismissedUpdateVersion(
      deviceId: deviceId,
      version: normalized,
    );
  }
}

/// App-layer firmware-update prompt state service.
final ff1FirmwareUpdatePromptServiceProvider =
    Provider<Ff1FirmwareUpdatePromptService>((ref) {
      return Ff1FirmwareUpdatePromptService(ref.watch(appStateServiceProvider));
    });
