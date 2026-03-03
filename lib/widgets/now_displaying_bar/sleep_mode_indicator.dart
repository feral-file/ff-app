import 'package:app/app/providers/ff1_wifi_providers.dart';
import 'package:app/app/providers/now_displaying_provider.dart';
import 'package:app/design/build/primitives.dart';
import 'package:app/design/layout_constants.dart';
import 'package:app/domain/models/now_displaying_object.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Sleep mode indicator for the now displaying bar.
///
/// Matches old repo SleepModeIndicator structure with scale animation.
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
  static const _pressedScale = 0.6;

  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: _processingAnimationDuration,
      vsync: this,
    );
    _scaleAnimation =
        Tween<double>(
          begin: 1.2,
          end: _pressedScale,
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
    if (device.topicId.isEmpty) {
      return;
    }

    if (_isProcessing) {
      return;
    }

    setState(() {
      _isProcessing = true;
    });

    HapticFeedback.lightImpact();

    _animationController.repeat(reverse: true);

    try {
      final control = ref.read(ff1WifiControlProvider);
      if (widget.isSleeping) {
        await control.resume(topicId: device.topicId);
      } else {
        await control.pause(topicId: device.topicId);
      }
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

    return GestureDetector(
      onTap: _handleTap,
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
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
    );
  }
}
