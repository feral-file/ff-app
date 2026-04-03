import 'package:app/app/routing/current_navigation_titles_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('currentVisiblePageTitleProvider', () {
    test('restores the previous title when the top scope is removed', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(currentVisiblePageTitleProvider.notifier);
      final tokenA = Object();
      final tokenB = Object();

      notifier
        ..upsert(token: tokenA, title: 'Playlists')
        ..upsert(token: tokenB, title: 'Work A');
      expect(container.read(currentVisiblePageTitleProvider), 'Work A');

      notifier.remove(tokenB);
      expect(container.read(currentVisiblePageTitleProvider), 'Playlists');
    });

    test('updating a lower entry does not displace the current top title', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(currentVisiblePageTitleProvider.notifier);
      final tokenA = Object();
      final tokenB = Object();

      notifier
        ..upsert(token: tokenA, title: 'Playlists')
        ..upsert(token: tokenB, title: 'Work A')
        ..upsert(token: tokenA, title: 'Playlists Updated');

      expect(container.read(currentVisiblePageTitleProvider), 'Work A');
    });
  });
}
