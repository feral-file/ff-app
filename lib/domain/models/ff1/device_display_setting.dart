import 'package:app/domain/models/ff1/art_framing.dart';

/// FF1 device display setting (e.g. scaling).
class DeviceDisplaySetting {
  DeviceDisplaySetting({
    this.scaling,
  });

  factory DeviceDisplaySetting.fromJson(Map<String, dynamic> json) {
    return DeviceDisplaySetting(
      scaling: json['scaling'] != null
          ? ArtFraming.fromString(json['scaling'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'scaling': scaling?.name,
    };
  }

  DeviceDisplaySetting copyWith({
    ArtFraming? scaling,
  }) {
    return DeviceDisplaySetting(
      scaling: scaling ?? this.scaling,
    );
  }

  ArtFraming? scaling;
}
