import 'package:app/design/app_typography.dart';
import 'package:app/design/layout_constants.dart';
import 'package:app/domain/extensions/extensions.dart';
import 'package:app/theme/app_color.dart';
import 'package:flutter/material.dart';

/// Outline button.
class OutlineButton extends StatelessWidget {
  /// Creates an OutlineButton.
  const OutlineButton({
    super.key,
    this.onTap,
    this.color,
    this.text,
    this.width,
    this.enabled = true,
    this.isProcessing = false,
    this.textColor,
    this.borderColor,
    this.padding = const EdgeInsets.symmetric(vertical: 12),
    this.rightIcon,
  });

  /// On tap callback.
  final VoidCallback? onTap;

  /// Color.
  final Color? color;

  /// Text.
  final String? text;

  /// Width.
  final double? width;

  /// Whether the button is processing.
  final bool isProcessing;

  /// Whether the button is enabled.
  final bool enabled;

  /// Text color.
  final Color? textColor;

  /// Border color.
  final Color? borderColor;

  /// Padding.
  final EdgeInsets padding;

  /// Right icon.
  final Widget? rightIcon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: width,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: color ?? theme.auGreyBackground,
          shadowColor: Colors.transparent,
          elevation: 0,
          shape: RoundedRectangleBorder(
            side: BorderSide(color: borderColor ?? Colors.white),
            borderRadius: BorderRadius.circular(32),
          ),
        ),
        onPressed: enabled ? onTap : null,
        child: Padding(
          padding: padding,
          child: Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (isProcessing)
                  Container(
                    height: LayoutConstants.space3,
                    width: LayoutConstants.space3,
                    margin: EdgeInsets.only(right: LayoutConstants.space2),
                    child: CircularProgressIndicator(
                      color: theme.colorScheme.primary,
                      backgroundColor: theme.colorScheme.surface,
                      strokeWidth: 2,
                    ),
                  )
                else
                  const SizedBox(),
                Text(
                  text ?? '',
                  style: AppTypography.body(context).white.copyWith(
                    color:
                        textColor ?? (!enabled ? AppColor.disabledColor : null),
                  ),
                ),
                if (rightIcon != null) ...[
                  SizedBox(width: LayoutConstants.space2),
                  rightIcon!,
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
