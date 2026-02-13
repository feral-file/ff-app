/// FF1 WiFi Protocol: message definitions for device-to-app communication.
///
/// This file defines the message types and payloads exchanged between FF1
/// devices and the mobile app over WiFi (via relayer server or LAN).
///
/// Separation: This is pure protocol - no transport, no Flutter dependencies.
/// Messages can be serialized/deserialized and tested independently.
library;

import 'package:app/domain/models/dp1/dp1_playlist_item.dart';
import 'package:app/domain/models/ff1/art_framing.dart';
import 'package:app/domain/models/ff1/screen_orientation.dart';

// ============================================================================
// Message envelope types (top-level message wrapper)
// ============================================================================

/// Top-level message type (notification, RPC, etc.)
enum FF1WifiMessageType {
  /// Device-to-app notification (player status, device status, connection).
  notification('notification'),

  /// App-to-device RPC command (future).
  rpc('RPC')
  ;

  const FF1WifiMessageType(this.value);

  /// Wire format value.
  final String value;

  /// Parse from wire format value.
  static FF1WifiMessageType fromString(String value) {
    for (final type in FF1WifiMessageType.values) {
      if (type.value == value) {
        return type;
      }
    }
    throw ArgumentError('Unknown FF1WifiMessageType: $value');
  }
}

/// Notification subtypes (player_status, device_status, connection).
enum FF1NotificationType {
  /// Player status notification (playback state, current work).
  playerStatus('player_status'),

  /// Device status notification (WiFi, internet, version).
  deviceStatus('device_status'),

  /// Connection status notification (device online/offline).
  connection('connection')
  ;

  const FF1NotificationType(this.value);

  /// Wire format value.
  final String value;

  /// Parse from wire format value.
  static FF1NotificationType fromString(String value) {
    for (final type in FF1NotificationType.values) {
      if (type.value == value) {
        return type;
      }
    }
    throw ArgumentError('Unknown FF1NotificationType: $value');
  }
}

// ============================================================================
// Base message class
// ============================================================================

/// Base class for all FF1 WiFi messages.
abstract class FF1WifiMessage {
  /// Creates an FF1 WiFi message.
  const FF1WifiMessage({
    required this.type,
    required this.message,
  });

  /// Message type (notification, RPC).
  final FF1WifiMessageType type;

  /// Message payload.
  final Map<String, dynamic> message;

  /// Serialize to JSON.
  Map<String, dynamic> toJson();
}

// ============================================================================
// Notification message (device → app status updates)
// ============================================================================

/// Notification message from device.
class FF1NotificationMessage extends FF1WifiMessage {
  /// Creates a notification message.
  const FF1NotificationMessage({
    required super.type,
    required super.message,
    required this.notificationType,
    required this.timestamp,
  });

  /// Deserialize from JSON.
  factory FF1NotificationMessage.fromJson(Map<String, dynamic> json) {
    return FF1NotificationMessage(
      type: FF1WifiMessageType.fromString(json['type'] as String),
      message: json['message'] as Map<String, dynamic>,
      notificationType: FF1NotificationType.fromString(
        json['notification_type'] as String,
      ),
      timestamp: DateTime.fromMillisecondsSinceEpoch(
        json['timestamp'] as int,
      ),
    );
  }

  /// Notification subtype.
  final FF1NotificationType notificationType;

  /// Message timestamp.
  final DateTime timestamp;

  @override
  Map<String, dynamic> toJson() {
    return {
      'type': type.value,
      'message': message,
      'notification_type': notificationType.value,
      'timestamp': timestamp.millisecondsSinceEpoch,
    };
  }

  @override
  String toString() =>
      'FF1NotificationMessage(type: $notificationType, timestamp: $timestamp)';
}

// ============================================================================
// RPC message (future: app → device commands)
// ============================================================================

/// RPC message for app-to-device commands (future).
class FF1RpcMessage extends FF1WifiMessage {
  /// Creates an RPC message.
  const FF1RpcMessage({
    required super.type,
    required super.message,
  });

  /// Deserialize from JSON.
  factory FF1RpcMessage.fromJson(Map<String, dynamic> json) {
    return FF1RpcMessage(
      type: FF1WifiMessageType.fromString(json['type'] as String),
      message: json['message'] as Map<String, dynamic>,
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      'type': type.value,
      'message': message,
    };
  }
}

// ============================================================================
// Typed notification payloads
// ============================================================================

