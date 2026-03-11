import 'package:app/ui/screens/tabs/tab_reload_guard.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('shouldLoadTabData', () {
    test('returns false while loading', () {
      final shouldLoad = shouldLoadTabData(
        isLoading: true,
        hasCachedItems: false,
        hasError: false,
      );

      expect(shouldLoad, isFalse);
    });

    test('returns false when tab already has cached items', () {
      final shouldLoad = shouldLoadTabData(
        isLoading: false,
        hasCachedItems: true,
        hasError: false,
      );

      expect(shouldLoad, isFalse);
    });

    test('returns true when tab has no items and is idle', () {
      final shouldLoad = shouldLoadTabData(
        isLoading: false,
        hasCachedItems: false,
        hasError: false,
      );

      expect(shouldLoad, isTrue);
    });

    test('returns true when previous load failed', () {
      final shouldLoad = shouldLoadTabData(
        isLoading: false,
        hasCachedItems: true,
        hasError: true,
      );

      expect(shouldLoad, isTrue);
    });
  });
}
