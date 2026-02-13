import 'package:app/design/build/primitives.dart';
import 'package:app/design/layout_constants.dart';
import 'package:flutter/material.dart';

/// Top line handle for the now displaying bar.
///
/// Matches old repo TopLine with optional color parameter.
class TopLine extends StatelessWidget {
  const TopLine({
    this.color,
    super.key,
  });

  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: LayoutConstants.nowDisplayingBarTopLineWidth,
      height: LayoutConstants.nowDisplayingBarTopLineHeight,
      decoration: BoxDecoration(
        color: color ?? PrimitivesTokens.colorsTopLine,
        borderRadius: BorderRadius.circular(
          LayoutConstants.nowPlayingBarTopLineCornerRadius,
        ),
      ),
    );
  }
}
