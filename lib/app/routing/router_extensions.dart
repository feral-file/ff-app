import 'dart:async';

import 'package:go_router/go_router.dart';

/// Extension methods for [GoRouter] to push detail routes without stacking
/// duplicates of the same location.
extension SmartNavigation on GoRouter {
  /// Pushes [location] when it differs from the current matched path; otherwise
  /// does nothing.
  ///
  /// Uses [GoRouterState.matchedLocation] (e.g. `/works/item-123`), not the
  /// route pattern (`/works/:workId`), so nested / shell layouts still resolve
  /// correctly.
  ///
  /// Example:
  /// - Currently on `/works/item-123`, call `smartPush('/works/item-456')`
  ///   → Pushes the new work detail (Back returns to the previous screen).
  /// - Currently on `/playlists/list-1`, call `smartPush('/works/item-123')`
  ///   → Pushes work detail.
  /// - Currently on `/works/item-123`, call `smartPush('/works/item-123')`
  ///   → No-op (already on that location).
  void smartPush(String location, {Object? extra}) {
    final path = routerDelegate.state.matchedLocation;
    final currentUri = path.isEmpty ? '/' : path;

    if (currentUri == location) {
      return;
    }
    unawaited(push<void>(location, extra: extra));
  }
}
