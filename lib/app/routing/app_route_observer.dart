import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// NavigatorObserver that updates current route state on push/pop/replace.
///
/// Calls [onRouteChanged] with the current path (from Go Router) and the top
/// route on the Navigator stack. Used to drive [currentRouteProvider].
class AppRouteObserver extends NavigatorObserver {
  /// Creates an [AppRouteObserver].
  AppRouteObserver({
    required this.onRouteChanged,
  });

  /// Called when the route stack changes (push, pop, replace).
  ///
  /// [path] is from [GoRouter.routerDelegate.state.matchedLocation].
  /// [currentRoute] is the top route on the stack (null when stack is empty).
  final void Function(String path, Route<dynamic>? currentRoute) onRouteChanged;

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

    onRouteChanged(path.isEmpty ? '/' : path, topRoute);
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
