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
