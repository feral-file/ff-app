import 'dart:async';

import 'package:app/design/app_typography.dart';
import 'package:app/domain/utils/debounce_util.dart';
import 'package:app/theme/app_color.dart';
import 'package:flutter/material.dart';

/// Primary button.
class PrimaryButton extends StatelessWidget {
  /// Creates a PrimaryButton.
  const PrimaryButton({
    super.key,
    this.onTap,
    this.color,
    this.disabledColor,
    this.text,
    this.textColor,
    this.width,
    this.enabled = true,
    this.isProcessing = false,
    this.indicatorColor,
    this.padding = const EdgeInsets.symmetric(vertical: 13),
    this.elevatedPadding,
    this.borderRadius = 32,
    this.borderColor,
    this.textStyle,
    this.rightIcon,
  });

  /// On tap callback.
  final VoidCallback? onTap;

  /// Color.
  final Color? color;

  /// Disabled color.
  final Color? disabledColor;

  /// Text.
  final String? text;

  /// Text color.
  final Color? textColor;

  /// Width.
  final double? width;

  /// Whether the button is processing.
  final bool isProcessing;

  /// Whether the button is enabled.
  final bool enabled;

  /// Indicator color.
  final Color? indicatorColor;

  /// Padding.
  final EdgeInsetsGeometry padding;

  /// Elevated padding.
  final EdgeInsetsGeometry? elevatedPadding;

  /// Border radius.
  final double borderRadius;

  /// Border color.
  final Color? borderColor;

  /// Text style.
  final TextStyle? textStyle;

  /// Right icon.
  final Widget? rightIcon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final disabledColor = this.disabledColor ?? AppColor.disabledColor;
    return SizedBox(
      width: width,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: enabled
              ? color ?? AppColor.feralFileLightBlue
              : disabledColor,
          padding: elevatedPadding,
          shadowColor: Colors.transparent,
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
        child: Padding(
          padding: padding,
          child: Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (isProcessing)
                  Container(
                    height: 14,
                    width: 14,
                    margin: const EdgeInsets.only(right: 8),
                    child: CircularProgressIndicator(
                      color: indicatorColor ?? theme.colorScheme.primary,
                      backgroundColor: theme.colorScheme.surface,
                      strokeWidth: 2,
                    ),
                  )
                else
                  const SizedBox(),
                Text(
                  text ?? '',
                  style:
                      textStyle ??
                      AppTypography.body(
                        context,
                      ).black.copyWith(color: textColor),
                ),
                if (rightIcon != null) ...[
                  const SizedBox(width: 7),
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

/// Primary async button.
class PrimaryAsyncButton extends StatefulWidget {
  /// Creates a PrimaryAsyncButton.
  const PrimaryAsyncButton({
    super.key,
    this.onTap,
    this.color,
    this.textColor,
    this.text,
    this.width,
    this.enabled = true,
    this.borderColor,
    this.borderRadius = 32,
    this.processingText,
    this.padding = const EdgeInsets.symmetric(vertical: 13),
  });

  /// On tap callback.
  final FutureOr<void> Function()? onTap;

  /// Color.
  final Color? color;

  /// Text.
  final String? text;

  /// Text color.
  final Color? textColor;

  /// Width.
  final double? width;

  /// Whether the button is enabled.
  final bool enabled;

  /// Processing text.
  final String? processingText;

  /// Border color.
  final Color? borderColor;

  /// Border radius.
  final double borderRadius;

  /// Padding.
  final EdgeInsetsGeometry padding;

  @override
  State<PrimaryAsyncButton> createState() => _PrimaryAsyncButtonState();
}

class _PrimaryAsyncButtonState extends State<PrimaryAsyncButton> {
  bool _isProcessing = false;

  late final String randomKey;

  @override
  void initState() {
    super.initState();
    randomKey = DateTime.now().millisecondsSinceEpoch.toString();
  }

  @override
  Widget build(BuildContext context) => PrimaryButton(
    padding: widget.padding,
    onTap: () async {
      withDebounce(
        key: randomKey,
        () async {
          setState(() {
            _isProcessing = true;
          });
          await widget.onTap?.call();
          if (!mounted) {
            return;
          }
          setState(() {
            _isProcessing = false;
          });
        },
      );
    },
    color: widget.color,
    text: _isProcessing && widget.processingText != null
        ? widget.processingText
        : widget.text,
    textColor: widget.textColor,
    borderColor: widget.borderColor,
    width: widget.width,
    enabled: widget.enabled && !_isProcessing,
    isProcessing: _isProcessing,
  );
}
