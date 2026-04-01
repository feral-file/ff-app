/// Snapshot from FF1 `ddcPanelStatus` command (flat `message`, ffos#84).
///
/// Relayer may send `notification_type: "default"` with the same flat `message`
/// shape (brightness, contrast, volume, power, monitor, errors, …).
///
/// Distinct from FF1 system audio (`FF1DeviceStatus.volume` / `setVolume`).
library;

/// Parsed `ddcPanelStatus` / unwrapped relayer `message` for the connected display.
class FfpDdcPanelStatus {
  /// Creates a DDC panel snapshot (typically from `fromRelayerPayload`).
  const FfpDdcPanelStatus({
    this.brightness,
    this.contrast,
    this.volume,
    this.mute,
    this.power,
    this.monitor,
    this.errors,
  });

  /// After relayer unwrap: flat `message`, or nested `ddcPanelStatus` map.
  factory FfpDdcPanelStatus.fromRelayerPayload(Map<String, dynamic> json) {
    if (json.isEmpty) {
      return const FfpDdcPanelStatus();
    }
    final nested = json['ddcPanelStatus'];
    if (nested is Map) {
      return FfpDdcPanelStatus._fromWireMap(
        Map<String, dynamic>.from(nested),
      );
    }
    return FfpDdcPanelStatus._fromWireMap(json);
  }

  factory FfpDdcPanelStatus._fromWireMap(Map<String, dynamic> m) {
    final errRaw = m['errors'];
    Map<String, String>? errMap;
    if (errRaw is Map) {
      errMap = {};
      for (final e in errRaw.entries) {
        errMap[e.key.toString()] = e.value?.toString() ?? '';
      }
    }
    return FfpDdcPanelStatus(
      brightness: _parsePercent(m['brightness']),
      contrast: _parsePercent(m['contrast']),
      volume: _parsePercent(m['volume']),
      mute: _parseMute(m['mute']),
      power: m['power']?.toString(),
      monitor: m['monitor'] as String?,
      errors: errMap,
    );
  }

  /// 0–100 when read succeeded.
  final int? brightness;

  /// 0–100 when read succeeded.
  final int? contrast;

  /// DDC / monitor speaker volume 0–100 — not FF1 player volume.
  final int? volume;

  /// Mute when read succeeded (`mute` wire: `on` / `off`).
  final bool? mute;

  /// Wire values: `on`, `off`, `standby`, etc.
  final String? power;

  /// `Vendor:Model` from controld (`ddcutil detect --brief`).
  final String? monitor;

  /// Field name → error message when that VCP read failed.
  final Map<String, String>? errors;

  /// True when there is anything to show (values, monitor id, or read errors).
  bool get hasData =>
      brightness != null ||
      contrast != null ||
      volume != null ||
      mute != null ||
      power != null ||
      (monitor != null && monitor!.trim().isNotEmpty) ||
      (errors != null && errors!.isNotEmpty);

  /// Merge updates (e.g. after a DDC write while a refresh is in flight).
  FfpDdcPanelStatus copyWith({
    int? brightness,
    int? contrast,
    int? volume,
    bool? mute,
    String? power,
    String? monitor,
    Map<String, String>? errors,
  }) {
    return FfpDdcPanelStatus(
      brightness: brightness ?? this.brightness,
      contrast: contrast ?? this.contrast,
      volume: volume ?? this.volume,
      mute: mute ?? this.mute,
      power: power ?? this.power,
      monitor: monitor ?? this.monitor,
      errors: errors ?? this.errors,
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
