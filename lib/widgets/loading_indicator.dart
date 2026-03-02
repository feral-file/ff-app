import 'package:flutter/material.dart';

/// Loading indicator widget.
class LoadingIndicator extends StatelessWidget {
  /// Constructor
  const LoadingIndicator({
    this.size = 27,
    this.valueColor = Colors.black,
    this.backgroundColor = Colors.black54,
    this.strokeWidth = 2.0,
    super.key,
  });

  /// Size.
  final double size;

  /// Value color.
  final Color valueColor;

  /// Background color.
  final Color backgroundColor;

  /// Stroke width.
  final double strokeWidth;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CircularProgressIndicator(
        backgroundColor: backgroundColor,
        color: valueColor,
        strokeWidth: strokeWidth,
      ),
    );
  }
}
