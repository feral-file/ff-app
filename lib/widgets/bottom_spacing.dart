import 'package:flutter/material.dart';

/// Bottom spacing widget for consistent spacing at the bottom of scrollable content.
class BottomSpacing extends StatelessWidget {
  /// Creates a BottomSpacing widget.
  const BottomSpacing({super.key});

  @override
  Widget build(BuildContext context) {
    // Bottom safe area padding + extra space
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    return SizedBox(height: bottomPadding + 80);
  }
}
