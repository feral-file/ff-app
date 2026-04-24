import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:logging/logging.dart';

final _log = Logger('FfMouseGestureDetector');

/// A small gesture detector that maps touch gestures to FF1-like mouse
/// interactions.
///
/// - `onTap`: single click.
/// - `onDoubleTap`: double click.
/// - `onMove`: move-only drag (no button held).
/// - `onClickAndDrag`: click-and-drag (double-tap-hold then drag).
/// - `onLongPress`: long press.
/// - `onZoomGesture`: two-finger pinch; each update reports a multiplicative
///   scale step since the last update (see [ScaleUpdateDetails.scale]).
///
/// Drag callbacks receive a per-update `Offset delta` so callers can batch
/// into `dragGesture` or `clickAndDragGesture` `cursorOffsets` as needed.
/// `Offset.zero` updates are ignored (not forwarded).
class FfMouseGestureDetector extends StatefulWidget {
  /// Creates a detector that maps touch to FF1-like mouse interactions.
  const FfMouseGestureDetector({
    required this.child,
    this.onTap,
    this.onDoubleTap,
    this.onMove,
    this.onClickAndDrag,
    this.onLongPress,
    this.onZoomGesture,
    this.behavior,
    super.key,
  });

  /// Child painted below the gesture arena.
  final Widget child;

  /// Single tap (primary click).
  final VoidCallback? onTap;

  /// Double tap (double click).
  final VoidCallback? onDoubleTap;

  /// Move-only drag; receives each non-zero [Offset] delta.
  final ValueChanged<Offset>? onMove;

  /// Click-and-drag after double-tap-hold; non-zero [Offset] deltas only.
  final ValueChanged<Offset>? onClickAndDrag;

  /// Long press.
  final VoidCallback? onLongPress;

  /// Pinch-to-zoom steps for forwarding as `zoomGesture` on the player.
  ///
  /// Values are **multiplicative** per update: `> 1` spreads fingers (zoom in),
  /// `< 1` pinches inward (zoom out). Derived from successive
  /// [ScaleUpdateDetails.scale] samples during the same pinch.
  final ValueChanged<double>? onZoomGesture;

  /// Hit-test behavior; defaults to opaque when null.
  final HitTestBehavior? behavior;

  @override
  State<FfMouseGestureDetector> createState() => _FfMouseGestureDetectorState();
}

class _FfMouseGestureDetectorState extends State<FfMouseGestureDetector> {
  bool _isClickAndDrag = false;
  Timer? _singleTapTimer;
  double _pinchLastCumulativeScale = 1;

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

  void _resetPinchScaleTracking() {
    _pinchLastCumulativeScale = 1;
  }

  void _handleZoomStart(ScaleStartDetails details) {
    _log.fine('onZoomStart');
    _resetPinchScaleTracking();
  }

  void _handleZoomUpdate(ScaleUpdateDetails details) {
    final onZoom = widget.onZoomGesture;
    if (onZoom == null) return;
    final cumulative = details.scale;
    if (cumulative == 0) return;
    final ratio = cumulative / _pinchLastCumulativeScale;
    _pinchLastCumulativeScale = cumulative;
    if ((ratio - 1).abs() < 0.0001) return;
    _log.fine('onZoomUpdate ratio=$ratio cumulative=$cumulative');
    onZoom(ratio);
  }

  void _handleZoomEnd(ScaleEndDetails details) {
    _log.fine('onZoomEnd');
    _resetPinchScaleTracking();
  }

  @override
  Widget build(BuildContext context) {
    final gestures = <Type, GestureRecognizerFactory>{
      TapAndPanGestureRecognizer:
          GestureRecognizerFactoryWithHandlers<TapAndPanGestureRecognizer>(
            () => TapAndPanGestureRecognizer(
              supportedDevices: const {PointerDeviceKind.touch},
            ),
            (instance) {
              // Defer tap-and-pan drag victory when pinch-zoom is enabled so
              // scale can compete after a second pointer lands.
              instance
                ..eagerVictoryOnDrag = widget.onZoomGesture == null
                ..onTapDown = (details) {
                  _log.fine(
                    'onTapDown '
                    'count=${details.consecutiveTapCount}',
                  );
                  if (details.consecutiveTapCount == 2) {
                    // Cancel pending single tap when starting a double-tap
                    // sequence.
                    _cancelPendingTap();
                  }
                }
                ..onTapUp = (details) {
                  _log.fine(
                    'onTapUp count=${details.consecutiveTapCount}',
                  );
                  if (details.consecutiveTapCount == 1) {
                    _scheduleSingleTap();
                  } else if (details.consecutiveTapCount == 2) {
                    _handleDoubleTap();
                  }
                }
                ..onDragStart = (details) {
                  _log.fine(
                    'onDragStart count=${details.consecutiveTapCount}',
                  );
                  _cancelPendingTap();
                  _isClickAndDrag = details.consecutiveTapCount == 2;
                }
                ..onDragUpdate = (details) {
                  final delta = details.delta;
                  if (delta == Offset.zero) return;
                  _log.fine(
                    'onDragUpdate delta=$delta '
                    'isClickAndDrag=$_isClickAndDrag',
                  );
                  if (_isClickAndDrag) {
                    widget.onClickAndDrag?.call(delta);
                  } else {
                    widget.onMove?.call(delta);
                  }
                }
                ..onDragEnd = (details) {
                  _log.fine('onDragEnd');
                  _resetDragMode();
                }
                ..onCancel = () {
                  _log.fine('onCancel');
                  _resetAllModes();
                };
            },
          ),
      LongPressGestureRecognizer:
          GestureRecognizerFactoryWithHandlers<LongPressGestureRecognizer>(
            () => LongPressGestureRecognizer(
              supportedDevices: const {PointerDeviceKind.touch},
            ),
            (instance) {
              instance.onLongPress = () {
                _log.fine('onLongPress');
                // Long press wins: treat any in-flight drag as ended.
                _resetAllModes();
                widget.onLongPress?.call();
              };
            },
          ),
    };

    if (widget.onZoomGesture != null) {
      gestures[ScaleGestureRecognizer] =
          GestureRecognizerFactoryWithHandlers<ScaleGestureRecognizer>(
            () => ScaleGestureRecognizer(
              supportedDevices: const {PointerDeviceKind.touch},
            ),
            (instance) {
              instance
                ..onStart = _handleZoomStart
                ..onUpdate = _handleZoomUpdate
                ..onEnd = _handleZoomEnd;
            },
          );
    }

    return RawGestureDetector(
      behavior: widget.behavior ?? HitTestBehavior.opaque,
      gestures: gestures,
      child: widget.child,
    );
  }

  @override
  void dispose() {
    _cancelPendingTap();
    super.dispose();
  }
}
