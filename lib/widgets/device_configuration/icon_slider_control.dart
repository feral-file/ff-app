import 'dart:math' as math;

import 'package:app/design/layout_constants.dart';
import 'package:app/theme/app_color.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';

/// Slider control styled like [AudioControl]:
/// icon on the left + slider track on the right.
///
/// This is a purely-presentational widget: it owns no state and performs no
/// FF1/FFP wiring. The parent is responsible for optimistic UI + command
/// execution + revert-on-failure flows.
class IconSliderControl extends StatelessWidget {
  const IconSliderControl({
    required this.iconAsset,
    required this.value,
    required this.onChanged,
    super.key,
    this.max = 100,
    this.enabled = true,
    this.iconEnabled,
    this.iconColor,
    this.onChangeEnd,
    this.onIconTap,
    this.gap,
    this.iconSize = 18,
    this.semanticLabel,
  });

  /// Path to an SVG asset used as the leading icon.
  final String iconAsset;

  /// Current value (0..[max]).
  final double value;

  final double max;

  final bool enabled;

  /// Whether the icon tap interaction is enabled.
  ///
  /// Defaults to [enabled] when unset.
  final bool? iconEnabled;

  /// Optional explicit icon tint. Defaults to the slider's active/disabled tint.
  ///
  /// Use this to represent additional state (e.g. muted) without affecting the
  /// slider interaction state.
  final Color? iconColor;

  /// Called as the slider moves.
  final ValueChanged<double> onChanged;

  /// Called when the slider interaction ends.
  final ValueChanged<double>? onChangeEnd;

  /// Optional icon tap interaction (e.g. mute toggle).
  final VoidCallback? onIconTap;

  /// Spacing between icon and slider.
  final double? gap;

  /// Icon size (both width and height).
  final double iconSize;

  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final activeColor = enabled
        ? AppColor.white
        : AppColor.white.withValues(alpha: 0.4);

    final iconIsEnabled = iconEnabled ?? enabled;
    final iconBaseTint = iconIsEnabled
        ? AppColor.white
        : AppColor.white.withValues(alpha: 0.4);

    // When the slider is disabled but the icon is enabled (e.g. "mute-only"),
    // keep the icon at full tint while still reflecting any explicit [iconColor].
    final effectiveIconColor = iconColor ?? iconBaseTint;

    final icon = SvgPicture.asset(
      iconAsset,
      width: iconSize,
      height: iconSize,
      semanticsLabel: semanticLabel,
      colorFilter: ColorFilter.mode(effectiveIconColor, BlendMode.srcIn),
    );

    final tapSize = math.max(iconSize + 8, LayoutConstants.minTouchTarget);

    return Row(
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: iconIsEnabled ? onIconTap : null,
          child: SizedBox(
            width: tapSize,
            height: tapSize,
            child: Center(child: icon),
          ),
        ),
        SizedBox(width: gap ?? LayoutConstants.space2),
        Expanded(
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: activeColor,
              inactiveTrackColor: AppColor.white.withValues(alpha: 0.2),
              thumbColor: activeColor,
              trackHeight: 2,
              thumbShape: const RoundSliderThumbShape(
                enabledThumbRadius: 6,
              ),
              overlayShape: SliderComponentShape.noOverlay,
            ),
            child: Slider(
              value: value.clamp(0, max),
              max: max,
              onChanged: enabled ? onChanged : null,
              onChangeEnd: enabled ? onChangeEnd : null,
            ),
          ),
        ),
      ],
    );
  }
}
