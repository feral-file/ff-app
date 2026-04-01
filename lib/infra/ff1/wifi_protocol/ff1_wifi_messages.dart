/// FF1 WiFi Protocol: message definitions for device-to-app communication.
///
/// This file defines the message types and payloads exchanged between FF1
/// devices and the mobile app over WiFi (via relayer server or LAN).
///
/// Separation: This is pure protocol - no transport, no Flutter dependencies.
/// Messages can be serialized/deserialized and tested independently.
library;

import 'package:app/domain/models/ff1/art_framing.dart';
import 'package:app/domain/models/ff1/canvas_cast_request_reply.dart';
import 'package:app/domain/models/ff1/device_display_setting.dart';
import 'package:app/domain/models/ff1/loop_mode.dart';
import 'package:app/domain/models/ff1/screen_orientation.dart';
import 'package:app/domain/models/models.dart';

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

/// Notification subtypes (player_status, device_status, connection, FFP DDC).
enum FF1NotificationType {
  /// Player status notification (playback state, current work).
  playerStatus('player_status'),

  /// Device status notification (WiFi, internet, version).
  deviceStatus('device_status'),

  /// FFP display / DDC panel status notification.
  ffpDdcPanelStatus('ddcPanelStatus'),

  /// Same payload as [ffpDdcPanelStatus]; relayer uses this `notification_type`.
  ffpStatusDefault('default'),

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
  FF1PlayerStatus({
    required this.playlistId,
    this.currentWorkIndex,
    bool? isPaused,
    this.deviceSettings,
    this.error,
    this.items,
    this.sleepMode,
    this.shuffle,
    this.loopMode,
  }) : isPaused = isPaused ?? false;

  /// Deserialize from JSON.
  factory FF1PlayerStatus.fromJson(Map<String, dynamic> json) {
    return FF1PlayerStatus(
      playlistId: json['playlistId'] as String?,
      currentWorkIndex: json['index'] as int?,
      isPaused: json['isPaused'] as bool?,
      items: json['items'] != null
          ? (json['items'] as List<dynamic>)
                .map(
                  (item) =>
                      DP1PlaylistItem.fromJson(item as Map<String, dynamic>),
                )
                .toList()
          : null,
      deviceSettings: json['deviceSettings'] != null
          ? DeviceDisplaySetting.fromJson(
              json['deviceSettings'] as Map<String, dynamic>,
            )
          : null,
      error: json['error'] != null
          ? ReplyError.fromString(json['error'] as String)
          : null,
      sleepMode: json['sleepMode'] as bool?,
      shuffle: json['shuffle'] as bool?,
      loopMode: json['loopMode'] != null
          ? LoopMode.fromString(json['loopMode'] as String)
          : null,
    );
  }

  /// Current playlist ID.
  final String? playlistId;

  /// Current work index in playlist.
  final int? currentWorkIndex;

  /// Whether playback is paused.
  final bool isPaused;

  /// Device display settings.
  DeviceDisplaySetting? deviceSettings;

  /// Playlist items.
  final List<DP1PlaylistItem>? items;

  /// Whether device is in sleep mode.
  final bool? sleepMode;

  /// Whether shuffle is enabled.
  final bool? shuffle;

  /// Current loop mode.
  final LoopMode? loopMode;

  /// Error.
  final ReplyError? error;

  /// Serialize to JSON.
  Map<String, dynamic> toJson() => {
    'playlistId': playlistId,
    'index': currentWorkIndex,
    'isPaused': isPaused,
    'deviceSettings': deviceSettings?.toJson(),
    'error': error?.jsonString,
    'sleepMode': sleepMode,
    'items': items?.map((item) => item.toJson()).toList(),
    'shuffle': shuffle,
    'loopMode': loopMode?.wireValue,
  };

