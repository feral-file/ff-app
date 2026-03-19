import 'package:app/theme/app_color.dart';
import 'package:flutter/material.dart';

/// Custom primary button.
class CustomPrimaryButton extends StatelessWidget {
  /// Creates a CustomPrimaryButton.
  const CustomPrimaryButton({
    required this.child,
    super.key,
    this.onTap,
    this.color,
    this.disabledColor,
    this.enabled = true,
    this.isProcessing = false,
    this.borderColor,
    this.indicatorColor,
    this.padding = const EdgeInsets.symmetric(vertical: 13),
    this.borderRadius = 32,
    this.textColor,
  });

  /// Creates a CustomPrimaryButton.
  /// onTap callback.
  final VoidCallback? onTap;

  /// Color.
  final Color? color;

  /// Disabled color.
  final Color? disabledColor;

  /// Text color.
  final Color? textColor;

  /// Whether the button is processing.
  final bool isProcessing;

  /// Whether the button is enabled.
  final bool enabled;

  /// Indicator color.
  final Color? indicatorColor;

  /// Padding.
  final EdgeInsetsGeometry padding;

  /// Border radius.
  final double borderRadius;

  /// Border color.
  final Color? borderColor;

  /// Child.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final disabledColor = this.disabledColor ?? AppColor.disabledColor;
    return SizedBox(
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: enabled
              ? color ?? AppColor.feralFileLightBlue
              : disabledColor,
          shadowColor: Colors.transparent,
          padding: padding,
          disabledForegroundColor: disabledColor,
          disabledBackgroundColor: disabledColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(borderRadius),
            side: BorderSide(
              color: borderColor ?? Colors.transparent,
            ),
          ),
        ),
        onPressed: enabled ? onTap : null,
        child: Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (isProcessing)
                Container(
                  height: 12,
                  width: 12,
                  margin: const EdgeInsets.only(right: 8),
                  child: CircularProgressIndicator(
                    color: indicatorColor ?? theme.colorScheme.primary,
                    backgroundColor: theme.colorScheme.surface,
                    strokeWidth: 2,
                  ),
                )
              else
                const SizedBox(),
              child,
            ],
          ),
        ),
      ),
    );
  }
}
