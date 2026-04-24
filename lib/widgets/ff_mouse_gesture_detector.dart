import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:logging/logging.dart';

final _log = Logger('FfMouseGestureDetector');

class _CancelableLongPressGestureRecognizer extends LongPressGestureRecognizer {
  _CancelableLongPressGestureRecognizer({
    super.supportedDevices,
  });

  void cancel() {
    resolve(GestureDisposition.rejected);
  }
}

/// A small gesture detector that maps touch gestures to FF1-like mouse
/// interactions.
///
/// - `onTap`: single click.
/// - `onDoubleTap`: double click.
/// - `onMove`: move-only drag (no button held).
/// - `onClickAndDrag`: click-and-drag (double-tap-hold then drag).
/// - `onLongPress`: long press.
/// - `onZoomGesture`: two-finger pinch; each update reports a multiplicative
///   scale step from the change in distance between the two touches (global
///   coordinates). Implemented with a [Listener] so taps and drags are not
///   competing in the gesture arena against [ScaleGestureRecognizer].
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
  /// `< 1` pinches inward (zoom out). Ratios come from successive distances
  /// between the two active touches.
  final ValueChanged<double>? onZoomGesture;

  /// Hit-test behavior; defaults to opaque when null.
  final HitTestBehavior? behavior;

  @override
  State<FfMouseGestureDetector> createState() => _FfMouseGestureDetectorState();
}

class _FfMouseGestureDetectorState extends State<FfMouseGestureDetector> {
  bool _isClickAndDrag = false;
  bool _isPinching = false;
  bool _suppressTap = false;
  Timer? _singleTapTimer;
  _CancelableLongPressGestureRecognizer? _longPressRecognizer;

  /// Active touch positions for pinch (global); only used when
  /// [FfMouseGestureDetector.onZoomGesture] is non-null.
  final Map<int, Offset> _pinchPointerPositions = <int, Offset>{};

  /// Previous inter-touch distance during an active two-finger pinch.
  double? _pinchLastSpan;

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
    _isPinching = false;
    _suppressTap = false;
    _cancelPendingTap();
  }

  void _startPinch() {
    _resetDragMode();
    _cancelPendingTap();
    _longPressRecognizer?.cancel();
    _isPinching = true;
    _suppressTap = true;
    _pinchLastSpan = _pinchSpanForTwoTouches();
    _log.fine('pinch start span=$_pinchLastSpan');
  }

  double? _pinchSpanForTwoTouches() {
    if (_pinchPointerPositions.length != 2) return null;
    final positions = _pinchPointerPositions.values.toList();
    return (positions[0] - positions[1]).distance;
  }

  void _handlePinchPointerDown(PointerDownEvent event) {
    if (widget.onZoomGesture == null) return;
    _pinchPointerPositions[event.pointer] = event.position;
    if (_singleTapTimer != null) {
      _cancelPendingTap();
    }
    if (_pinchPointerPositions.length == 2) {
      // Once two pointers are active, treat the interaction as pinch-only so
      // one-finger pan updates do not leak through while the user is zooming.
      _startPinch();
    }
  }

  void _handlePinchPointerMove(PointerMoveEvent event) {
    if (widget.onZoomGesture == null) return;
    if (!_pinchPointerPositions.containsKey(event.pointer)) return;
    _pinchPointerPositions[event.pointer] = event.position;
    if (_pinchPointerPositions.length != 2) return;
    final span = _pinchSpanForTwoTouches();
    if (span == null || span == 0) return;
    final last = _pinchLastSpan;
    if (last == null || last <= 0) {
      _pinchLastSpan = span;
      return;
    }
    final ratio = span / last;
    _pinchLastSpan = span;
    if ((ratio - 1).abs() < 0.0001) return;
    _log.fine('pinch ratio=$ratio span=$span');
    widget.onZoomGesture!.call(ratio);
  }

  void _handlePinchPointerEnd(PointerEvent event) {
    if (widget.onZoomGesture == null) return;
    _pinchPointerPositions.remove(event.pointer);
    if (_pinchPointerPositions.length < 2) {
      _pinchLastSpan = null;
      _isPinching = false;
    } else if (_pinchPointerPositions.length == 2) {
      _pinchLastSpan = _pinchSpanForTwoTouches();
    }
    if (_pinchPointerPositions.isEmpty) {
      _suppressTap = false;
    }
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
              instance
                ..onTapDown = (details) {
                  if (_suppressTap) return;
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
                  if (_suppressTap) return;
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
                  if (_isPinching) return;
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
      _CancelableLongPressGestureRecognizer:
          GestureRecognizerFactoryWithHandlers<_CancelableLongPressGestureRecognizer>(
            () {
              _longPressRecognizer = _CancelableLongPressGestureRecognizer(
                supportedDevices: const {PointerDeviceKind.touch},
              );
              return _longPressRecognizer!;
            },
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

    final core = RawGestureDetector(
      behavior: widget.behavior ?? HitTestBehavior.opaque,
      gestures: gestures,
      child: widget.child,
    );

    if (widget.onZoomGesture == null) {
      return core;
    }
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: _handlePinchPointerDown,
      onPointerMove: _handlePinchPointerMove,
      onPointerUp: _handlePinchPointerEnd,
      onPointerCancel: _handlePinchPointerEnd,
      child: core,
    );
  }

  @override
  void dispose() {
    _cancelPendingTap();
    super.dispose();
  }
}
