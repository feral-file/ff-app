import 'package:app/app/providers/navigation_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('NavigationNotifier', () {
    test('initial state has default route', () {
      final container = ProviderContainer.test();
      addTearDown(container.dispose);

      final state = container.read(navigationStateProvider);

      expect(state.currentRoute, equals('/'));
    });

    test('updateRoute changes current route', () {
      final container = ProviderContainer.test();
      addTearDown(container.dispose);

      container.read(navigationStateProvider.notifier).updateRoute('/channels');

      final state = container.read(navigationStateProvider);
      expect(state.currentRoute, equals('/channels'));
    });

    test('copyWith creates new state with updated values', () {
      const state = NavigationState();
      final newState = state.copyWith(currentRoute: '/playlists');

      expect(newState.currentRoute, equals('/playlists'));
      expect(state.currentRoute, equals('/')); // Original unchanged
    });
  });
}
