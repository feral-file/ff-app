/// FF1 BLE command definitions and request/response types
///
/// This file defines all available FF1 commands and their typed request/response
/// payloads. Each command has:
/// - A wire name (what gets sent over BLE)
/// - A request type (parameters to send)
/// - A response type (parsed result)
library;

/// Available FF1 BLE commands
enum FF1BleCommand {
  /// Send WiFi credentials (SSID + password)
  sendWifiCredentials('connect_wifi'),

  /// Scan for available WiFi networks
  scanWifi('scan_wifi'),

  /// Keep current WiFi connection (get topicId)
  keepWifi('keep_wifi'),

  /// Get device information
  getInfo('get_info'),

  /// Factory reset device
  factoryReset('factory_reset'),

  /// Update to latest version
  updateToLatestVersion('update_to_latest_version'),

  /// Send device logs to support
  sendLog('send_log'),

  /// Set device timezone
  setTimezone('set_time'),
  ;

  const FF1BleCommand(this.wireName);

  /// Command name sent over the wire
  final String wireName;
}

// ============================================================================
// Request types
// ============================================================================

/// Base class for FF1 BLE requests
abstract class FF1BleRequest {
  const FF1BleRequest();

  /// Convert request to parameter list (for protocol encoding)
  List<String> toParams();
}

/// Send WiFi credentials (SSID + password)
class SendWifiCredentialsRequest extends FF1BleRequest {
  const SendWifiCredentialsRequest({
    required this.ssid,
    required this.password,
  });

  final String ssid;
  final String password;

  @override
  List<String> toParams() => [ssid, password];
}

/// Scan for available WiFi networks
class ScanWifiRequest extends FF1BleRequest {
  const ScanWifiRequest();

  @override
  List<String> toParams() => [];
}

/// Keep current WiFi connection (get topicId)
class KeepWifiRequest extends FF1BleRequest {
  const KeepWifiRequest();

  @override
  List<String> toParams() => [];
}

/// Get device information
class GetInfoRequest extends FF1BleRequest {
  const GetInfoRequest();

  @override
  List<String> toParams() => [];
}

/// Factory reset device
class FactoryResetRequest extends FF1BleRequest {
  const FactoryResetRequest();

  @override
  List<String> toParams() => [];
}

/// Update to latest version
class UpdateToLatestVersionRequest extends FF1BleRequest {
  /// Constructor
  const UpdateToLatestVersionRequest();

  @override
  List<String> toParams() => [];
}

/// Send device logs to support
class SendLogRequest extends FF1BleRequest {
  const SendLogRequest({
    required this.userId,
    required this.title,
    required this.apiKey,
  });

  final String userId;
  final String title;
  final String apiKey;

  @override
  List<String> toParams() => [userId, title, apiKey];
}

/// Set device timezone
class SetTimezoneRequest extends FF1BleRequest {
  SetTimezoneRequest({
    required this.timezone,
    DateTime? time,
  }) : time = time ?? DateTime.now();

  final String timezone;
  final DateTime time;

  @override
  List<String> toParams() => [
    timezone,
    _formatDateTime(time),
  ];

  static String _formatDateTime(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-'
        '${dt.day.toString().padLeft(2, '0')} '
        '${dt.hour.toString().padLeft(2, '0')}:'
        '${dt.minute.toString().padLeft(2, '0')}:'
        '${dt.second.toString().padLeft(2, '0')}';
  }
}

// ============================================================================
// Response types
// ============================================================================

/// Base class for FF1 BLE responses
abstract class FF1BleCommandResponse {
  const FF1BleCommandResponse();
}

/// Empty response (for commands that don't return data)
class EmptyResponse extends FF1BleCommandResponse {
  const EmptyResponse();
}

/// Send WiFi credentials response (returns topicId)
class SendWifiCredentialsResponse extends FF1BleCommandResponse {
  const SendWifiCredentialsResponse({required this.topicId});

  final String topicId;
}

/// Scan WiFi response (list of SSIDs)
class ScanWifiResponse extends FF1BleCommandResponse {
  const ScanWifiResponse({required this.ssids});

  final List<String> ssids;
}

/// Keep WiFi response (returns topicId)
class KeepWifiResponse extends FF1BleCommandResponse {
  const KeepWifiResponse({required this.topicId});

  final String topicId;
}

/// Get device info response
class GetInfoResponse extends FF1BleCommandResponse {
  const GetInfoResponse({required this.deviceInfoString});

  final String deviceInfoString;
}

/// Factory reset response
class FactoryResetResponse extends FF1BleCommandResponse {
  const FactoryResetResponse();
}

/// Update to latest version response
class UpdateToLatestVersionResponse extends FF1BleCommandResponse {
  /// Constructor
  const UpdateToLatestVersionResponse();
}

/// Send log response
class SendLogResponse extends FF1BleCommandResponse {
  const SendLogResponse();
}

/// Set timezone response
class SetTimezoneResponse extends FF1BleCommandResponse {
  const SetTimezoneResponse();
}
