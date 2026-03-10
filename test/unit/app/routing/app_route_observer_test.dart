import 'package:app/app/routing/app_route_observer.dart';
import 'package:app/app/routing/routes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  group('AppRouteObserver', () {
    testWidgets('calls onRouteChanged on didPush with path and route', (
      tester,
    ) async {
      String? capturedPath;
      Route<dynamic>? capturedRoute;

      await tester.pumpWidget(
        MaterialApp.router(
          routerConfig: GoRouter(
            initialLocation: Routes.home,
            routes: [
              GoRoute(
                path: Routes.home,
                builder: (context, state) => const Scaffold(
                  body: Text('Home'),
                ),
              ),
              GoRoute(
                path: Routes.playlists,
                builder: (context, state) => const Scaffold(
                  body: Text('Playlists'),
                ),
              ),
            ],
            observers: [
              AppRouteObserver(
                onRouteChanged:
                    ({
                      required fromPath,
                      required toPath,
                      required currentRoute,
                    }) {
                      capturedPath = toPath;
                      capturedRoute = currentRoute;
                    },
              ),
            ],
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(capturedPath, Routes.home);
      expect(capturedRoute, isNotNull);
    });

    testWidgets('calls onRouteChanged on push with route', (tester) async {
      final captured = <({String path, bool hasRoute})>[];

      await tester.pumpWidget(
        MaterialApp.router(
          routerConfig: GoRouter(
            initialLocation: Routes.home,
            routes: [
              GoRoute(
                path: Routes.home,
                builder: (context, state) => Scaffold(
                  body: Builder(
                    builder: (context) => TextButton(
                      onPressed: () => context.push(Routes.playlists),
                      child: const Text('Go'),
                    ),
                  ),
                ),
              ),
              GoRoute(
                path: Routes.playlists,
                builder: (context, state) => const Scaffold(
                  body: Text('Playlists'),
                ),
              ),
            ],
            observers: [
              AppRouteObserver(
                onRouteChanged:
                    ({
                      required fromPath,
                      required toPath,
                      required currentRoute,
                    }) {
                      captured.add(
                        (path: toPath, hasRoute: currentRoute != null),
                      );
                    },
              ),
            ],
          ),
        ),
      );

      await tester.pumpAndSettle();
      final initialCount = captured.length;

      await tester.tap(find.text('Go'));
      await tester.pumpAndSettle();

      expect(captured.length, greaterThan(initialCount));
      expect(captured.last.hasRoute, isTrue);
    });
  });
}