  /// Whether device is in sleep mode or paused.
  bool get isSleeping => sleepMode ?? isPaused;
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
    this.volume,
    this.isMuted,
    this.macInfo,
  });

  /// Deserialize from JSON.
  factory FF1DeviceStatus.fromJson(Map<String, dynamic> json) {
    final rawRotation = json['screenRotation'] as String?;
    ScreenOrientation? rotation;
    if (rawRotation != null && rawRotation.isNotEmpty) {
      rotation = _parseScreenOrientation(rawRotation);
    }

    // macInfo is a map from network interface name to MAC address string.
    Map<String, String>? macInfo;
    final rawMac = json['macInfo'];
    if (rawMac is Map) {
      macInfo = rawMac.map(
        (k, v) => MapEntry(k.toString(), v.toString()),
      );
    }

    return FF1DeviceStatus(
      connectedWifi: json['connectedWifi'] as String?,
      screenRotation: rotation,
      installedVersion: json['installedVersion'] as String?,
      latestVersion: json['latestVersion'] as String?,
      internetConnected: json['internetConnected'] as bool?,
      volume: json['volume'] as int?,
      isMuted: json['isMuted'] as bool?,
      macInfo: macInfo,
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

  /// Current volume level (0–100).
  final int? volume;

  /// Whether audio output is muted.
  final bool? isMuted;

  /// MAC addresses keyed by network interface name
  /// (e.g. `{"enp1s0": "10:bb:f3:64:0e:75", "wlp2s0": "40:9c:a7:50:90:21"}`).
  final Map<String, String>? macInfo;

  /// Serialize to JSON.
  Map<String, dynamic> toJson() => {
    'connectedWifi': connectedWifi,
    'screenRotation': screenRotation?.name,
    'installedVersion': installedVersion,
    'latestVersion': latestVersion,
    'internetConnected': internetConnected,
    'volume': volume,
    'isMuted': isMuted,
    'macInfo': macInfo,
  };

  @override
  String toString() =>
      'FF1DeviceStatus(wifi: $connectedWifi, internet: $internetConnected, '
      'volume: $volume, isMuted: $isMuted, macInfo: $macInfo)';
}

ScreenOrientation? _parseScreenOrientation(String value) {
  switch (value) {
    case 'landscape':
    case 'normal':
      return ScreenOrientation.landscape;
    case 'landscapeReverse':
    case 'inverted':
      return ScreenOrientation.landscapeReverse;
    case 'portrait':
    case 'left':
      return ScreenOrientation.portrait;
    case 'portraitReverse':
    case 'right':
      return ScreenOrientation.portraitReverse;
    default:
      return null;
  }
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
class FF1WifiResumeRequest extends FF1WifiCommandRequest {
  /// Creates a resume request.
  const FF1WifiResumeRequest();

  @override
  String get command => 'resume';

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

/// Move to artwork at index (jump to item in playlist).
class FF1WifiMoveToArtworkRequest extends FF1WifiCommandRequest {
  /// Creates a move to artwork request.
  ///
  /// [index] — zero-based index of the artwork in the playlist
  const FF1WifiMoveToArtworkRequest({required this.index});

  /// Index of the artwork in the playlist.
  final int index;

  @override
  String get command => 'moveToArtwork';

  @override
  Map<String, dynamic> get params => {'index': index};
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

/// Shutdown command.
class FF1WifiShutdownRequest extends FF1WifiCommandRequest {
  /// Creates a safe shutdown request.
  const FF1WifiShutdownRequest();

  @override
  String get command => 'shutdown';

  @override
  Map<String, dynamic> get params => {};
}

/// Reboot command.
class FF1WifiRebootRequest extends FF1WifiCommandRequest {
  /// Creates a restart request.
  const FF1WifiRebootRequest();

  @override
  String get command => 'reboot';

  @override
  Map<String, dynamic> get params => {};
}

/// Factory reset command.
class FF1WifiFactoryResetRequest extends FF1WifiCommandRequest {
  /// Creates a factory reset request.
  const FF1WifiFactoryResetRequest();

  @override
  String get command => 'factoryReset';

  @override
  Map<String, dynamic> get params => {};
}

/// Send log command.
class FF1WifiSendLogRequest extends FF1WifiCommandRequest {
  /// Creates a send log request.
  const FF1WifiSendLogRequest({
    required this.userId,
    required this.title,
    required this.apiKey,
  });

  /// User identifier.
  final String userId;

  /// Optional log title.
  final String? title;

  /// Support API key.
  final String apiKey;

  @override
  String get command => 'uploadLogs';

  @override
  Map<String, dynamic> get params => SendLogRequest(
    userId: userId,
    title: title,
    apiKey: apiKey,
  ).toJson();
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

/// Realtime metrics command.
class FF1WifiDeviceMetricsRequest extends FF1WifiCommandRequest {
  /// Creates a realtime metrics request.
  const FF1WifiDeviceMetricsRequest();

  @override
  String get command => 'deviceMetrics';

  @override
  Map<String, dynamic> get params => {};
}

/// Keyboard event command (send key code to device).
/// Command name must match old repo: sendKeyboardEvent.
class FF1WifiKeyboardEventRequest extends FF1WifiCommandRequest {
  /// Creates a keyboard event request.
  ///
  /// [code] — key code (e.g. from [String.codeUnitAt])
  const FF1WifiKeyboardEventRequest({required this.code});

  /// Key code.
  final int code;

  @override
  String get command => 'sendKeyboardEvent';

  @override
  Map<String, dynamic> get params => {'code': code};
}

/// Tap gesture command. Name must match old repo: tapGesture.
class FF1WifiTapRequest extends FF1WifiCommandRequest {
  /// Creates a tap request.
  const FF1WifiTapRequest();

  @override
  String get command => 'tapGesture';

  @override
  Map<String, dynamic> get params => {};
}

/// Drag gesture command (cursor offsets).
/// Command name must match old repo: dragGesture.
/// dx/dy rounded to 2 decimals like old CursorOffset.toJson().
class FF1WifiDragRequest extends FF1WifiCommandRequest {
  /// Creates a drag request.
  ///
  /// [cursorOffsets] — list of cursor offsets
  const FF1WifiDragRequest({required this.cursorOffsets});

  /// Cursor offsets.
  final List<Map<String, double>> cursorOffsets;

  @override
  String get command => 'dragGesture';

  @override
  Map<String, dynamic> get params => {
    'cursorOffsets': cursorOffsets
        .map(
          (o) => {
            'dx': _round2(o['dx']!),
            'dy': _round2(o['dy']!),
          },
        )
        .toList(),
  };
}

double _round2(double v) => double.parse(v.toStringAsFixed(2));

/// Set device volume command.
///
/// [percent] — target volume level, clamped to 0–100.
class FF1WifiSetVolumeRequest extends FF1WifiCommandRequest {
  /// Creates a set-volume request.
  ///
  /// [percent] must be in the range 0–100.
  const FF1WifiSetVolumeRequest({required this.percent});

  /// Target volume level (0–100).
  final int percent;

  @override
  String get command => 'setVolume';

  @override
  Map<String, dynamic> get params => {'percent': percent};
}

/// Toggle mute state on the device.
class FF1WifiToggleMuteRequest extends FF1WifiCommandRequest {
  /// Creates a toggle-mute request.
  const FF1WifiToggleMuteRequest();

  @override
  String get command => 'toggleMute';

  @override
  Map<String, dynamic> get params => {};
}

/// Enable or disable shuffle playback on the device.
class FF1WifiShuffleRequest extends FF1WifiCommandRequest {
  /// Creates a shuffle request.
  ///
  /// [enabled] — true to enable shuffle, false to disable it.
  const FF1WifiShuffleRequest({required this.enabled});

  /// Whether shuffle is enabled.
  final bool enabled;

  @override
  String get command => 'setShuffle';

  @override
  Map<String, dynamic> get params => {'enabled': enabled};
}

/// Set the loop (repeat) mode on the device.
class FF1WifiSetLoopRequest extends FF1WifiCommandRequest {
  /// Creates a set-loop request.
  ///
  /// [mode] — playlist or one.
  const FF1WifiSetLoopRequest({required this.mode});

  /// Loop mode.
  final LoopMode mode;

  @override
  String get command => 'setLoop';

  @override
  Map<String, dynamic> get params => {'mode': mode.wireValue};
}

// ============================================================================
// FFP / DDC monitor (controld via relayer) — not FF1 system audio (ffos#84)
// ============================================================================

/// Poll/read current DDC panel snapshot.
///
/// Wire command name and flat `message` response shape match ffos issue 84
/// (comment describing `ddcPanelStatus` / optional brightness, contrast,
/// volume, mute, power, monitor, errors).
class FfpDdcGetPanelStatusRequest extends FF1WifiCommandRequest {
  /// Creates a get DDC panel status request.
  const FfpDdcGetPanelStatusRequest();

  @override
  String get command => 'ddcPanelStatus';

  @override
  Map<String, dynamic> get params => {};
}

/// Set monitor brightness (VCP) — may return explicit unsupported on FFP.
///
/// Wire: `ddcPanelControl` with `action` + `value` (ffos issue 84 comment).
/// [monitorId] is kept for call-site consistency; not sent until controld
/// defines multi-monitor routing.
class FfpDdcMonitorSetBrightnessRequest extends FF1WifiCommandRequest {
  /// Creates set brightness request.
  const FfpDdcMonitorSetBrightnessRequest({
    required this.monitorId,
    required this.percent,
  });

  /// Reserved for future multi-monitor routing; wire is `action`/`value` only.
  final String monitorId;

  /// 0–100.
  final int percent;

  @override
  String get command => 'ddcPanelControl';

  @override
  Map<String, dynamic> get params => {
    'action': 'brightness',
    'value': percent,
  };
}

/// Set monitor contrast (DDC).
class FfpDdcMonitorSetContrastRequest extends FF1WifiCommandRequest {
  /// Creates set contrast request.
  const FfpDdcMonitorSetContrastRequest({
    required this.monitorId,
    required this.percent,
  });

  /// Target monitor id.
  final String monitorId;

  /// Contrast 0–100.
  final int percent;

  @override
  String get command => 'ddcPanelControl';

  @override
  Map<String, dynamic> get params => {
    'action': 'contrast',
    'value': percent,
  };
}

/// Set monitor speaker / DDC volume — not FF1 [FF1WifiSetVolumeRequest].
class FfpDdcMonitorSetVolumeRequest extends FF1WifiCommandRequest {
  /// Creates set monitor volume request.
  const FfpDdcMonitorSetVolumeRequest({
    required this.monitorId,
    required this.percent,
  });

  /// Target monitor id.
  final String monitorId;

  /// Monitor output volume 0–100 (DDC, not FF1 player).
  final int percent;

  @override
  String get command => 'ddcPanelControl';

  @override
  Map<String, dynamic> get params => {
    'action': 'volume',
    'value': percent,
  };
}

/// Toggle or set DDC monitor mute.
class FfpDdcMonitorSetMuteRequest extends FF1WifiCommandRequest {
  /// Creates set mute request.
  const FfpDdcMonitorSetMuteRequest({
    required this.monitorId,
    required this.muted,
  });

  /// Target monitor id.
  final String monitorId;

  /// Desired mute state for the monitor output.
  final bool muted;

  @override
  String get command => 'ddcPanelControl';

  @override
  Map<String, dynamic> get params => {
    'action': 'mute',
    'value': muted ? 'on' : 'off',
  };
}

/// Power control for the display (on / off / standby).
class FfpDdcMonitorSetPowerRequest extends FF1WifiCommandRequest {
  /// Creates set power request.
  const FfpDdcMonitorSetPowerRequest({
    required this.monitorId,
    required this.powerState,
  });

  final String monitorId;

  /// Wire values: `on`, `off`, `standby`.
  final String powerState;

  @override
  String get command => 'ddcPanelControl';

  @override
  Map<String, dynamic> get params => {
    'action': 'power',
    'value': powerState,
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
    final statusFromTopLevel = json['status'] as String?;
    final dataFromTopLevel = json['data'] as Map<String, dynamic>?;

    if (statusFromTopLevel != null || dataFromTopLevel != null) {
      return FF1CommandResponse(
        status: statusFromTopLevel,
        data: dataFromTopLevel,
      );
    }

    final nestedOk = _extractNestedOkValue(json);
    if (nestedOk != null) {
      return FF1CommandResponse(
        status: nestedOk ? 'ok' : 'error',
        data: json,
      );
    }

    final message = json['message'];
    if (message is Map) {
      final payload = Map<String, dynamic>.from(message);
      final ok = payload['ok'];
      if (ok is bool) {
        return FF1CommandResponse(
          status: ok ? 'ok' : 'error',
          data: payload,
        );
      }
      return FF1CommandResponse(data: payload);
    }

    if (json['error'] is Map) {
      return FF1CommandResponse(
        status: 'error',
        data: Map<String, dynamic>.from(json['error'] as Map),
      );
    }

    return FF1CommandResponse();
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

bool? _extractNestedOkValue(Map<String, dynamic> payload) {
  final directOk = payload['ok'];
  if (directOk is bool) {
    return directOk;
  }

  final nestedMessage = payload['message'];
  if (nestedMessage is Map) {
    return _extractNestedOkValue(Map<String, dynamic>.from(nestedMessage));
  }

  return null;
}
