import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// A small gesture detector that maps touch gestures to FF1-like mouse
/// interactions.
///
/// - `onTap`: single click.
/// - `onDoubleTap`: double click.
/// - `onMove`: move-only drag (no button held).
/// - `onClickAndDrag`: click-and-drag (double-tap-hold then drag).
/// - `onLongPress`: long press.
///
/// Drag callbacks receive a per-update `Offset delta` so callers can batch
/// into `dragGesture` or `clickAndDragGesture` `cursorOffsets` as needed.
class FfMouseGestureDetector extends StatefulWidget {
  const FfMouseGestureDetector({
    required this.child,
    this.onTap,
    this.onDoubleTap,
    this.onMove,
    this.onClickAndDrag,
    this.onLongPress,
    this.behavior,
    super.key,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onDoubleTap;
  final ValueChanged<Offset>? onMove;
  final ValueChanged<Offset>? onClickAndDrag;
  final VoidCallback? onLongPress;
  final HitTestBehavior? behavior;

  @override
  State<FfMouseGestureDetector> createState() => _FfMouseGestureDetectorState();
}

class _FfMouseGestureDetectorState extends State<FfMouseGestureDetector> {
  bool _isClickAndDrag = false;
  Timer? _singleTapTimer;

  void _resetDragMode() {
    _isClickAndDrag = false;
  }

  void _cancelPendingTap() {
    _singleTapTimer?.cancel();
    _singleTapTimer = null;
  }

  void _scheduleSingleTap() {
    _cancelPendingTap();
    if (widget.onTap == null) return;
    _singleTapTimer = Timer(kDoubleTapTimeout, () {
      widget.onTap?.call();
    });
  }

  void _handleDoubleTap() {
    _cancelPendingTap();
    widget.onDoubleTap?.call();
  }

  void _resetAllModes() {
    _resetDragMode();
    _cancelPendingTap();
  }

  @override
  Widget build(BuildContext context) {
    return RawGestureDetector(
      behavior: widget.behavior ?? HitTestBehavior.opaque,
      gestures: <Type, GestureRecognizerFactory>{
        TapAndPanGestureRecognizer: GestureRecognizerFactoryWithHandlers<
            TapAndPanGestureRecognizer>(
          () => TapAndPanGestureRecognizer(
            supportedDevices: const {PointerDeviceKind.touch},
          ),
          (TapAndPanGestureRecognizer instance) {
            instance
              ..onTapDown = (TapDragDownDetails details) {
                if (details.consecutiveTapCount == 2) {
                  // Prevent the pending single-tap callback from firing if we are
                  // entering a double-tap sequence.
                  _cancelPendingTap();
                }
              }
              ..onTapUp = (TapDragUpDetails details) {
                if (details.consecutiveTapCount == 1) {
                  _scheduleSingleTap();
                } else if (details.consecutiveTapCount == 2) {
                  _handleDoubleTap();
                }
              }
              ..onDragStart = (TapDragStartDetails details) {
                _cancelPendingTap();
                _isClickAndDrag = details.consecutiveTapCount == 2;
              }
              ..onDragUpdate = (TapDragUpdateDetails details) {
                final delta = details.delta;
                if (_isClickAndDrag) {
                  widget.onClickAndDrag?.call(delta);
                } else {
                  widget.onMove?.call(delta);
                }
              }
              ..onDragEnd = (TapDragEndDetails details) {
                _resetDragMode();
              }
              ..onCancel = () {
                _resetAllModes();
              };
          },
        ),
        LongPressGestureRecognizer:
            GestureRecognizerFactoryWithHandlers<LongPressGestureRecognizer>(
          () => LongPressGestureRecognizer(
            supportedDevices: const {PointerDeviceKind.touch},
          ),
          (LongPressGestureRecognizer instance) {
            instance.onLongPress = () {
              // If long press wins, any drag interaction should be treated as ended.
              _resetAllModes();
              widget.onLongPress?.call();
            };
          },
        ),
      },
      child: widget.child,
    );
  }

  @override
  void dispose() {
    _cancelPendingTap();
    super.dispose();
  }
}
