/// FFP display / DDC monitor snapshot (ffos#84).
///
/// Distinct from FF1 system audio (`FF1DeviceStatus.volume` / `setVolume`).
library;

/// Power state reported for a connected display (DDC / panel).
enum FfpDdcPowerState {
  on,
  off,
  standby,
}

/// Per-monitor capability flags from controld (explicit unsupported vs supported).
class FfpDdcPanelCapabilities {
  const FfpDdcPanelCapabilities({
    this.brightnessSupported,
    this.contrastSupported,
    this.volumeSupported,
    this.muteSupported,
    this.powerSupported,
  });

  factory FfpDdcPanelCapabilities.fromJson(Map<String, dynamic>? json) {
    if (json == null || json.isEmpty) {
      return const FfpDdcPanelCapabilities();
    }
    bool? read(String key) {
      final v = json[key];
      if (v is bool) {
        return v;
      }
      return null;
    }

    return FfpDdcPanelCapabilities(
      brightnessSupported: read('brightness'),
      contrastSupported: read('contrast'),
      volumeSupported: read('volume'),
      muteSupported: read('mute'),
      powerSupported: read('power'),
    );
  }

  /// When null, treat as supported unless UI chooses a stricter default.
  final bool? brightnessSupported;
  final bool? contrastSupported;
  final bool? volumeSupported;
  final bool? muteSupported;
  final bool? powerSupported;

  bool isSupported(String feature) {
    switch (feature) {
      case 'brightness':
        return brightnessSupported ?? true;
      case 'contrast':
        return contrastSupported ?? true;
      case 'volume':
        return volumeSupported ?? true;
      case 'mute':
        return muteSupported ?? true;
      case 'power':
        return powerSupported ?? true;
      default:
        return true;
    }
  }
}

/// One physical or logical monitor exposed via DDC.
class FfpDdcMonitorPanel {
  const FfpDdcMonitorPanel({
    required this.monitorId,
    this.displayName,
    this.powerState,
    this.brightnessPercent,
    this.contrastPercent,
    this.monitorVolumePercent,
    this.isMuted,
    this.capabilities = const FfpDdcPanelCapabilities(),
  });

  factory FfpDdcMonitorPanel.fromJson(Map<String, dynamic> json) {
    return FfpDdcMonitorPanel(
      monitorId: json['monitorId']?.toString() ?? json['id']?.toString() ?? '',
      displayName: json['displayName'] as String? ?? json['name'] as String?,
      powerState: _parsePower(json['powerState'] ?? json['power']),
      brightnessPercent: _parsePercent(json['brightness']),
      contrastPercent: _parsePercent(json['contrast']),
      monitorVolumePercent: _parsePercent(
        json['monitorVolume'] ?? json['volume'],
      ),
      isMuted: json['isMuted'] as bool? ?? json['muted'] as bool?,
      capabilities: FfpDdcPanelCapabilities.fromJson(
        json['capabilities'] is Map
            ? Map<String, dynamic>.from(json['capabilities'] as Map)
            : null,
      ),
    );
  }

  final String monitorId;
  final String? displayName;
  final FfpDdcPowerState? powerState;
  final int? brightnessPercent;
  final int? contrastPercent;

  /// DDC / monitor speaker volume — not FF1 player volume.
  final int? monitorVolumePercent;
  final bool? isMuted;
  final FfpDdcPanelCapabilities capabilities;
}

/// Root snapshot: one or more monitors (e.g. internal + external).
class FfpDdcPanelStatus {
  const FfpDdcPanelStatus({required this.panels});

  factory FfpDdcPanelStatus.fromJson(Map<String, dynamic> json) {
    final rawPanels = json['panels'] ?? json['monitors'];
    if (rawPanels is! List) {
      return const FfpDdcPanelStatus(panels: []);
    }
    final panels = <FfpDdcMonitorPanel>[];
    for (final item in rawPanels) {
      if (item is Map) {
        panels.add(
          FfpDdcMonitorPanel.fromJson(Map<String, dynamic>.from(item)),
        );
      }
    }
    return FfpDdcPanelStatus(panels: panels);
  }

  /// Parses relayer payload that may nest under the `ddcPanelStatus` key.
  factory FfpDdcPanelStatus.fromRelayerPayload(Map<String, dynamic> json) {
    final nested = json['ddcPanelStatus'];
    if (nested is Map) {
      return FfpDdcPanelStatus.fromJson(
        Map<String, dynamic>.from(nested),
      );
    }
    return FfpDdcPanelStatus.fromJson(json);
  }

  final List<FfpDdcMonitorPanel> panels;
}

FfpDdcPowerState? _parsePower(Object? raw) {
  if (raw == null) {
    return null;
  }
  final s = raw.toString().trim().toLowerCase();
  switch (s) {
    case 'on':
    case 'poweron':
      return FfpDdcPowerState.on;
    case 'off':
    case 'poweroff':
      return FfpDdcPowerState.off;
    case 'standby':
    case 'suspend':
      return FfpDdcPowerState.standby;
    default:
      return null;
  }
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
