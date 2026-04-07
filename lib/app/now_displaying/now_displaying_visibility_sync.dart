import 'dart:ui' show ViewPadding;

import 'package:app/app/now_displaying/now_displaying_visibility_config.dart';
import 'package:app/app/providers/current_route_provider.dart';
import 'package:app/app/providers/now_displaying_visibility_provider.dart';
import 'package:app/app/routing/app_route_observer.dart' show AppRouteObserver;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Minimum scrollable content extent required before scroll should toggle
/// now displaying visibility.
const nowDisplayingScrollToggleThreshold = 100.0;

/// Returns true when the now displaying bar should be visible for [routeState].
///
/// Route (modal/drawer) has higher priority than path: when modal/drawer
/// is shown, returns false regardless of path.
bool shouldShowNowDisplayingForRoute(AppRouteState routeState) {
  if (routeState.hasModalOrDrawer) {
    return false;
  }
  final path = routeState.path;
  for (final hidden in routesThatHideNowDisplayingBar) {
    if (path == hidden || path.startsWith('$hidden/')) {
      return false;
    }
  }
  return true;
}

/// Returns true if a scroll event should affect now displaying visibility.
bool shouldReactToNowDisplayingScroll({
  required Axis axis,
  required double maxScrollExtent,
}) {
  return axis == Axis.vertical &&
      maxScrollExtent >= nowDisplayingScrollToggleThreshold;
}

/// Returns true when view insets indicate the software keyboard is visible.
bool isKeyboardVisibleForViewInsets(ViewPadding viewInsets) {
  return viewInsets.bottom > 0;
}

/// Syncs scroll + keyboard visibility into [nowDisplayingVisibilityProvider].
///
/// Route visibility (path + modal/drawer) is driven by [currentRouteProvider],
/// which is updated by [AppRouteObserver]. This widget only wires scroll and
/// keyboard signals.
class NowDisplayingVisibilitySync extends ConsumerStatefulWidget {
  /// Creates a [NowDisplayingVisibilitySync].
  const NowDisplayingVisibilitySync({
    required this.child,
    super.key,
  });

  /// Subtree that sends scroll notifications for visibility sync.
  final Widget child;

  @override
  ConsumerState<NowDisplayingVisibilitySync> createState() =>
      _NowDisplayingVisibilitySyncState();
}

class _NowDisplayingVisibilitySyncState
    extends ConsumerState<NowDisplayingVisibilitySync>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Riverpod forbids modifying providers while the widget tree is building.
    // Defer the initial keyboard sync until after the first frame so the
    // app-root observer never mutates provider state during build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncKeyboardVisibilityFromViewInsets();
    });
  }

  @override
  void didChangeMetrics() {
    super.didChangeMetrics();
    _syncKeyboardVisibilityFromViewInsets();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _syncKeyboardVisibilityFromViewInsets() {
    if (!mounted) {
      return;
    }

    final view = View.maybeOf(context);
    if (view == null) {
      return;
    }

    ref
        .read(nowDisplayingVisibilityProvider.notifier)
        .setKeyboardVisibility(
          isKeyboardVisibleForViewInsets(view.viewInsets),
        );
  }

  bool _onScrollNotification(UserScrollNotification notification) {
    if (!shouldReactToNowDisplayingScroll(
      axis: notification.metrics.axis,
      maxScrollExtent: notification.metrics.maxScrollExtent,
    )) {
      return false;
    }

    final notifier = ref.read(nowDisplayingVisibilityProvider.notifier);

    switch (notification.direction) {
      case ScrollDirection.reverse:
        notifier.setNowDisplayingVisibility(false);
      case ScrollDirection.forward:
        notifier.setNowDisplayingVisibility(true);
      case ScrollDirection.idle:
        break;
    }

    // Do not stop the notification from bubbling.
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return NotificationListener<UserScrollNotification>(
      onNotification: _onScrollNotification,
      child: widget.child,
    );
  }
}
