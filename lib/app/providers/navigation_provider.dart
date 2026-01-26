import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Navigation state provider.
/// Tracks current navigation state for analytics, UI updates, etc.
/// All navigation state flows through Riverpod.
final navigationStateProvider =
    NotifierProvider<NavigationNotifier, NavigationState>(
  NavigationNotifier.new,
);

/// Navigation state notifier.
class NavigationNotifier extends Notifier<NavigationState> {
  @override
  NavigationState build() {
    return const NavigationState();
  }

  /// Updates the current route.
  void updateRoute(String route) {
    state = NavigationState(currentRoute: route);
  }
}

/// Navigation state.
class NavigationState {
  /// Creates a navigation state.
  const NavigationState({
    this.currentRoute = '/',
  });

  /// Current route path.
  final String currentRoute;

  /// Creates a copy with updated values.
  NavigationState copyWith({
    String? currentRoute,
  }) {
    return NavigationState(
      currentRoute: currentRoute ?? this.currentRoute,
    );
  }
}