/// Player status notification payload.
class FF1PlayerStatus {
  /// Creates a player status.
  const FF1PlayerStatus({
    required this.playlistId,
    this.currentWorkIndex,
    this.isPaused = false,
    this.connectedDeviceId,
    this.items,
  });

  /// Deserialize from JSON.
  factory FF1PlayerStatus.fromJson(Map<String, dynamic> json) {
    return FF1PlayerStatus(
      playlistId: json['playlistId'] as String?,
      currentWorkIndex: json['index'] as int?,
      isPaused: json['isPaused'] as bool? ?? false,
      connectedDeviceId: json['connectedDevice']?['device_id'] as String?,
      items: json['items'] != null
          ? (json['items'] as List<dynamic>)
                .map(
                  (item) =>
                      DP1PlaylistItem.fromJson(item as Map<String, dynamic>),
                )
                .toList()
          : null,
    );
  }

  /// Current playlist ID.
  final String? playlistId;

  /// Current work index in playlist.
  final int? currentWorkIndex;

  /// Whether playback is paused.
  final bool isPaused;

  /// Connected device ID.
  final String? connectedDeviceId;

  /// Playlist items.
  final List<DP1PlaylistItem>? items;

  /// Serialize to JSON.
  Map<String, dynamic> toJson() => {
    'playlistId': playlistId,
    'index': currentWorkIndex,
    'isPaused': isPaused,
    'connectedDevice': connectedDeviceId != null
        ? {'device_id': connectedDeviceId}
        : null,
    'items': items?.map((item) => item.toJson()).toList(),
  };

  @override
  String toString() =>
      'FF1PlayerStatus(playlist: $playlistId, index: $currentWorkIndex, '
      'paused: $isPaused)';
}

/// Device status notification payload.
class FF1DeviceStatus {
  /// Creates a device status.
  const FF1DeviceStatus({
    this.connectedWifi,
    this.screenRotation,
    this.installedVersion,
    this.latestVersion,
    this.internetConnected,
  });

  /// Deserialize from JSON.
  factory FF1DeviceStatus.fromJson(Map<String, dynamic> json) {
    final rawRotation = json['screenRotation'] as String?;
    ScreenOrientation? rotation;
    if (rawRotation != null && rawRotation.isNotEmpty) {
      try {
        rotation = ScreenOrientation.fromString(rawRotation);
      } on ArgumentError {
        rotation = null;
      }
    }

    return FF1DeviceStatus(
      connectedWifi: json['connectedWifi'] as String?,
      screenRotation: rotation,
      installedVersion: json['installedVersion'] as String?,
      latestVersion: json['latestVersion'] as String?,
      internetConnected: json['internetConnected'] as bool?,
    );
  }

  /// Connected WiFi network.
  final String? connectedWifi;

  /// Screen rotation (landscape, portrait).
  final ScreenOrientation? screenRotation;

  /// Installed version.
  final String? installedVersion;

  /// Latest available version.
  final String? latestVersion;

  /// Whether device has internet connection.
  final bool? internetConnected;

  /// Serialize to JSON.
  Map<String, dynamic> toJson() => {
    'connectedWifi': connectedWifi,
    'screenRotation': screenRotation?.name,
    'installedVersion': installedVersion,
    'latestVersion': latestVersion,
    'internetConnected': internetConnected,
  };

  @override
  String toString() =>
      'FF1DeviceStatus(wifi: $connectedWifi, internet: $internetConnected)';
}

/// Connection status notification payload.
class FF1ConnectionStatus {
  /// Creates a connection status.
  const FF1ConnectionStatus({required this.isConnected});

  /// Deserialize from JSON.
  factory FF1ConnectionStatus.fromJson(Map<String, dynamic> json) {
    return FF1ConnectionStatus(
      isConnected: json['isConnected'] as bool,
    );
  }

  /// Whether device is connected.
  final bool isConnected;

  /// Serialize to JSON.
  Map<String, dynamic> toJson() => {
    'isConnected': isConnected,
  };

  @override
  String toString() => 'FF1ConnectionStatus(connected: $isConnected)';
}

// ============================================================================
// WiFi Command Request/Response Types (App → Device via REST API)
// ============================================================================

/// Base class for WiFi command requests sent via REST API.
abstract class FF1WifiCommandRequest {
  /// Creates a command request.
  const FF1WifiCommandRequest();

  /// Command name (e.g., 'rotate', 'pause', 'play').
  String get command;

  /// Command-specific parameters.
  Map<String, dynamic> get params;

  /// Convert to JSON for sending via API.
  Map<String, dynamic> toJson() => {
    'command': command,
    'params': params,
  };
}

