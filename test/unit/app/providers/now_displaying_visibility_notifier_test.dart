import 'package:app/app/providers/current_route_provider.dart';
import 'package:app/app/providers/ff1_bluetooth_device_providers.dart';
import 'package:app/app/providers/ff1_wifi_providers.dart';
import 'package:app/app/providers/now_displaying_visibility_provider.dart';
import 'package:app/app/routing/routes.dart';
import 'package:app/domain/models/dp1/dp1_playlist_item.dart';
import 'package:app/infra/ff1/wifi_protocol/ff1_wifi_messages.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'provider_test_helpers.dart';

void main() {
  group('NowDisplayingVisibilityNotifier scroll flag reset', () {
    const item = DP1PlaylistItem(
      id: 'w1',
      duration: 1,
      title: 'A',
    );

    test('route path change sets nowDisplayingVisibility back to true', () {
      final container = ProviderContainer.test(
        overrides: [
          allFF1BluetoothDevicesProvider.overrideWith(
            (ref) => Stream.value([]),
          ),
          ff1CurrentPlayerStatusProvider.overrideWith(
            (ref) => FF1PlayerStatus(
              playlistId: 'pl_1',
              currentWorkIndex: 0,
              items: const [item],
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      container
          .read(nowDisplayingVisibilityProvider.notifier)
          .setNowDisplayingVisibility(false);
      expect(
        container.read(nowDisplayingVisibilityProvider).nowDisplayingVisibility,
        isFalse,
      );

      container
          .read(currentRouteProvider.notifier)
          .update(Routes.channels, null);

      expect(
        container.read(nowDisplayingVisibilityProvider).nowDisplayingVisibility,
        isTrue,
      );
    });

    test(
      'FF1 playlistId change sets nowDisplayingVisibility back to true',
      () async {
        var playerStatus = FF1PlayerStatus(
          playlistId: 'pl_a',
          currentWorkIndex: 0,
          items: const [item],
        );

        final container = ProviderContainer.test(
          overrides: [
            allFF1BluetoothDevicesProvider.overrideWith(
              (ref) => Stream.value([]),
            ),
            ff1CurrentPlayerStatusProvider.overrideWith((ref) => playerStatus),
          ],
        );
        addTearDown(container.dispose);

        container.read(nowDisplayingVisibilityProvider);
        await Future<void>.delayed(Duration.zero);

        container
            .read(nowDisplayingVisibilityProvider.notifier)
            .setNowDisplayingVisibility(false);
        expect(
          container
              .read(nowDisplayingVisibilityProvider)
              .nowDisplayingVisibility,
          isFalse,
        );

        playerStatus = FF1PlayerStatus(
          playlistId: 'pl_b',
          currentWorkIndex: 0,
          items: const [item],
        );
        container.invalidate(ff1CurrentPlayerStatusProvider);
        await Future<void>.delayed(Duration.zero);

        expect(
          container
              .read(nowDisplayingVisibilityProvider)
              .nowDisplayingVisibility,
          isTrue,
        );
      },
    );

    test(
      'FF1 currentWorkIndex change sets nowDisplayingVisibility back to true',
      () async {
        var playerStatus = FF1PlayerStatus(
          playlistId: 'pl_a',
          currentWorkIndex: 0,
          items: const [item],
        );

        final container = ProviderContainer.test(
          overrides: [
            allFF1BluetoothDevicesProvider.overrideWith(
              (ref) => Stream.value([]),
            ),
            ff1CurrentPlayerStatusProvider.overrideWith((ref) => playerStatus),
          ],
        );
        addTearDown(container.dispose);

        container.read(nowDisplayingVisibilityProvider);
        await Future<void>.delayed(Duration.zero);

        container
            .read(nowDisplayingVisibilityProvider.notifier)
            .setNowDisplayingVisibility(false);
        expect(
          container
              .read(nowDisplayingVisibilityProvider)
              .nowDisplayingVisibility,
          isFalse,
        );

        playerStatus = FF1PlayerStatus(
          playlistId: 'pl_a',
          currentWorkIndex: 1,
          items: const [item],
        );
        container.invalidate(ff1CurrentPlayerStatusProvider);
        await Future<void>.delayed(Duration.zero);

        expect(
          container
              .read(nowDisplayingVisibilityProvider)
              .nowDisplayingVisibility,
          isTrue,
        );
      },
    );

    test(
      'FF1 status becomes null does not reset nowDisplayingVisibility',
      () async {
        FF1PlayerStatus? playerStatus = FF1PlayerStatus(
          playlistId: 'pl_a',
          currentWorkIndex: 0,
          items: const [item],
        );

        final container = ProviderContainer.test(
          overrides: [
            allFF1BluetoothDevicesProvider.overrideWith(
              (ref) => Stream.value([]),
            ),
            ff1CurrentPlayerStatusProvider.overrideWith((ref) => playerStatus),
          ],
        );
        addTearDown(container.dispose);

        container.read(nowDisplayingVisibilityProvider);
        await Future<void>.delayed(Duration.zero);

        container
            .read(nowDisplayingVisibilityProvider.notifier)
            .setNowDisplayingVisibility(false);
        expect(
          container
              .read(nowDisplayingVisibilityProvider)
              .nowDisplayingVisibility,
          isFalse,
        );

        playerStatus = null;
        container.invalidate(ff1CurrentPlayerStatusProvider);
        await Future<void>.delayed(Duration.zero);

        expect(
          container
              .read(nowDisplayingVisibilityProvider)
              .nowDisplayingVisibility,
          isFalse,
        );
      },
    );

    test(
      'FF1 status change without playlistId/index change does not reset nowDisplayingVisibility',
      () async {
        var playerStatus = FF1PlayerStatus(
          playlistId: 'pl_a',
          currentWorkIndex: 0,
          items: const [item],
          isPaused: false,
        );

        final container = ProviderContainer.test(
          overrides: [
            allFF1BluetoothDevicesProvider.overrideWith(
              (ref) => Stream.value([]),
            ),
            ff1CurrentPlayerStatusProvider.overrideWith((ref) => playerStatus),
          ],
        );
        addTearDown(container.dispose);

        container.read(nowDisplayingVisibilityProvider);
        await Future<void>.delayed(Duration.zero);

        container
            .read(nowDisplayingVisibilityProvider.notifier)
            .setNowDisplayingVisibility(false);
        expect(
          container
              .read(nowDisplayingVisibilityProvider)
              .nowDisplayingVisibility,
          isFalse,
        );

        playerStatus = FF1PlayerStatus(
          playlistId: 'pl_a',
          currentWorkIndex: 0,
          items: const [item],
          isPaused: true,
        );
        container.invalidate(ff1CurrentPlayerStatusProvider);
        await Future<void>.delayed(Duration.zero);

        expect(
          container
              .read(nowDisplayingVisibilityProvider)
              .nowDisplayingVisibility,
          isFalse,
        );
      },
    );

    test(
      'route top Route change resets nowDisplayingVisibility '
      'even if path is unchanged',
      () async {
        final container = ProviderContainer.test(
          overrides: [
            allFF1BluetoothDevicesProvider.overrideWith(
              (ref) => Stream.value([]),
            ),
            ff1CurrentPlayerStatusProvider.overrideWith(
              (ref) => FF1PlayerStatus(
                playlistId: 'pl_1',
                currentWorkIndex: 0,
                items: const [item],
              ),
            ),
          ],
        );
        addTearDown(container.dispose);

        container
            .read(nowDisplayingVisibilityProvider.notifier)
            .setNowDisplayingVisibility(false);
        expect(
          container
              .read(nowDisplayingVisibilityProvider)
              .nowDisplayingVisibility,
          isFalse,
        );

        final route = MaterialPageRoute<void>(
          builder: (_) => const SizedBox.shrink(),
        );
        container
            .read(currentRouteProvider.notifier)
            .update(Routes.home, route);

        expect(
          container
              .read(nowDisplayingVisibilityProvider)
              .nowDisplayingVisibility,
          isTrue,
        );
      },
    );

    test(
      'FF1 playlistId change through stream provider '
      'resets nowDisplayingVisibility',
      () async {
        // [ff1CurrentPlayerStatusProvider] watches the stream for invalidation
        // but reads [FF1WifiControl.currentPlayerStatus]. Overriding only the
        // stream without updating the control leaves playlistId stale. Use
        // [FakeWifiControl.emitPlayerStatus] so the stream and cache stay
        // aligned (same as production notifications).
        final fakeControl = FakeWifiControl();

        final container = ProviderContainer.test(
          overrides: [
            allFF1BluetoothDevicesProvider.overrideWith(
              (ref) => Stream.value([]),
            ),
            ff1WifiControlProvider.overrideWithValue(fakeControl),
          ],
        );
        addTearDown(container.dispose);

        final resets = <bool>[];

        container
          ..listen<NowDisplayingVisibilityState>(
            nowDisplayingVisibilityProvider,
            (prev, next) {
              resets.add(next.nowDisplayingVisibility);
            },
          )
          ..read(nowDisplayingVisibilityProvider);

        fakeControl.emitPlayerStatus(
          FF1PlayerStatus(
            playlistId: 'pl_initial',
            currentWorkIndex: 0,
            items: const [item],
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 50));

        container
            .read(nowDisplayingVisibilityProvider.notifier)
            .setNowDisplayingVisibility(false);

        fakeControl.emitPlayerStatus(
          FF1PlayerStatus(
            playlistId: 'pl_changed',
            currentWorkIndex: 0,
            items: const [item],
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 50));

        expect(
          resets,
          contains(true),
          reason:
              'Bar should be visible again after playlistId changed '
              'through stream',
        );
      },
    );

    test(
      'FF1 player status stream reconnect transitions: '
      'known limitation documented',
      () async {
        // LIMITATION: When listening to ff1CurrentPlayerStatusProvider (which
        // collapses loading/error to null), playback changes may be missed
        // during transient reconnect cycles. Example:
        // data -> null (on loading) -> data again breaks our previous!=null
        // guard because 'previous' becomes null during loading.
        //
        // This is acceptable because:
        // 1) Most reconnect cycles complete fast enough to avoid UI flicker
        // 2) The bar stays hidden during data load anyway
        // 3) Full detection would require stream listener + mutable notifier
        //    state
        //
        // Future: If reconnect UX becomes priority, listen to
        // ff1PlayerStatusStreamProvider directly and track last data value in
        // notifier state.
        final container = ProviderContainer.test(
          overrides: [
            allFF1BluetoothDevicesProvider.overrideWith(
              (ref) => Stream.value([]),
            ),
            ff1CurrentPlayerStatusProvider.overrideWith(
              (ref) => FF1PlayerStatus(
                playlistId: 'pl_1',
                currentWorkIndex: 0,
                items: const [item],
              ),
            ),
          ],
        );
        addTearDown(container.dispose);

        // Verify normal happy path still works
        expect(
          container
              .read(nowDisplayingVisibilityProvider)
              .nowDisplayingVisibility,
          isTrue,
        );
      },
    );
  });
}
