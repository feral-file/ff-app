import 'package:app/app/now_displaying/now_displaying_visibility_config.dart';
import 'package:app/app/routing/routes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Current route state in the app, including path and top route (modal/drawer).
///
/// Single source of truth for route state. Updated by [AppRouteObserver]
/// on Navigator push/pop/replace.
@immutable
class AppRouteState {
  const AppRouteState({
    required this.path,
    required this.currentRoute,
  });

  /// Current route path from Go Router (e.g. [Routes.home], [Routes.playlists]).
  final String path;

  /// Top route on the Navigator stack. Null when no route.
  final Route<dynamic>? currentRoute;

  /// True when the top route is a modal/drawer that hides the Now Displaying bar.
  ///
  /// Uses [isRouteThatHidesNowDisplaying] from config.
  bool get hasModalOrDrawer =>
      isRouteThatHidesNowDisplaying(currentRoute);

  AppRouteState copyWith({
    String? path,
    Route<dynamic>? currentRoute,
  }) {
    return AppRouteState(
      path: path ?? this.path,
      currentRoute: currentRoute ?? this.currentRoute,
    );
  }
}

/// Provider for current route state. Updated by [AppRouteObserver].
final currentRouteProvider =
    NotifierProvider<CurrentRouteNotifier, AppRouteState>(
      CurrentRouteNotifier.new,
    );

class CurrentRouteNotifier extends Notifier<AppRouteState> {
  @override
  AppRouteState build() {
    return const AppRouteState(
      path: Routes.home,
      currentRoute: null,
    );
  }

  /// Updates the current route state. Called by [AppRouteObserver].
  void update(String path, Route<dynamic>? currentRoute) {
    state = AppRouteState(
      path: path.isEmpty ? Routes.home : path,
      currentRoute: currentRoute,
    );
  }
}