/// Rotate device command.
class FF1WifiRotateRequest extends FF1WifiCommandRequest {
  /// Creates a rotate request.
  ///
  /// [angle] — rotation angle in degrees (optional, default 90)
  const FF1WifiRotateRequest({this.angle = 90});

  /// Rotation angle in degrees.
  final int angle;

  @override
  String get command => 'rotate';

  @override
  Map<String, dynamic> get params => {'angle': angle};
}

/// Pause playback command.
class FF1WifiPauseRequest extends FF1WifiCommandRequest {
  /// Creates a pause request.
  const FF1WifiPauseRequest();

  @override
  String get command => 'pause';

  @override
  Map<String, dynamic> get params => {};
}

/// Resume/play command.
class FF1WifiPlayRequest extends FF1WifiCommandRequest {
  /// Creates a play/resume request.
  const FF1WifiPlayRequest();

  @override
  String get command => 'play';

  @override
  Map<String, dynamic> get params => {};
}

/// Next artwork command.
class FF1WifiNextArtworkRequest extends FF1WifiCommandRequest {
  /// Creates a next artwork request.
  const FF1WifiNextArtworkRequest();

  @override
  String get command => 'nextArtwork';

  @override
  Map<String, dynamic> get params => {};
}

/// Previous artwork command.
class FF1WifiPreviousArtworkRequest extends FF1WifiCommandRequest {
  /// Creates a previous artwork request.
  const FF1WifiPreviousArtworkRequest();

  @override
  String get command => 'previousArtwork';

  @override
  Map<String, dynamic> get params => {};
}

/// Show/hide pairing QR code command.
class FF1WifiShowPairingQRCodeRequest extends FF1WifiCommandRequest {
  /// Creates a show/hide pairing QR code request.
  ///
  /// [show] — true to show QR code, false to hide it
  const FF1WifiShowPairingQRCodeRequest({required this.show});

  /// Whether to show (true) or hide (false) the QR code.
  final bool show;

  @override
  String get command => 'showPairingQRCode';

  @override
  Map<String, dynamic> get params => {'show': show};
}

/// Update art framing (fit/fill) command.
class FF1WifiUpdateArtFramingRequest extends FF1WifiCommandRequest {
  /// Creates an update art framing request.
  ///
  /// [framing] — fitToScreen (0) or cropToFill (1)
  const FF1WifiUpdateArtFramingRequest({required this.framing});

  /// Art framing mode.
  final ArtFraming framing;

  @override
  String get command => 'updateArtFraming';

  @override
  Map<String, dynamic> get params => {'frameConfig': framing.value};
}

/// Keyboard event command (send key code to device).
class FF1WifiKeyboardEventRequest extends FF1WifiCommandRequest {
  const FF1WifiKeyboardEventRequest({required this.code});

  final int code;

  @override
  String get command => 'keyboardEvent';

  @override
  Map<String, dynamic> get params => {'code': code};
}

/// Tap gesture command.
class FF1WifiTapRequest extends FF1WifiCommandRequest {
  const FF1WifiTapRequest();

  @override
  String get command => 'tap';

  @override
  Map<String, dynamic> get params => {};
}

/// Drag gesture command (cursor offsets).
class FF1WifiDragRequest extends FF1WifiCommandRequest {
  const FF1WifiDragRequest({required this.cursorOffsets});

  final List<Map<String, double>> cursorOffsets;

  @override
  String get command => 'drag';

  @override
  Map<String, dynamic> get params => {
        'cursorOffsets': cursorOffsets
            .map((o) => {
                  'dx': o['dx']!,
                  'dy': o['dy']!,
                })
            .toList(),
      };
}

/// Base class for command responses.
class FF1CommandResponse {
  /// Creates a command response.
  FF1CommandResponse({
    this.status,
    this.data,
  });

  /// Deserialize from JSON response.
  factory FF1CommandResponse.fromJson(Map<String, dynamic> json) {
    return FF1CommandResponse(
      status: json['status'] as String?,
      data: json['data'] as Map<String, dynamic>?,
    );
  }

  /// Response status (e.g., 'ok', 'error').
  final String? status;

  /// Response data payload.
  final Map<String, dynamic>? data;

  /// Serialize to JSON.
  Map<String, dynamic> toJson() => {
    if (status != null) 'status': status,
    if (data != null) 'data': data,
  };

  @override
  String toString() => 'FF1CommandResponse(status: $status, data: $data)';
}
