/// Model for a WiFi access point
class WifiPoint {
  /// Create a WifiPoint
  const WifiPoint(this.ssid, {this.isOpenNetwork});

  /// Create a WifiPoint from a WiFi scan result
  factory WifiPoint.fromWifiScanResult(String result) {
    // Backward compatibility: if result doesn't have format "ssid|security",
    // treat entire result as SSID and assume it's not an open network
    if (!result.contains('|')) {
      return WifiPoint(result, isOpenNetwork: false);
    }

    final parts = result.split('|');
    final ssid = parts.isNotEmpty ? parts.first : '';
    final security = parts.length > 1 ? parts[1].trim().toUpperCase() : '';
    final isOpenNetwork = security == 'OPEN';
    return WifiPoint(
      ssid,
      isOpenNetwork: isOpenNetwork,
    );
  }

  /// The SSID of the WiFi access point
  final String ssid;

  /// Whether the WiFi access point is open network
  final bool? isOpenNetwork;
}
