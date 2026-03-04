import 'package:app/app/providers/now_displaying_provider.dart';
import 'package:app/app/providers/services_provider.dart';
import 'package:app/design/build/primitives.dart';
import 'package:app/design/layout_constants.dart';
import 'package:app/domain/models/now_displaying_object.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Sleep mode indicator for the now displaying bar.
///
/// Shows a blinking (opacity) animation while processing sleep/wake.
class SleepModeIndicator extends ConsumerStatefulWidget {
  const SleepModeIndicator({
    required this.isSleeping,
    super.key,
  });

  final bool isSleeping;

  @override
  ConsumerState<SleepModeIndicator> createState() => _SleepModeIndicatorState();
}

class _SleepModeIndicatorState extends ConsumerState<SleepModeIndicator>
    with SingleTickerProviderStateMixin {
  static const _processingAnimationDuration = Duration(milliseconds: 150);
  static const _blinkOpacityMin = 0.3;

  late AnimationController _animationController;
  late Animation<double> _blinkAnimation;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: _processingAnimationDuration,
      vsync: this,
    );
    _blinkAnimation =
        Tween<double>(
          begin: 1.0,
          end: _blinkOpacityMin,
        ).animate(
          CurvedAnimation(
            parent: _animationController,
            curve: Curves.easeInOut,
          ),
        );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _handleTap() async {
    final status = ref.read(nowDisplayingProvider);
    if (status is! NowDisplayingSuccess ||
        status.object is! DP1NowDisplayingObject) {
      return;
    }

    final device = (status.object as DP1NowDisplayingObject).connectedDevice;

    if (_isProcessing) {
      return;
    }

    setState(() {
      _isProcessing = true;
    });

    HapticFeedback.lightImpact();

    _animationController.repeat(reverse: true);

    try {
      await ref.read(canvasClientServiceV2Provider).setSleepMode(
        device,
        !widget.isSleeping,
      );
    } finally {
      if (!mounted) {
        return;
      }

      _animationController
        ..stop()
        ..reset();

      setState(() {
        _isProcessing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.isSleeping
        ? PrimitivesTokens.colorsSleepModeInactive
        : PrimitivesTokens.colorsSleepModeActive;

    final semanticsLabel = widget.isSleeping
        ? 'Tap to wake FF1'
        : 'Tap to put FF1 to sleep';

    return Semantics(
      label: semanticsLabel,
      button: true,
      child: GestureDetector(
        onTap: _handleTap,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          width: LayoutConstants.minTouchTarget,
          height: LayoutConstants.minTouchTarget,
          child: Center(
            child: AnimatedBuilder(
              animation: _blinkAnimation,
              builder: (context, child) {
                return Opacity(
                  opacity: _blinkAnimation.value,
                  child: SizedBox(
                    width: LayoutConstants.sleepModeIndicatorSize,
                    height: LayoutConstants.sleepModeIndicatorSize,
                    child: Padding(
                      padding: EdgeInsets.all(
                        LayoutConstants.sleepModeIndicatorPadding,
                      ),
                      child: Container(
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
