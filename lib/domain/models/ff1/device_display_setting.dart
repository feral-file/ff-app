import 'package:app/domain/models/ff1/art_framing.dart';

/// FF1 device display setting (e.g. scaling).
class DeviceDisplaySetting {
  /// Creates a device display setting.
  DeviceDisplaySetting({
    this.scaling,
  });

  /// Deserialize from JSON.
  factory DeviceDisplaySetting.fromJson(Map<String, dynamic> json) {
    return DeviceDisplaySetting(
      scaling: json['scaling'] != null
          ? ArtFraming.fromString(json['scaling'] as String)
          : null,
    );
  }

  /// Serialize to JSON.
  Map<String, dynamic> toJson() {
    return {
      'scaling': scaling?.name,
    };
  }

  /// Copy with new values.
  DeviceDisplaySetting copyWith({
    ArtFraming? scaling,
  }) {
    return DeviceDisplaySetting(
      scaling: scaling ?? this.scaling,
    );
  }

  /// Scaling mode.
  ArtFraming? scaling;
}
