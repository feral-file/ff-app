import 'dart:async';
import 'package:app/domain/utils/debounce_util.dart';
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

/// Custom primary async button.
class CustomPrimaryAsyncButton extends StatefulWidget {
  /// Creates a CustomPrimaryAsyncButton.
  const CustomPrimaryAsyncButton({
    required this.child,
    super.key,
    this.onTap,
    this.color,
    this.enabled = true,
    this.processingText,
    this.borderColor,
    this.padding = const EdgeInsets.symmetric(vertical: 2),
  });

  /// On tap callback.
  final FutureOr<void> Function()? onTap;

  /// Child.
  final Widget child;

  /// Color.
  final Color? color;

  /// Whether the button is enabled.
  final bool enabled;

  /// Processing text.
  final String? processingText;

  /// Border color.
  final Color? borderColor;

  /// Padding.
  final EdgeInsetsGeometry padding;

  @override
  State<CustomPrimaryAsyncButton> createState() =>
      _CustomPrimaryAsyncButtonState();
}

class _CustomPrimaryAsyncButtonState extends State<CustomPrimaryAsyncButton> {
  bool _isProcessing = false;
  late final String randomKey;

  @override
  void initState() {
    super.initState();
    randomKey = DateTime.now().millisecondsSinceEpoch.toString();
  }

  @override
  Widget build(BuildContext context) {
    return CustomPrimaryButton(
      onTap: () async {
        withDebounce(
          key: randomKey,
          () async {
            setState(() {
              _isProcessing = true;
            });
            await Future<void>.sync(() => widget.onTap?.call());
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
      borderColor: widget.borderColor,
      enabled: widget.enabled && !_isProcessing,
      isProcessing: _isProcessing,
      padding: widget.padding,
      child: widget.child,
    );
  }
}
