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
    // Keep the shared zero-toggle helper here so DDC level controls can use
    // the same quick tap-to-zero / restore shortcut as audio while the slider
    // still owns the committed value and rollback path.
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
    // Keep the shared zero-toggle helper here so DDC level controls can use
    // the same quick tap-to-zero / restore shortcut as audio while the slider
    // still owns the committed value and rollback path.
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
