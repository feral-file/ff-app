import 'dart:async';

import 'package:flutter/material.dart';
import 'package:logging/logging.dart';

final _log = Logger('TwoStopDraggableSheet');

/// Global expanded state for the now displaying bar.
///
/// Used by the app shell to show a tap-to-dismiss overlay when expanded.
final ValueNotifier<bool> isNowDisplayingBarExpanded = ValueNotifier<bool>(
  false,
);

final GlobalKey<_TwoStopDraggableSheetState> nowDisplayingSheetKey =
    GlobalKey<_TwoStopDraggableSheetState>();

/// Two-stop draggable sheet matching old repo structure.
///
/// Wraps both collapsed and expanded in SingleChildScrollView with
/// ValueListenableBuilder for snap behavior.
class TwoStopDraggableSheet extends StatefulWidget {
  const TwoStopDraggableSheet({
    required this.minSize,
    required this.maxSize,
    required this.collapsedBuilder,
    required this.expandedBuilder,
    super.key,
  });

  final double minSize;
  final double maxSize;
  final Widget Function(BuildContext, ScrollController) collapsedBuilder;
  final Widget Function(BuildContext, ScrollController) expandedBuilder;

  @override
  State<TwoStopDraggableSheet> createState() => _TwoStopDraggableSheetState();
}

class _TwoStopDraggableSheetState extends State<TwoStopDraggableSheet> {
  final DraggableScrollableController _controller =
      DraggableScrollableController();

  bool _isAdjustingSize = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_snapSheet);
  }

  void _snapSheet() {
    if (_isAdjustingSize) {
      return;
    }
    final midSize = (widget.minSize + widget.maxSize) / 2;
    if (_controller.size > widget.minSize * 2 ||
        _controller.size >= midSize) {
      isNowDisplayingBarExpanded.value = true;
    } else {
      isNowDisplayingBarExpanded.value = false;
    }
  }

  Future<void> collapseSheet({
    Duration duration = const Duration(milliseconds: 150),
  }) async {
    _log.info('Collapsing sheet from size: ${_controller.size}');
    _log.info('Collapsing sheet to minSize: ${widget.minSize}');
    _isAdjustingSize = true;
    final completer = Completer<void>();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        await _controller.animateTo(
          widget.minSize,
          duration: duration,
          curve: Curves.easeOut,
        );
        _log.info('Sheet collapsed to minSize: ${_controller.size}');
      } catch (e) {
        _log.info('Error collapsing sheet: $e');
      } finally {
        _isAdjustingSize = false;
        if (!completer.isCompleted) {
          completer.complete();
        }
        _snapSheet();
      }
    });
    await completer.future;
  }

  @override
  void didUpdateWidget(covariant TwoStopDraggableSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.minSize != oldWidget.minSize) {
      final bool isCurrentlyExpanded = isNowDisplayingBarExpanded.value;
      final bool shouldClampToMin =
          !isCurrentlyExpanded || _controller.size < widget.minSize;

      if (shouldClampToMin) {
        _isAdjustingSize = true;
        final double distance = (widget.minSize - _controller.size).abs();
        final int ms = (120 + distance * 200).clamp(80, 300).toInt();
        collapseSheet(duration: Duration(milliseconds: ms));
      }
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_snapSheet);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      controller: _controller,
      initialChildSize: widget.minSize,
      minChildSize: widget.minSize,
      maxChildSize: widget.maxSize,
      snap: true,
      snapSizes: [widget.minSize, widget.maxSize],
      builder: (context, scrollController) {
        return Stack(
          children: [
            ValueListenableBuilder<bool>(
              valueListenable: isNowDisplayingBarExpanded,
              builder: (context, value, child) {
                return Container(
                  child: value
                      ? SingleChildScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          controller: scrollController,
                          child: widget.expandedBuilder(
                            context,
                            scrollController,
                          ),
                        )
                      : SingleChildScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          controller: scrollController,
                          child: widget.collapsedBuilder(
                            context,
                            scrollController,
                          ),
                        ),
                );
              },
            ),
          ],
        );
      },
    );
  }
}

/// Controller for collapsing the now displaying sheet.
class NowDisplayingSheetController {
  static Future<void> collapse() async {
    final state = nowDisplayingSheetKey.currentState;
    if (state == null) {
      return;
    }
    await state.collapseSheet();
  }
}
