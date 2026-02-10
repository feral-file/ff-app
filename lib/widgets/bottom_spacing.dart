import 'package:app/design/layout_constants.dart';
import 'package:flutter/material.dart';

/// Bottom spacing widget for consistent spacing at the bottom of scrollable content.
class BottomSpacing extends StatelessWidget {
  /// Creates a BottomSpacing widget.
  const BottomSpacing({super.key});

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    return SizedBox(height: bottomPadding + LayoutConstants.space20);
  }
}
