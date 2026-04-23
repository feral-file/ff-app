import 'dart:async';

import 'package:app/app/providers/ff1_wifi_providers.dart';
import 'package:app/design/app_typography.dart';
import 'package:app/design/build/primitives.dart';
import 'package:app/design/layout_constants.dart';
import 'package:app/infra/ff1/wifi_control/ff1_wifi_control.dart';
import 'package:app/theme/app_color.dart';
import 'package:app/widgets/ff_mouse_gesture_detector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';

final _log = Logger('TouchPad');

/// Touchpad for keyboard control screen. Tap and drag send to FF1 via
/// [ff1WifiControlProvider].
class TouchPad extends ConsumerStatefulWidget {
  /// Creates a touchpad surface that forwards gestures to the active FF1
  /// device.
  const TouchPad({
    required this.topicId,
    this.onExpand,
    super.key,
  });

  /// Relayer topic id of the target FF1 device.
  final String topicId;

  /// Optional action to expand the touchpad UI.
  final VoidCallback? onExpand;

  @override
  ConsumerState<TouchPad> createState() => _TouchPadState();
}

class _TouchPadState extends ConsumerState<TouchPad> {
  final List<Offset> _moveDragOffsets = [];
  final List<Offset> _clickAndDragOffsets = [];
  bool _didSendDoubleTapForClickAndDrag = false;

  void _queueMoveDelta(Offset delta) {
    _moveDragOffsets.add(delta);
  }

  void _queueClickAndDragDelta(Offset delta) {
    _clickAndDragOffsets.add(delta);
  }

  void _flushMoveDeltasIfNeeded(FF1WifiControl wifiControl) {
    if (_moveDragOffsets.length <= 5) return;
    _flushMoveDeltas(wifiControl);
  }

  void _flushClickAndDragDeltasIfNeeded(FF1WifiControl wifiControl) {
    if (_clickAndDragOffsets.length <= 5) return;
    _flushClickAndDragDeltas(wifiControl);
  }

  void _flushMoveDeltas(FF1WifiControl wifiControl) {
    if (_moveDragOffsets.isEmpty) return;
    final offsets = List<Offset>.from(_moveDragOffsets);
    _moveDragOffsets.clear();
    unawaited(
      wifiControl.drag(
        topicId: widget.topicId,
        cursorOffsets: offsets,
      ),
    );
  }

  void _flushClickAndDragDeltas(FF1WifiControl wifiControl) {
    if (_clickAndDragOffsets.isEmpty) return;
    final offsets = List<Offset>.from(_clickAndDragOffsets);
    _clickAndDragOffsets.clear();
    unawaited(
      wifiControl.clickAndDrag(
        topicId: widget.topicId,
        cursorOffsets: offsets,
      ),
    );
  }

  void _onPointerGestureEnd(FF1WifiControl wifiControl) {
    _didSendDoubleTapForClickAndDrag = false;
    _flushMoveDeltas(wifiControl);
    _flushClickAndDragDeltas(wifiControl);
  }

  @override
  Widget build(BuildContext context) {
    final wifiControl = ref.read(ff1WifiControlProvider);

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(LayoutConstants.space5),
        color: Colors.black,
      ),
      child: Stack(
        children: [
          Listener(
            behavior: HitTestBehavior.opaque,
            onPointerUp: (_) => _onPointerGestureEnd(wifiControl),
            onPointerCancel: (_) => _onPointerGestureEnd(wifiControl),
            child: FfMouseGestureDetector(
              onTap: () async {
                _log.info(
                  '[Touchpad] onTap topicId=${widget.topicId} '
                  '(tapGesture)',
                );
                await wifiControl.tap(topicId: widget.topicId);
              },
              onDoubleTap: () async {
                _log.info(
                  '[Touchpad] onDoubleTap topicId=${widget.topicId} '
                  '(doubleTapGesture)',
                );
                await wifiControl.doubleTap(topicId: widget.topicId);
              },
              onMove: (delta) {
                _log.fine(
                  '[Touchpad] onMove topicId=${widget.topicId} '
                  'delta=$delta',
                );
                _didSendDoubleTapForClickAndDrag = false;
                _queueMoveDelta(delta);
                _flushMoveDeltasIfNeeded(wifiControl);
              },
              onClickAndDrag: (delta) {
                if (!_didSendDoubleTapForClickAndDrag) {
                  _didSendDoubleTapForClickAndDrag = true;
                  _log.info(
                    '[Touchpad] onClickAndDrag arm doubleTapGesture '
                    'topicId=${widget.topicId}',
                  );
                  unawaited(
                    wifiControl.doubleTap(topicId: widget.topicId),
                  );
                }
                _log.fine(
                  '[Touchpad] onClickAndDrag topicId=${widget.topicId} '
                  'delta=$delta',
                );
                _queueClickAndDragDelta(delta);
                _flushClickAndDragDeltasIfNeeded(wifiControl);
              },
              onLongPress: () async {
                _log.info(
                  '[Touchpad] onLongPress topicId=${widget.topicId} '
                  '(longPressGesture)',
                );
                _didSendDoubleTapForClickAndDrag = false;
                await wifiControl.longPress(topicId: widget.topicId);
              },
              child: const SizedBox.expand(),
            ),
          ),
          Positioned(
            bottom: 0,
            right: 0,
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: LayoutConstants.space5,
                vertical: LayoutConstants.space4,
              ),
              child: Text(
                'Touchpad',
                style: AppTypography.body(context).white.copyWith(
                  color: AppColor.auGrey,
                ),
              ),
            ),
          ),
          if (widget.onExpand != null)
            Positioned(
              bottom: 0,
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: LayoutConstants.space5,
                  vertical: LayoutConstants.space4,
                ),
                child: GestureDetector(
                  onTap: widget.onExpand,
                  child: Icon(
                    Icons.open_in_full,
                    size: LayoutConstants.iconSizeMedium,
                    color: PrimitivesTokens.colorsWhite,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
