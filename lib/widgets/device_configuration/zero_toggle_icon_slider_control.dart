import 'package:app/theme/app_color.dart';
import 'package:app/widgets/device_configuration/icon_slider_control.dart';
import 'package:flutter/material.dart';

/// Icon + slider control where tapping the icon toggles the value between `0`
/// and the last non-zero value (AudioControl-like behaviour).
///
/// The parent remains responsible for:
/// - owning the authoritative value
/// - updating UI optimistically via [onChanged]
/// - committing the final value via [onChangeEnd]
///
/// This widget only remembers the last non-zero value so it can restore it.
class ZeroToggleIconSliderControl extends StatefulWidget {
  const ZeroToggleIconSliderControl({
    required this.iconAsset,
    required this.value,
    required this.onChanged,
    super.key,
    this.zeroIconAsset,
    this.max = 100,
    this.enabled = true,
    this.iconEnabled,
    this.onChangeEnd,
    this.gap,
    this.iconSize = 18,
    this.semanticLabel,
    this.restoreFallbackValue = 50,
    this.dimIconWhenZero = true,
  });

  final String iconAsset;
  final String? zeroIconAsset;
  final String? semanticLabel;

  /// Current value (0..[max]) from the parent.
  final double value;
  final double max;

  final bool enabled;
  final bool? iconEnabled;

  final ValueChanged<double> onChanged;
  final ValueChanged<double>? onChangeEnd;

  final double? gap;
  final double iconSize;

  /// Used when the control is currently 0 and we have no prior non-zero value.
  final double restoreFallbackValue;

  /// When true, icon tint is dimmed while [value] is 0 (and enabled).
  final bool dimIconWhenZero;

  @override
  State<ZeroToggleIconSliderControl> createState() =>
      _ZeroToggleIconSliderControlState();
}

class _ZeroToggleIconSliderControlState
    extends State<ZeroToggleIconSliderControl> {
  double _previousNonZero = 0;

  @override
  void initState() {
    super.initState();
    _rememberIfNonZero(widget.value);
  }

  @override
  void didUpdateWidget(covariant ZeroToggleIconSliderControl oldWidget) {
    super.didUpdateWidget(oldWidget);
    _rememberIfNonZero(widget.value);
  }

  void _rememberIfNonZero(double v) {
    if (v > 0) {
      _previousNonZero = v;
    }
  }

  void _toggleZero() {
    final iconIsEnabled = widget.iconEnabled ?? widget.enabled;
    if (!iconIsEnabled) return;

    final current = widget.value.clamp(0, widget.max).toDouble();
    final double next;
    if (current > 0) {
      next = 0;
    } else if (_previousNonZero > 0) {
      next = _previousNonZero;
    } else {
      next = widget.restoreFallbackValue.clamp(0, widget.max).toDouble();
    }

    // Match drag behaviour: update first, then commit.
    widget.onChanged(next);
    widget.onChangeEnd?.call(next);
  }

  @override
  Widget build(BuildContext context) {
    final iconIsEnabled = widget.iconEnabled ?? widget.enabled;
    final shouldDimIcon = widget.enabled && widget.dimIconWhenZero
        ? widget.value <= 0
        : false;

    return IconSliderControl(
      iconAsset: widget.value <= 0 && widget.zeroIconAsset != null
          ? widget.zeroIconAsset!
          : widget.iconAsset,
      semanticLabel: widget.semanticLabel,
      value: widget.value,
      max: widget.max,
      enabled: widget.enabled,
      iconEnabled: iconIsEnabled,
      iconColor: shouldDimIcon
          ? AppColor.white.withValues(alpha: 0.4)
          : null,
      gap: widget.gap,
      iconSize: widget.iconSize,
      onChanged: widget.onChanged,
      onChangeEnd: widget.onChangeEnd,
      onIconTap: _toggleZero,
    );
  }
}
