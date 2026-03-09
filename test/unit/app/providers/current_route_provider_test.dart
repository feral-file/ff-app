import 'package:app/app/providers/current_route_provider.dart';
import 'package:app/app/routing/routes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CurrentRouteNotifier', () {
    test('initial state has home path and null currentRoute', () {
      final container = ProviderContainer.test();
      addTearDown(container.dispose);

      final state = container.read(currentRouteProvider);

      expect(state.path, Routes.home);
      expect(state.currentRoute, isNull);
      expect(state.hasModalOrDrawer, isFalse);
    });

    test('update sets path and currentRoute', () {
      final container = ProviderContainer.test();
      addTearDown(container.dispose);

      container.read(currentRouteProvider.notifier).update(
            Routes.playlists,
            null,
          );

      final state = container.read(currentRouteProvider);
      expect(state.path, Routes.playlists);
      expect(state.currentRoute, isNull);
      expect(state.hasModalOrDrawer, isFalse);
    });

    test('update with empty path uses home', () {
      final container = ProviderContainer.test();
      addTearDown(container.dispose);

      container.read(currentRouteProvider.notifier).update('', null);

      final state = container.read(currentRouteProvider);
      expect(state.path, Routes.home);
    });

    test('hasModalOrDrawer is true when currentRoute is ModalBottomSheetRoute',
        () {
      final container = ProviderContainer.test();
      addTearDown(container.dispose);

      final route = ModalBottomSheetRoute<void>(
        isScrollControlled: false,
        builder: (context) => const SizedBox.shrink(),
      );

      container.read(currentRouteProvider.notifier).update(
            Routes.home,
            route,
          );

      final state = container.read(currentRouteProvider);
      expect(state.currentRoute, isA<ModalBottomSheetRoute>());
      expect(state.hasModalOrDrawer, isTrue);
    });

    test('hasModalOrDrawer is false when currentRoute is PageRoute', () {
      final container = ProviderContainer.test();
      addTearDown(container.dispose);

      final route = MaterialPageRoute<void>(
        builder: (context) => const SizedBox.shrink(),
      );

      container.read(currentRouteProvider.notifier).update(
            Routes.channels,
            route,
          );

      final state = container.read(currentRouteProvider);
      expect(state.currentRoute, isA<MaterialPageRoute>());
      expect(state.hasModalOrDrawer, isFalse);
    });

    test('update with null currentRoute clears modal state', () {
      final container = ProviderContainer.test();
      addTearDown(container.dispose);

      final route = ModalBottomSheetRoute<void>(
        isScrollControlled: false,
        builder: (context) => const SizedBox.shrink(),
      );
      container.read(currentRouteProvider.notifier).update(Routes.home, route);
      expect(container.read(currentRouteProvider).hasModalOrDrawer, isTrue);

      container.read(currentRouteProvider.notifier).update(Routes.home, null);
      expect(container.read(currentRouteProvider).hasModalOrDrawer, isFalse);
    });
  });

  group('AppRouteState', () {
    test('copyWith preserves unspecified fields', () {
      const state = AppRouteState(path: '/foo', currentRoute: null);
      final updated = state.copyWith(path: '/bar');

      expect(updated.path, '/bar');
      expect(updated.currentRoute, isNull);
    });
  });
}
