import 'dart:async';

import 'package:app/app/providers/ff1_wifi_providers.dart';
import 'package:app/design/app_typography.dart';
import 'package:app/design/build/primitives.dart';
import 'package:app/design/layout_constants.dart';
import 'package:app/theme/app_color.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';

final _log = Logger('TouchPad');

/// Touchpad for keyboard control screen. Tap and drag send to FF1 via
/// [ff1WifiControlProvider]. [topicId] from now displaying provider.
class TouchPad extends ConsumerStatefulWidget {
  const TouchPad({
    required this.topicId,
    this.onExpand,
    super.key,
  });

  final String topicId;
  final VoidCallback? onExpand;

  @override
  ConsumerState<TouchPad> createState() => _TouchPadState();
}

class _TouchPadState extends ConsumerState<TouchPad> {
  Offset? _lastPosition;
  final List<Offset> _dragOffsets = [];

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
          GestureDetector(
            onTap: () async {
              _log.info('[Touchpad] onTap');
              await wifiControl.tap(topicId: widget.topicId);
            },
            onPanStart: (panDetails) {
              _log.info('[Touchpad] onPanStart: ${panDetails.localPosition}');
              _lastPosition = panDetails.localPosition;
            },
            onPanUpdate: (panDetails) {
              final delta = panDetails.localPosition -
                  (_lastPosition ?? panDetails.localPosition);
              _lastPosition = panDetails.localPosition;
              _dragOffsets.add(delta);
              if (_dragOffsets.length > 5) {
                final offsets = List<Offset>.from(_dragOffsets);
                _dragOffsets.clear();
                unawaited(
                  wifiControl.drag(
                    topicId: widget.topicId,
                    cursorOffsets: offsets,
                  ),
                );
              }
            },
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
