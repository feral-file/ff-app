import 'package:app/app/providers/ff1_wifi_providers.dart';
import 'package:app/infra/ff1/wifi_control/ff1_wifi_control.dart';
import 'package:app/infra/ff1/wifi_control/ff1_wifi_control_verifier.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Result of asking the relayer to start a firmware update (Wi-Fi path only).
enum Ff1RelayerFirmwareUpdateOutcome {
  /// Relayer accepted the command per response parsing rules.
  success,

  /// No topic id; cannot address the device on the relayer.
  missingTopic,

  /// Command ran but response was not OK.
  relayerRejected,

  /// Threw while sending or parsing (network, timeout, etc.).
  commandFailed,
}

/// Starts firmware update via Wi-Fi control only (no Bluetooth).
class Ff1RelayerFirmwareUpdateService {
  /// Creates a service backed by the given Wi-Fi control instance.
  const Ff1RelayerFirmwareUpdateService(this._control);

  final FF1WifiControl _control;

  /// Sends update-to-latest for [topicId] and classifies the outcome.
  Future<Ff1RelayerFirmwareUpdateOutcome> start({
    required String topicId,
  }) async {
    if (topicId.isEmpty) {
      return Ff1RelayerFirmwareUpdateOutcome.missingTopic;
    }
    try {
      final response = await _control.updateToLatestVersion(topicId: topicId);
      final okFlag = ff1CommandResponseOkFlag(response);
      final ok = okFlag ?? ff1CommandResponseIsOk(response);
      return ok
          ? Ff1RelayerFirmwareUpdateOutcome.success
          : Ff1RelayerFirmwareUpdateOutcome.relayerRejected;
    } on Exception {
      return Ff1RelayerFirmwareUpdateOutcome.commandFailed;
    }
  }
}

/// App-layer entry for relayer-only firmware update start.
final ff1RelayerFirmwareUpdateServiceProvider =
    Provider<Ff1RelayerFirmwareUpdateService>((ref) {
      return Ff1RelayerFirmwareUpdateService(ref.watch(ff1WifiControlProvider));
    });
