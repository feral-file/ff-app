import 'package:app/widgets/device_configuration/zero_toggle_icon_slider_control.dart';
import 'package:flutter/material.dart';

/// FFP monitor brightness slider (DDC panel control).
class FfpBrightnessControl extends StatelessWidget {
  const FfpBrightnessControl({
    required this.value,
    required this.onChanged,
    super.key,
    this.enabled = true,
    this.onChangeEnd,
  });

  final double value;
  final bool enabled;
  final ValueChanged<double> onChanged;
  final ValueChanged<double>? onChangeEnd;

  @override
  Widget build(BuildContext context) {
    return ZeroToggleIconSliderControl(
      iconAsset: 'assets/images/icon_brightness.svg',
      semanticLabel: 'Brightness',
      value: value,
      enabled: enabled,
      onChanged: onChanged,
      onChangeEnd: onChangeEnd,
    );
  }
}

/// FFP monitor contrast slider (DDC panel control).
class FfpContrastControl extends StatelessWidget {
  const FfpContrastControl({
    required this.value,
    required this.onChanged,
    super.key,
    this.enabled = true,
    this.onChangeEnd,
  });

  final double value;
  final bool enabled;
  final ValueChanged<double> onChanged;
  final ValueChanged<double>? onChangeEnd;

  @override
  Widget build(BuildContext context) {
    return ZeroToggleIconSliderControl(
      iconAsset: 'assets/images/icon_contrast.svg',
      semanticLabel: 'Contrast',
      value: value,
      enabled: enabled,
      onChanged: onChanged,
      onChangeEnd: onChangeEnd,
    );
  }
}

/// FFP monitor volume slider (DDC panel control).
class FfpMonitorVolumeControl extends StatelessWidget {
  const FfpMonitorVolumeControl({
    required this.value,
    required this.onChanged,
    super.key,
    this.enabled = true,
    this.iconEnabled,
    this.onChangeEnd,
  });

  final double value;
  final bool enabled;
  final bool? iconEnabled;
  final ValueChanged<double> onChanged;
  final ValueChanged<double>? onChangeEnd;

  @override
  Widget build(BuildContext context) {
    return ZeroToggleIconSliderControl(
      iconAsset: 'assets/images/icon_volume.svg',
      zeroIconAsset: 'assets/images/icon_volume_muted.svg',
      semanticLabel: 'Monitor volume',
      value: value,
      enabled: enabled,
      iconEnabled: iconEnabled,
      onChanged: onChanged,
      onChangeEnd: onChangeEnd,
    );
  }
}

