import 'package:app/app/now_displaying/now_displaying_visibility_sync.dart';
import 'package:app/app/routing/routes.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('shouldShowNowDisplayingForPath', () {
    test('returns false for hidden routes from legacy behavior', () {
      for (final path in routesThatHideNowDisplayingBar) {
        expect(shouldShowNowDisplayingForPath(path), isFalse);
      }
    });

    test('returns false for children of hidden routes', () {
      expect(
        shouldShowNowDisplayingForPath('${Routes.settings}/nested'),
        isFalse,
      );
      expect(
        shouldShowNowDisplayingForPath('${Routes.onboarding}/nested'),
        isFalse,
      );
    });

    test('returns true for home and DP-1 browsing routes', () {
      expect(shouldShowNowDisplayingForPath(Routes.home), isTrue);
      expect(shouldShowNowDisplayingForPath(Routes.channels), isTrue);
      expect(shouldShowNowDisplayingForPath('${Routes.playlists}/abc'), isTrue);
      expect(shouldShowNowDisplayingForPath('${Routes.works}/xyz'), isTrue);
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
