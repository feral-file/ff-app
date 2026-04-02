/// DDC panel snapshot from relayer notifications only (`notification_type`
/// `ddc_status`), flat `message` (ffos#84).
///
/// Distinct from FF1 system audio (`FF1DeviceStatus.volume` / `setVolume`).
library;

/// DDC monitor power state from relayer `power` (ffos#84).
enum FfpDdcPanelPower {
  /// Powered on.
  on,

  /// Powered off.
  off,

  /// Standby or suspend.
  standby;

  /// Canonical wire string for REST/commands.
  String get wireValue => switch (this) {
        FfpDdcPanelPower.on => 'on',
        FfpDdcPanelPower.off => 'off',
        FfpDdcPanelPower.standby => 'standby',
      };

  /// Parses relayer/command strings (case-insensitive; accepts `poweron`, etc.).
  static FfpDdcPanelPower? tryParse(Object? raw) {
    if (raw == null) {
      return null;
    }
    final s = raw.toString().trim().toLowerCase();
    switch (s) {
      case 'on':
      case 'poweron':
        return FfpDdcPanelPower.on;
      case 'off':
      case 'poweroff':
        return FfpDdcPanelPower.off;
      case 'standby':
      case 'suspend':
        return FfpDdcPanelPower.standby;
      default:
        return null;
    }
  }
}

/// Parsed relayer `message` for the connected display (flat JSON).
class FfpDdcPanelStatus {
  /// Creates a DDC panel snapshot (typically deserialized with `fromJson`).
  const FfpDdcPanelStatus({
    this.brightness,
    this.contrast,
    this.volume,
    this.mute,
    this.power,
    this.monitor,
  });

  /// Parses flat relayer `message` JSON (ffos#84).
  factory FfpDdcPanelStatus.fromJson(Map<String, dynamic> json) {
    if (json.isEmpty) {
      return const FfpDdcPanelStatus();
    }
    return FfpDdcPanelStatus(
      brightness: _parsePercent(json['brightness']),
      contrast: _parsePercent(json['contrast']),
      volume: _parsePercent(json['volume']),
      mute: _parseMute(json['mute']),
      power: FfpDdcPanelPower.tryParse(json['power']),
      monitor: json['monitor'] as String?,
    );
  }

  /// Serializes panel fields for debugging or round-trip tests.
  Map<String, dynamic> toJson() {
    return {
      'brightness': brightness,
      'contrast': contrast,
      'volume': volume,
      'mute': mute == null ? null : (mute! ? 'on' : 'off'),
      'power': power?.wireValue,
      'monitor': monitor,
    };
  }

  /// 0–100 when read succeeded.
  final int? brightness;

  /// 0–100 when read succeeded.
  final int? contrast;

  /// DDC / monitor speaker volume 0–100 — not FF1 player volume.
  final int? volume;

  /// Mute when read succeeded (`mute` wire: `on` / `off`).
  final bool? mute;

  /// Power state when read succeeded.
  final FfpDdcPanelPower? power;

  /// `Vendor:Model` from controld (`ddcutil detect --brief`).
  final String? monitor;

  /// True when there is any field to show (non-null values or monitor name).
  bool get hasData =>
      brightness != null ||
      contrast != null ||
      volume != null ||
      mute != null ||
      power != null ||
      (monitor != null && monitor!.trim().isNotEmpty);

  /// Merge updates (e.g. after a DDC write while a refresh is in flight).
  FfpDdcPanelStatus copyWith({
    int? brightness,
    int? contrast,
    int? volume,
    bool? mute,
    FfpDdcPanelPower? power,
    String? monitor,
  }) {
    return FfpDdcPanelStatus(
      brightness: brightness ?? this.brightness,
      contrast: contrast ?? this.contrast,
      volume: volume ?? this.volume,
      mute: mute ?? this.mute,
      power: power ?? this.power,
      monitor: monitor ?? this.monitor,
    );
  }
}

bool? _parseMute(Object? raw) {
  if (raw == null) {
    return null;
  }
  if (raw is bool) {
    return raw;
  }
  final s = raw.toString().trim().toLowerCase();
  if (s == 'on') {
    return true;
  }
  if (s == 'off') {
    return false;
  }
  return null;
}

int? _parsePercent(Object? raw) {
  if (raw == null) {
    return null;
  }
  if (raw is int) {
    return raw.clamp(0, 100);
  }
  if (raw is double) {
    return raw.round().clamp(0, 100);
  }
  final p = int.tryParse(raw.toString());
  return p?.clamp(0, 100);
}
