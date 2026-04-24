import 'package:app/app/providers/ff1_bluetooth_device_providers.dart';
import 'package:app/app/providers/ff1_wifi_providers.dart';
import 'package:app/app/providers/now_displaying_provider.dart';
import 'package:app/app/providers/seed_database_ready_provider.dart';
import 'package:app/app/providers/works_provider.dart';
import 'package:app/domain/models/ff1_device.dart';
import 'package:app/domain/models/now_displaying_object.dart';
import 'package:app/domain/models/playlist_item.dart';
import 'package:app/infra/config/app_state_service.dart';
import 'package:app/infra/ff1/wifi_protocol/ff1_wifi_messages.dart';
import 'package:app/ui/screens/work_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../app/providers/provider_test_helpers.dart';

const _workId = 'work_refresh_menu_test';
const _ff1Device = FF1Device(
  name: 'Test FF1',
  remoteId: 'remote-1',
  deviceId: 'device-1',
  topicId: 'topic-refresh-test',
);

final _playlistItem = PlaylistItem(
  id: _workId,
  kind: PlaylistItemKind.dp1Item,
  title: 'Refresh menu test work',
);

NowDisplayingSuccess _nowPlayingThisWork() {
  return NowDisplayingSuccess(
    DP1NowDisplayingObject(
      connectedDevice: _ff1Device,
      index: 0,
      items: [_playlistItem],
      isSleeping: false,
    ),
  );
}

NowDisplayingSuccess _nowPlayingOtherWork() {
  return NowDisplayingSuccess(
    DP1NowDisplayingObject(
      connectedDevice: _ff1Device,
      index: 0,
      items: [
        PlaylistItem(
          id: 'other_work_id',
          kind: PlaylistItemKind.dp1Item,
          title: 'Other',
        ),
      ],
      isSleeping: false,
    ),
  );
}

class _SeedNotReadyNotifier extends SeedDatabaseReadyNotifier {
  @override
  bool build() => false;
}

class _StaticWorkDetailNotifier extends WorkDetailNotifier {
  // ignore: matching_super_parameters
  _StaticWorkDetailNotifier(super.itemId, this._state);

  final AsyncValue<WorkDetailData?> _state;

  @override
  AsyncValue<WorkDetailData?> build() => _state;
}

class _StaticNowDisplayingNotifier extends NowDisplayingNotifier {
  _StaticNowDisplayingNotifier(this._status);

  final NowDisplayingStatus _status;

  @override
  NowDisplayingStatus build() => _status;
}

class _RefreshCapturingWifiControl extends FakeWifiControl {
  String? lastRefreshTopicId;

  @override
  Future<FF1CommandResponse> refreshArtwork({required String topicId}) async {
    lastRefreshTopicId = topicId;
    return FF1CommandResponse(status: 'ok');
  }
}

/// Minimal fake so [FFDisplayButton] tooltip logic does not touch ObjectBox.
class _WorkDetailTestAppState implements AppStateService {
  @override
  Future<bool> hasSeenPlayToFf1Tooltip() async => true;

  @override
  Future<void> setHasSeenPlayToFf1Tooltip({required bool hasSeen}) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('Work detail overflow — Refresh artwork on FF1', () {
    testWidgets(
      'shows the action when this work is playing on FF1 and sends refreshArtwork',
      (tester) async {
        final wifi = _RefreshCapturingWifiControl();

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              appStateServiceProvider.overrideWithValue(_WorkDetailTestAppState()),
              activeFF1BluetoothDeviceProvider.overrideWith(
                (ref) => Stream<FF1Device?>.value(null),
              ),
              isSeedDatabaseReadyProvider.overrideWith(_SeedNotReadyNotifier.new),
              workDetailStateProvider(_workId).overrideWith(
                () => _StaticWorkDetailNotifier(
                  _workId,
                  AsyncValue.data(WorkDetailData(item: _playlistItem)),
                ),
              ),
              nowDisplayingProvider.overrideWith(
                () => _StaticNowDisplayingNotifier(_nowPlayingThisWork()),
              ),
              ff1WifiControlProvider.overrideWithValue(wifi),
              ownerAddressesProvider.overrideWith((ref) async => []),
            ],
            child: const MaterialApp(
              home: WorkDetailScreen(workId: _workId),
            ),
          ),
        );

        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const ValueKey('work_detail_overflow_menu')));
        await tester.pumpAndSettle();

        expect(find.text('Refresh artwork on FF1'), findsOneWidget);

        await tester.tap(find.text('Refresh artwork on FF1'));
        await tester.pumpAndSettle();

        expect(wifi.lastRefreshTopicId, _ff1Device.topicId);
      },
    );

    testWidgets(
      'hides the action when another work is playing on FF1',
      (tester) async {
        final wifi = _RefreshCapturingWifiControl();

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              appStateServiceProvider.overrideWithValue(_WorkDetailTestAppState()),
              activeFF1BluetoothDeviceProvider.overrideWith(
                (ref) => Stream<FF1Device?>.value(null),
              ),
              isSeedDatabaseReadyProvider.overrideWith(_SeedNotReadyNotifier.new),
              workDetailStateProvider(_workId).overrideWith(
                () => _StaticWorkDetailNotifier(
                  _workId,
                  AsyncValue.data(WorkDetailData(item: _playlistItem)),
                ),
              ),
              nowDisplayingProvider.overrideWith(
                () => _StaticNowDisplayingNotifier(_nowPlayingOtherWork()),
              ),
              ff1WifiControlProvider.overrideWithValue(wifi),
              ownerAddressesProvider.overrideWith((ref) async => []),
            ],
            child: const MaterialApp(
              home: WorkDetailScreen(workId: _workId),
            ),
          ),
        );

        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const ValueKey('work_detail_overflow_menu')));
        await tester.pumpAndSettle();

        expect(find.text('Refresh artwork on FF1'), findsNothing);
        expect(wifi.lastRefreshTopicId, isNull);
      },
    );
  });
}
