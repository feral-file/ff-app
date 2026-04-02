import 'package:app/app/now_displaying/now_displaying_visibility_config.dart';
import 'package:app/app/now_displaying/now_displaying_visibility_sync.dart';
import 'package:app/app/providers/current_route_provider.dart';
import 'package:app/app/routing/routes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('shouldShowNowDisplayingForRoute', () {
    test('returns false for hidden routes from legacy behavior', () {
      for (final path in routesThatHideNowDisplayingBar) {
        expect(
          shouldShowNowDisplayingForRoute(
            AppRouteState(path: path, currentRoute: null),
          ),
          isFalse,
        );
      }
    });

    test('returns false for children of hidden routes', () {
      expect(
        shouldShowNowDisplayingForRoute(
          const AppRouteState(
            path: '${Routes.settings}/nested',
            currentRoute: null,
          ),
        ),
        isFalse,
      );
      expect(
        shouldShowNowDisplayingForRoute(
          const AppRouteState(
            path: '${Routes.onboarding}/nested',
            currentRoute: null,
          ),
        ),
        isFalse,
      );
    });

    test('returns false for settings and release-notes routes', () {
      expect(
        shouldShowNowDisplayingForRoute(
          const AppRouteState(path: Routes.settings, currentRoute: null),
        ),
        isFalse,
      );
      expect(
        shouldShowNowDisplayingForRoute(
          const AppRouteState(path: Routes.releaseNotes, currentRoute: null),
        ),
        isFalse,
      );
    });

    test('returns true for home and DP-1 browsing routes', () {
      expect(
        shouldShowNowDisplayingForRoute(
          const AppRouteState(path: Routes.home, currentRoute: null),
        ),
        isTrue,
      );
      expect(
        shouldShowNowDisplayingForRoute(
          const AppRouteState(path: Routes.channels, currentRoute: null),
        ),
        isTrue,
      );
      expect(
        shouldShowNowDisplayingForRoute(
          const AppRouteState(
            path: '${Routes.playlists}/abc',
            currentRoute: null,
          ),
        ),
        isTrue,
      );
      expect(
        shouldShowNowDisplayingForRoute(
          const AppRouteState(
            path: '${Routes.works}/xyz',
            currentRoute: null,
          ),
        ),
        isTrue,
      );
    });

    test('returns false when modal/drawer is shown (route has priority)', () {
      final modalRoute = ModalBottomSheetRoute<void>(
        isScrollControlled: false,
        builder: (context) => const SizedBox.shrink(),
      );
      expect(
        shouldShowNowDisplayingForRoute(
          AppRouteState(path: Routes.home, currentRoute: modalRoute),
        ),
        isFalse,
      );
    });
  });

  group('shouldReactToNowDisplayingScroll', () {
    test('returns false for non-vertical axes', () {
      expect(
        shouldReactToNowDisplayingScroll(
          axis: Axis.horizontal,
          maxScrollExtent: 200,
        ),
        isFalse,
      );
    });

    test('returns false when max scroll extent is below threshold', () {
      expect(
        shouldReactToNowDisplayingScroll(
          axis: Axis.vertical,
          maxScrollExtent: nowDisplayingScrollToggleThreshold - 1,
        ),
        isFalse,
      );
    });

    test('returns true when vertical and threshold is met', () {
      expect(
        shouldReactToNowDisplayingScroll(
          axis: Axis.vertical,
          maxScrollExtent: nowDisplayingScrollToggleThreshold,
        ),
        isTrue,
      );
      expect(
        shouldReactToNowDisplayingScroll(
          axis: Axis.vertical,
          maxScrollExtent: nowDisplayingScrollToggleThreshold + 1,
        ),
        isTrue,
      );
    });
  });
}
