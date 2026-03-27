import 'package:app/domain/constants/deeplink_constants.dart';

/// FF1 device info model
///
/// Represents the information about a FF1 device.
class FF1DeviceInfo {
  /// Creates a FF1 device info.
  const FF1DeviceInfo({
    required this.deviceId,
    required this.topicId,
    required this.isConnectedToInternet,
    required this.branchName,
    required this.version,
  });

  /// Parses pipe-delimited path data (same format as legacy deeplink path
  /// segments).
  factory FF1DeviceInfo.fromEncodedPath(String encodedPath) {
    final decoded = Uri.decodeFull(encodedPath);
    final data = decoded.split('|');
    if (data.length <= 1) {
      return FF1DeviceInfo(
        deviceId: 'FF1',
        topicId: _part(data, 0) ?? '',
        isConnectedToInternet: false,
        branchName: 'release',
        version: '1.0.0', // default version
      );
    }

    return FF1DeviceInfo(
      deviceId: _part(data, 0) ?? 'FF1',
      topicId: _part(data, 1) ?? '',
      isConnectedToInternet: _part(data, 2) == 'true',
      branchName: _part(data, 3) ?? 'release',
      version: _part(data, 4) ?? '',
    );
  }

  /// Parses [FF1DeviceInfo] from a device-connect deeplink.
  ///
  /// Returns null if [deeplink] does not use a known
  /// [deviceConnectDeepLinks] prefix.
  static FF1DeviceInfo? fromDeeplink(String deeplink) {
    final prefix = deviceConnectDeepLinks.firstWhere(
      (value) => deeplink.startsWith(value),
      orElse: () => '',
    );
    if (prefix.isEmpty) {
      return null;
    }

    var path = deeplink.replaceFirst(prefix, '');
    if (path.startsWith('/')) {
      path = path.substring(1);
    }
    return FF1DeviceInfo.fromEncodedPath(path);
  }

  static String? _part(List<String> data, int index) =>
      index < data.length ? data[index] : null;

  /// The name of the device.
  String get name => deviceId;

  /// The device ID.
  final String deviceId;

  /// The topic ID.
  final String topicId;

  /// Whether the device is connected to the internet.
  final bool isConnectedToInternet;

  /// The branch name.
  final String branchName;

  /// The version.
  final String version;
}
