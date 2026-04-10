import 'package:app/domain/models/ff1_device_info.dart';

/// Deeplink-derived readiness for guided setup UI.
extension FF1DeviceInfoPortalX on FF1DeviceInfo {
  /// True when the deeplink indicates topic is present and the device is
  /// online.
  ///
  /// Used to decide portal-all-set presentation without extra setup state
  /// flags.
  bool get isPortalAllSet => topicId.isNotEmpty && isConnectedToInternet;
}
