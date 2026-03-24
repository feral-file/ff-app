import 'package:app/app/routing/router_extensions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  group('SmartNavigation.smartPush', () {
    late GoRouter router;

    setUp(() {
      // Create a GoRouter with routes for testing
      router = GoRouter(
        initialLocation: '/',
        routes: [
          GoRoute(
            path: '/',
            name: 'home',
            builder: (context, state) => Container(),
          ),
          GoRoute(
            path: '/works/:workId',
            name: 'work-detail',
            builder: (context, state) => Container(),
          ),
          GoRoute(
            path: '/playlists/:playlistId',
            name: 'playlist-detail',
            builder: (context, state) => Container(),
          ),
        ],
      );
    });

    test('no-op when already on exact same location', () async {
      // Navigate to a work detail first
      router.goNamed('work-detail', pathParameters: {'workId': 'item-123'});
      await Future<void>.delayed(const Duration(milliseconds: 100));

      // Get the stack size before smartPush
      final initialStackSize =
          router.routerDelegate.currentConfiguration.routes.length;

      // Call smartPush with same location - should be no-op
      router.smartPush('/works/item-123');
      await Future<void>.delayed(const Duration(milliseconds: 100));

      // Stack size should not change
      expect(
        router.routerDelegate.currentConfiguration.routes.length,
        initialStackSize,
      );
    });

    test('replaces when navigating to different work in same family', () async {
      // Navigate to work-detail for item-123
      router.goNamed('work-detail', pathParameters: {'workId': 'item-123'});
      await Future<void>.delayed(const Duration(milliseconds: 100));

      final initialStackSize =
          router.routerDelegate.currentConfiguration.routes.length;

      // Call smartPush for different work - should replace
      router.smartPush('/works/item-456');
      await Future<void>.delayed(const Duration(milliseconds: 100));

      // Stack size should stay same (replace, not push)
      expect(
        router.routerDelegate.currentConfiguration.routes.length,
        initialStackSize,
      );

      // Location should be updated to new work
      expect(
        router.routerDelegate.currentConfiguration.uri.path,
        '/works/item-456',
      );
    });

    test('pushes when navigating to different route family', () async {
      // Navigate to playlist-detail
      router.goNamed(
        'playlist-detail',
        pathParameters: {'playlistId': 'list-1'},
      );
      await Future<void>.delayed(const Duration(milliseconds: 100));

      final initialStackSize =
          router.routerDelegate.currentConfiguration.routes.length;

      // Call smartPush to work detail (different family) - should push
      router.smartPush('/works/item-123');
      await Future<void>.delayed(const Duration(milliseconds: 100));

      // Stack size should increase (push, not replace)
      expect(
        router.routerDelegate.currentConfiguration.routes.length,
        greaterThan(initialStackSize),
      );
    });
  });
}
