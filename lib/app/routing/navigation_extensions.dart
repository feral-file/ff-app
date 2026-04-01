import 'package:app/app/routing/previous_page_title_extra.dart';
import 'package:app/app/routing/previous_page_title_scope.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Extension methods for navigation with go_router.
extension NavigationExtensions on BuildContext {
  /// Pushes [location] while attaching the current screen title (when
  /// available) so the next route can label its back control with the previous
  /// page title.
  ///
  /// Note: go_router supports a single `extra` payload; this helper only
  /// supplies [PreviousPageTitleExtra] when the caller didn't already provide
  /// an [extra] object.
  Future<T?> pushWithPreviousTitle<T extends Object?>(
    String location, {
    Object? extra,
  }) {
    final scopeTitle = PreviousPageTitleScope.maybeOf(this);
    final effectiveExtra = extra ?? previousPageTitleExtraFromTitle(scopeTitle);
    return push<T>(location, extra: effectiveExtra);
  }

  /// Named-route variant of [pushWithPreviousTitle].
  Future<T?> pushNamedWithPreviousTitle<T extends Object?>(
    String name, {
    Map<String, String> pathParameters = const <String, String>{},
    Map<String, dynamic> queryParameters = const <String, dynamic>{},
    Object? extra,
  }) {
    final scopeTitle = PreviousPageTitleScope.maybeOf(this);
    final effectiveExtra = extra ?? previousPageTitleExtraFromTitle(scopeTitle);
    return pushNamed<T>(
      name,
      pathParameters: pathParameters,
      queryParameters: queryParameters,
      extra: effectiveExtra,
    );
  }

  /// Pops routes until the target route is reached.
  ///
  /// This method will:
  /// 1. Pop routes one by one until the target route is found in the stack
  /// 2. If the target route is not in the stack, navigate to it using [go]
  ///
  /// Note: In go_router, [go] will navigate to the route and clear everything
  /// above it if the route exists in the navigation history, or navigate to
  /// it if it doesn't exist.
  ///
  /// Usage:
  /// ```dart
  /// context.popUntil(Routes.startSetupFf1);
  /// ```
  void popUntil(String targetRoute) {
    final router = GoRouter.of(this);
    String matchedPath() {
      final p = router.routerDelegate.state.matchedLocation;
      return p.isEmpty ? '/' : p;
    }

    final currentLocation = matchedPath();

    // If we're already at the target route, do nothing
    if (currentLocation == targetRoute) {
      return;
    }

    // Try to pop routes until we reach the target
    // We'll pop while we can and check if we've reached the target
    while (router.canPop()) {
      final locationBeforePop = matchedPath();

      // If we're at the target, stop
      if (locationBeforePop == targetRoute) {
        return;
      }

      // Pop one route
      router.pop();

      // Check if we're now at the target after popping
      final locationAfterPop = matchedPath();
      if (locationAfterPop == targetRoute) {
        return;
      }
    }

    // If we can't pop anymore and we're not at the target,
    // navigate to it using go() which will handle the navigation appropriately
    router.go(targetRoute);
  }
}
