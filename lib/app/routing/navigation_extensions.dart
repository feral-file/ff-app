import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Extension methods for navigation with go_router.
extension NavigationExtensions on BuildContext {
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
    final currentLocation = router.routerDelegate.currentConfiguration.uri.path;

    // If we're already at the target route, do nothing
    if (currentLocation == targetRoute) {
      return;
    }

    // Try to pop routes until we reach the target
    // We'll pop while we can and check if we've reached the target
    while (router.canPop()) {
      final locationBeforePop = router.routerDelegate.currentConfiguration.uri.path;

      // If we're at the target, stop
      if (locationBeforePop == targetRoute) {
        return;
      }

      // Pop one route
      router.pop();

      // Check if we're now at the target after popping
      final locationAfterPop = router.routerDelegate.currentConfiguration.uri.path;
      if (locationAfterPop == targetRoute) {
        return;
      }
    }

    // If we can't pop anymore and we're not at the target,
    // navigate to it using go() which will handle the navigation appropriately
    router.go(targetRoute);
  }

  /// Replaces all routes in the navigation stack and navigates to a named route.
  ///
  /// This method will:
  /// 1. Clear/replace the entire navigation stack
  /// 2. Navigate to the specified named route
  ///
  /// In go_router, [goNamed] replaces the entire navigation stack and navigates
  /// to the named route, which is the desired behavior for "replace all and push".
  ///
  /// Usage:
  /// ```dart
  /// context.replaceAllAndPushNamed(RouteNames.home);
  /// context.replaceAllAndPushNamed(RouteNames.home, arguments: payload);
  /// ```
  Future<dynamic>? replaceAllAndPushNamed(
    String routeName, {
    Object? arguments,
  }) {
    GoRouter.of(this).goNamed(
      routeName,
      extra: arguments,
    );
    return null;
  }
}
