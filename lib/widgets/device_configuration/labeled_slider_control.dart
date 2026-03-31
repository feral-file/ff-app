import 'package:app/design/layout_constants.dart';
import 'package:app/theme/app_color.dart';
import 'package:flutter/material.dart';

/// Label + slider; callbacks only — no FF1/FFP wiring.
class LabeledSliderControl extends StatelessWidget {
  /// Creates a labeled slider.
  const LabeledSliderControl({
    required this.label,
    required this.value,
    required this.onChanged,
    super.key,
    this.max = 100,
    this.onChangeEnd,
    this.enabled = true,
  });

  /// Left column label (English UI copy from parent).
  final String label;

  /// Current value (0..[max]).
  final double value;

  final double max;

  final ValueChanged<double> onChanged;

  final ValueChanged<double>? onChangeEnd;

  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final activeColor = enabled
        ? AppColor.white
        : AppColor.white.withValues(alpha: 0.4);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(color: activeColor, fontSize: 13),
        ),
        SizedBox(height: LayoutConstants.space2),
        SliderTheme(
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
      ],
    );
  }
}
