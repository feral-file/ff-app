/// FF1 command definitions and request/response types
///
/// This file defines all available FF1 commands and their typed request/response
/// payloads. Each command has:
/// - A wire name (what gets sent over BLE)
/// - A request type (parameters to send)
/// - A response type (parsed result)

/// Available FF1 commands
enum FF1Command {
  sendWifiCredentials('connect_wifi'),
  scanWifi('scan_wifi'),
  keepWifi('keep_wifi'),
  getInfo('get_info'),
  factoryReset('factory_reset'),
  sendLog('send_log'),
  setTimezone('set_time');

  const FF1Command(this.wireName);

  /// Command name sent over the wire
  final String wireName;
}

// ============================================================================
// Request types
// ============================================================================

/// Base class for FF1 requests
abstract class FF1Request {
  const FF1Request();

  /// Convert request to parameter list (for protocol encoding)
  List<String> toParams();
}

/// Send WiFi credentials (SSID + password)
class SendWifiCredentialsRequest extends FF1Request {
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
class ScanWifiRequest extends FF1Request {
  const ScanWifiRequest();

  @override
  List<String> toParams() => [];
}

/// Keep current WiFi connection (get topicId)
class KeepWifiRequest extends FF1Request {
  const KeepWifiRequest();

  @override
  List<String> toParams() => [];
}

/// Get device information
class GetInfoRequest extends FF1Request {
  const GetInfoRequest();

  @override
  List<String> toParams() => [];
}

/// Factory reset device
class FactoryResetRequest extends FF1Request {
  const FactoryResetRequest();

  @override
  List<String> toParams() => [];
}

/// Send device logs to support
class SendLogRequest extends FF1Request {
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
class SetTimezoneRequest extends FF1Request {
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

/// Base class for FF1 responses
abstract class FF1CommandResponse {
  const FF1CommandResponse();
}

/// Empty response (for commands that don't return data)
class EmptyResponse extends FF1CommandResponse {
  const EmptyResponse();
}

/// Send WiFi credentials response (returns topicId)
class SendWifiCredentialsResponse extends FF1CommandResponse {
  const SendWifiCredentialsResponse({required this.topicId});

  final String topicId;
}

/// Scan WiFi response (list of SSIDs)
class ScanWifiResponse extends FF1CommandResponse {
  const ScanWifiResponse({required this.ssids});

  final List<String> ssids;
}

/// Keep WiFi response (returns topicId)
class KeepWifiResponse extends FF1CommandResponse {
  const KeepWifiResponse({required this.topicId});

  final String topicId;
}

/// Get device info response
class GetInfoResponse extends FF1CommandResponse {
  const GetInfoResponse({required this.deviceInfoString});

  final String deviceInfoString;
}

/// Factory reset response
class FactoryResetResponse extends FF1CommandResponse {
  const FactoryResetResponse();
}

/// Send log response
class SendLogResponse extends FF1CommandResponse {
  const SendLogResponse();
}

/// Set timezone response
class SetTimezoneResponse extends FF1CommandResponse {
  const SetTimezoneResponse();
}
