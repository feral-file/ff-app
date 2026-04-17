import 'package:app/domain/ff1/ff1_pairing_qr_display.dart';
import 'package:app/infra/ff1/wifi_protocol/ff1_wifi_messages.dart';

/// Pairing QR visibility derived from relayer `displayURL` on device status.
extension FF1DeviceStatusPairingQr on FF1DeviceStatus {
  /// Whether the pairing QR UI is currently shown, inferred from [displayUrl].
  ///
  /// `null` when [displayUrl] is absent or empty — keep existing UI state.
  bool? get isPairingQrShowing {
    final url = displayUrl;
    if (url == null || url.isEmpty) {
      return null;
    }
    return isPairingQrStepInDisplayUrl(url);
  }
}
