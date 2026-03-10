import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Expands tap hit testing up to [minSize] without changing layout size.
class TouchTarget extends SingleChildRenderObjectWidget {
  /// Creates a touch target wrapper.
  const TouchTarget({
    required this.minSize,
    required Widget child,
    super.key,
  }) : super(child: child);

  /// Minimum square hit region to expose for the wrapped child.
  final double minSize;

  @override
  RenderObject createRenderObject(BuildContext context) {
    return _RenderTouchTarget(minSize: minSize);
  }

  @override
  void updateRenderObject(
    BuildContext context,
    RenderObject renderObject,
  ) {
    (renderObject as _RenderTouchTarget).minSize = minSize;
  }
}

class _RenderTouchTarget extends RenderProxyBox {
  _RenderTouchTarget({required double minSize}) : _minSize = minSize;

  static const Color _debugOverlayColor = Color(0x3300E5FF);

  double _minSize;

  double get minSize => _minSize;

  set minSize(double value) {
    if (_minSize == value) {
      return;
    }
    _minSize = value;
    markNeedsPaint();
  }

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    final horizontalPadding = math.max(0, (_minSize - size.width) / 2)
        .toDouble();
    final verticalPadding = math.max(0, (_minSize - size.height) / 2)
        .toDouble();
    final hitRect = Rect.fromLTRB(
      -horizontalPadding,
      -verticalPadding,
      size.width + horizontalPadding,
      size.height + verticalPadding,
    );
    if (!hitRect.contains(position)) {
      return false;
    }
    return super.hitTest(result, position: position);
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    super.paint(context, offset);
    if (kDebugMode) {
      final horizontalPadding = math.max(0, (_minSize - size.width) / 2)
          .toDouble();
      final verticalPadding = math.max(0, (_minSize - size.height) / 2)
          .toDouble();
      final hitRect = Rect.fromLTRB(
        offset.dx - horizontalPadding,
        offset.dy - verticalPadding,
        offset.dx + size.width + horizontalPadding,
        offset.dy + size.height + verticalPadding,
      );
      context.canvas.drawRect(
        hitRect,
        Paint()..color = _debugOverlayColor,
      );
    }
  }
}
