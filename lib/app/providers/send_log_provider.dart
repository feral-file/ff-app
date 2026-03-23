import 'package:app/app/providers/ff1_providers.dart';
import 'package:app/app/providers/ff1_wifi_providers.dart';
import 'package:app/domain/models/ff1_device.dart';
import 'package:app/infra/config/app_config.dart';
import 'package:app/infra/ff1/wifi_control/ff1_wifi_control_verifier.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';

final _log = Logger('SendLogNotifier');

/// Provides `SUPPORT_API_KEY` as an injectable value so tests can override it
/// without needing a dotenv file.
final supportApiKeyProvider = Provider<String>(
  (ref) => AppConfig.supportApiKey,
);

// ============================================================================
// Outcome types
// ============================================================================

/// Typed result of a send-log attempt.
///
/// The widget layer pattern-matches on this to decide which dialog to show,
/// without knowing anything about key config, transports, or fallback logic.
sealed class SendLogOutcome {
  const SendLogOutcome();
}

/// `SUPPORT_API_KEY` is missing on this build.
/// The device was never contacted; no transport command was issued.
class SendLogNotConfigured extends SendLogOutcome {
  const SendLogNotConfigured();
}

/// Log was successfully dispatched to the support backend.
class SendLogSuccess extends SendLogOutcome {
  const SendLogSuccess();
}

/// Log dispatch failed (WiFi and BLE both unsuccessful or threw).
class SendLogFailure extends SendLogOutcome {
  const SendLogFailure(this.error);

  final Object error;
}

// ============================================================================
// Notifier
// ============================================================================

/// Owns the complete send-log action: key validation, WiFi→BLE transport
/// selection, and error mapping.
///
/// The widget calls [send] and renders whichever [SendLogOutcome] comes back.
/// No config lookup or transport decision belongs in the widget layer.
class SendLogNotifier extends Notifier<void> {
  @override
  void build() {}

  /// Attempt to send device logs to support.
  ///
  /// Flow:
  /// 1. Validate `SUPPORT_API_KEY` is present. Return [SendLogNotConfigured]
  ///    immediately — without touching the device — if missing.
  /// 2. Try WiFi when [device.topicId] is available. Treat any non-ok response
  ///    or thrown exception as a signal to fall back to BLE.
  /// 3. Fall back to BLE. Treat any thrown exception as [SendLogFailure].
  Future<SendLogOutcome> send(FF1Device device) async {
    final apiKey = ref.read(supportApiKeyProvider);
    if (apiKey.isEmpty) {
      _log.severe('[SendLog] SUPPORT_API_KEY is not configured');
      return const SendLogNotConfigured();
    }

    // The support backend correlates logs by userId. For now we use the device
    // name as a human-readable identifier; this matches the previous behavior.
    const userId = 'user-id';

    try {
      var success = false;

      if (device.topicId.isNotEmpty) {
        try {
          _log.info('[SendLog] Attempting via WiFi');
          final wifiControl = ref.read(ff1WifiControlProvider);
          final response = await wifiControl.sendLog(
            topicId: device.topicId,
            userId: userId,
            title: device.name,
            apiKey: apiKey,
          );
          // Use the canonical verifier: explicit ok flag takes priority over
          // status string so the result is consistent with all other WiFi
          // command checks in this codebase.
          final okFlag = ff1CommandResponseOkFlag(response);
          success = okFlag ?? ff1CommandResponseIsOk(response);
          if (!success) {
            _log.warning('[SendLog] WiFi returned non-ok response, falling back to BLE');
          }
        } catch (e) {
          _log.warning('[SendLog] WiFi error: $e, falling back to BLE');
        }
      }

      if (!success) {
        _log.info('[SendLog] Attempting via BLE');
        final bleControl = ref.read(ff1ControlProvider);
        await bleControl.sendLog(
          blDevice: device.toBluetoothDevice(),
          userId: userId,
          title: device.name,
          apiKey: apiKey,
        );
        success = true;
      }

      return success ? const SendLogSuccess() : const SendLogFailure('unknown');
    } catch (e) {
      _log.warning('[SendLog] Failed: $e');
      return SendLogFailure(e);
    }
  }
}

/// Provider for the send-log action.
final sendLogProvider = NotifierProvider<SendLogNotifier, void>(
  SendLogNotifier.new,
);
