import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// NavigatorObserver that updates current route state on push/pop/replace.
///
/// Calls onRouteChanged with route-path transitions and the top route.
class AppRouteObserver extends NavigatorObserver {
  /// Creates an [AppRouteObserver].
  AppRouteObserver({
    required this.onRouteChanged,
  });

  /// Called when the route stack changes (push, pop, replace).
  ///
  /// `fromPath` and `toPath` come from matched GoRouter locations.
  /// `currentRoute` is the top route on the stack (null when stack is empty).
  final void Function({
    required String fromPath,
    required String toPath,
    required Route<dynamic>? currentRoute,
  })
  onRouteChanged;

  String _lastPath = '/';
  String _lastRouteType = '';

  void _notify(Route<dynamic>? topRoute) {
    final nav = navigator;
    if (nav == null) return;

    final context = nav.context;
    String path;
    try {
      final router = GoRouter.of(context);
      // Use state.matchedLocation for full path; currentConfiguration.uri.path
      // can return "/" for nested/ShellRoute structures.
      path = router.routerDelegate.state.matchedLocation;
    } on Object {
      path = '/';
    }

    final normalizedPath = path.isEmpty ? '/' : path;
    final routeType = topRoute?.runtimeType.toString() ?? 'none';
    if (_lastPath == normalizedPath && _lastRouteType == routeType) {
      return;
    }

    final previousPath = _lastPath;
    _lastPath = normalizedPath;
    _lastRouteType = routeType;

    onRouteChanged(
      fromPath: previousPath,
      toPath: normalizedPath,
      currentRoute: topRoute,
    );
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    _notify(route);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    _notify(previousRoute);
  }

  @override
  void didReplace({
    Route<dynamic>? newRoute,
    Route<dynamic>? oldRoute,
  }) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    _notify(newRoute);
  }
}
