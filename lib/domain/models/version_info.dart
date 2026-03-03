/// Version info for force app update.
///
/// Contains the minimum required version and store link for the user to update.
class VersionInfo {
  /// Creates a [VersionInfo].
  const VersionInfo({
    required this.requiredVersion,
    required this.link,
  });

  /// Minimum required app version (e.g. "1.0.5" or "1.0.5(123)").
  final String requiredVersion;

  /// Store URL to open for update (App Store or Play Store).
  final String link;
}
