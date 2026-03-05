import 'dart:async';

import 'package:flutter/material.dart';

/// Delays rendering [child] while [isLoading] is true.
///
/// Useful to avoid flashing loading indicators during short internal loads.
class DelayedLoadingGate extends StatefulWidget {
  /// Creates a [DelayedLoadingGate].
  const DelayedLoadingGate({
    required this.isLoading,
    required this.child,
    super.key,
    this.delay = const Duration(milliseconds: 500),
    this.placeholder = const SizedBox.shrink(),
  });

  /// Whether loading is currently active.
  final bool isLoading;

  /// Delay before showing [child].
  final Duration delay;

  /// Loading indicator content.
  final Widget child;

  /// Widget shown before delay elapses, or when not loading.
  final Widget placeholder;

  @override
  State<DelayedLoadingGate> createState() => _DelayedLoadingGateState();
}

class _DelayedLoadingGateState extends State<DelayedLoadingGate> {
  Timer? _timer;
  bool _showChild = false;

  @override
  void initState() {
    super.initState();
    _syncWithLoadingState();
  }

  @override
  void didUpdateWidget(covariant DelayedLoadingGate oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isLoading != widget.isLoading ||
        oldWidget.delay != widget.delay) {
      _syncWithLoadingState();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _syncWithLoadingState() {
    _timer?.cancel();

    if (!widget.isLoading) {
      if (_showChild) {
        setState(() {
          _showChild = false;
        });
      }
      return;
    }

    if (widget.delay <= Duration.zero) {
      if (!_showChild) {
        setState(() {
          _showChild = true;
        });
      }
      return;
    }

    if (_showChild) {
      setState(() {
        _showChild = false;
      });
    }
    _timer = Timer(widget.delay, () {
      if (!mounted || !widget.isLoading) return;
      setState(() {
        _showChild = true;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_showChild) {
      return widget.placeholder;
    }
    return widget.child;
  }
}
