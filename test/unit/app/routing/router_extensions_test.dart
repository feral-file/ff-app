import 'package:app/app/routing/previous_page_title_extra.dart';
import 'package:app/app/routing/router_extensions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

class _RouteHarness extends StatelessWidget {
  const _RouteHarness({
    required this.onNavigate,
    required this.label,
  });

  final VoidCallback onNavigate;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ElevatedButton(
          onPressed: onNavigate,
          child: Text(label),
        ),
      ),
    );
  }
}

void main() {
  group('SmartNavigation.smartPush', () {
    testWidgets('no-ops when pushing the same matched location', (
      tester,
    ) async {
      late GoRouter router;
      final visitedLocations = <String>[];

      router = GoRouter(
        initialLocation: '/works/work-1',
        routes: [
          GoRoute(
            path: '/works/:workId',
            builder: (context, state) {
              visitedLocations.add(state.matchedLocation);
              return _RouteHarness(
                label: 'Open current work',
                onNavigate: () => router.smartPush('/works/work-1'),
              );
            },
          ),
        ],
      );

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open current work'));
      await tester.pumpAndSettle();

      expect(router.routerDelegate.state.matchedLocation, '/works/work-1');
      expect(visitedLocations, ['/works/work-1']);
    });

    testWidgets('pushes a different work and forwards extra', (tester) async {
      late GoRouter router;
      final visitedLocations = <String>[];
      Object? pushedExtra;

      router = GoRouter(
        initialLocation: '/works/work-1',
        routes: [
          GoRoute(
            path: '/works/:workId',
            builder: (context, state) {
              visitedLocations.add(state.matchedLocation);
              if (state.pathParameters['workId'] == 'work-2') {
                pushedExtra = state.extra;
              }
              return _RouteHarness(
                label: 'Open next work',
                onNavigate: () => router.smartPush(
                  '/works/work-2',
                  extra: const PreviousPageTitleExtra('Work 1'),
                ),
              );
            },
          ),
        ],
      );

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open next work'));
      await tester.pumpAndSettle();

      expect(visitedLocations.first, '/works/work-1');
      expect(visitedLocations, contains('/works/work-2'));
      expect(router.routerDelegate.state.matchedLocation, '/works/work-2');
      expect(previousPageTitleFromExtra(pushedExtra), 'Work 1');
    });

    testWidgets('pushes across route families and forwards extra', (
      tester,
    ) async {
      late GoRouter router;
      final visitedLocations = <String>[];
      Object? pushedExtra;

      router = GoRouter(
        initialLocation: '/playlists/list-1',
        routes: [
          GoRoute(
            path: '/playlists/:playlistId',
            builder: (context, state) {
              visitedLocations.add(state.matchedLocation);
              return _RouteHarness(
                label: 'Open work',
                onNavigate: () => router.smartPush(
                  '/works/work-2',
                  extra: const PreviousPageTitleExtra('Playlists'),
                ),
              );
            },
          ),
          GoRoute(
            path: '/works/:workId',
            builder: (context, state) {
              visitedLocations.add(state.matchedLocation);
              pushedExtra = state.extra;
              return const SizedBox.shrink();
            },
          ),
        ],
      );

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open work'));
      await tester.pumpAndSettle();

      expect(visitedLocations.first, '/playlists/list-1');
      expect(visitedLocations, contains('/works/work-2'));
      expect(router.routerDelegate.state.matchedLocation, '/works/work-2');
      expect(previousPageTitleFromExtra(pushedExtra), 'Playlists');
    });
  });
}
