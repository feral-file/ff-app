import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Header with animated child that expands/collapses.
///
/// Matches old repo HeaderWithAnimated structure.
class HeaderWithAnimated extends StatefulWidget {
  const HeaderWithAnimated({
    required this.header,
    required this.child,
    required this.isExpandedListenable,
    super.key,
  });

  final Widget header;
  final Widget child;
  final ValueListenable<bool> isExpandedListenable;

  @override
  State<HeaderWithAnimated> createState() => _HeaderWithAnimatedState();
}

class _HeaderWithAnimatedState extends State<HeaderWithAnimated>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );

    widget.isExpandedListenable.addListener(_onExpandedChanged);

    if (widget.isExpandedListenable.value) {
      _animationController.value = 1.0;
    }
  }

  void _onExpandedChanged() {
    if (widget.isExpandedListenable.value) {
      _animationController.forward();
    } else {
      _animationController.reverse();
    }
  }

  @override
  void didUpdateWidget(covariant HeaderWithAnimated oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isExpandedListenable != widget.isExpandedListenable) {
      oldWidget.isExpandedListenable.removeListener(_onExpandedChanged);
      widget.isExpandedListenable.addListener(_onExpandedChanged);

      if (widget.isExpandedListenable.value) {
        _animationController.value = 1.0;
      } else {
        _animationController.value = 0.0;
      }
    }
  }

  @override
  void dispose() {
    widget.isExpandedListenable.removeListener(_onExpandedChanged);
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        widget.header,
        ValueListenableBuilder<bool>(
          valueListenable: widget.isExpandedListenable,
          builder: (context, isExpanded, child) {
            return ClipRect(
              child: Align(
                alignment: Alignment.bottomCenter,
                heightFactor: isExpanded ? 1.0 : 0.0,
                child: child,
              ),
            );
          },
          child: widget.child,
        ),
      ],
    );
  }
}
