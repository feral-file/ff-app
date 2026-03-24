import 'package:go_router/go_router.dart';

/// Extension methods for GoRouter to handle smart navigation:
/// - Replace if navigating within same route family
/// - Push if navigating to different route family
extension SmartNavigation on GoRouter {
  /// Navigates to a route, replacing if already on same route family, else pushing.
  ///
  /// Example:
  /// - Currently on `/works/item-123`, call `smartPush('/works/item-456')`
  ///   → Replaces with new work detail
  /// - Currently on `/playlists/list-1`, call `smartPush('/works/item-123')`
  ///   → Pushes new work detail (can go back)
  /// - Currently on `/works/item-123`, call `smartPush('/works/item-123')`
  ///   → No-op (already on same work)
  void smartPush(String location) {
    final currentPath = routerDelegate.currentConfiguration.fullPath;
    
    // Extract the base route (e.g., '/works' from '/works/item-123')
    final currentBase = _extractBaseRoute(currentPath);
    final targetBase = _extractBaseRoute(location);
    
    // If same route family (e.g., both are /works/*), replace instead of push
    if (currentBase == targetBase && currentPath != location) {
      replace<void>(location);
    } else if (currentPath != location) {
      // Different route family or different target, push normally
      push(location);
    }
    // If already on exact same location, do nothing (no-op)
  }

  /// Extracts the base route from a full path.
  /// Example: '/works/item-123' → '/works'
  String _extractBaseRoute(String path) {
    // Split by '/' and take the first part (after empty string from leading /)
    final parts = path.split('/');
    if (parts.length > 1) {
      return '/${parts[1]}'; // e.g., '/works'
    }
    return path;
  }
}
