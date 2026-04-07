import 'package:app/app/providers/ff1_wifi_providers.dart';
import 'package:app/domain/models/dp1/dp1_playlist_item.dart';
import 'package:app/domain/models/ff1/loop_mode.dart';
import 'package:app/domain/models/ff1_device.dart';
import 'package:app/domain/models/now_displaying_object.dart';
import 'package:app/domain/models/playlist_item.dart';
import 'package:app/infra/ff1/wifi_protocol/ff1_wifi_messages.dart';
import 'package:app/widgets/now_displaying_bar/collapsed_now_playing_bar.dart';
import 'package:app/widgets/now_displaying_bar/loop_button.dart';
import 'package:app/widgets/now_displaying_bar/shuffle_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

DP1NowDisplayingObject playingObjectWithItemCount({
  required int itemCount,
}) {
  const device = FF1Device(
    name: 'FF1',
    remoteId: 'r',
    deviceId: 'd',
    topicId: 't',
  );
  return DP1NowDisplayingObject(
    connectedDevice: device,
    index: 0,
    items: [
      for (var i = 0; i < itemCount; i++)
        PlaylistItem(
          id: 'w$i',
          kind: PlaylistItemKind.dp1Item,
          title: 'Work $i',
        ),
    ],
    isSleeping: false,
  );
}

List<DP1PlaylistItem> dp1Items(int n) {
  return [
    for (var i = 0; i < n; i++)
      DP1PlaylistItem(id: 'w$i', duration: 0, title: 'W$i'),
  ];
}

void main() {
  testWidgets(
    'multi-work: shuffle field present without loop still shows shuffle only',
    (tester) async {
      final status = FF1PlayerStatus(
        playlistId: 'pl',
        shuffle: false,
        items: dp1Items(2),
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ff1CurrentPlayerStatusProvider.overrideWith((ref) => status),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: CollapsedNowPlayingBar(
                playingObject: playingObjectWithItemCount(itemCount: 2),
              ),
            ),
          ),
        ),
      );
      expect(find.byType(ShuffleButton), findsOneWidget);
      expect(find.byType(LoopButton), findsNothing);
    },
  );

  testWidgets('multi-work: loop without shuffle field shows loop only', (
    tester,
  ) async {
    final status = FF1PlayerStatus(
      playlistId: 'pl',
      loopMode: LoopMode.playlist,
      items: dp1Items(2),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ff1CurrentPlayerStatusProvider.overrideWith((ref) => status),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: CollapsedNowPlayingBar(
              playingObject: playingObjectWithItemCount(itemCount: 2),
            ),
          ),
        ),
      ),
    );
    expect(find.byType(ShuffleButton), findsNothing);
    expect(find.byType(LoopButton), findsOneWidget);
  });

  testWidgets('multi-work: both controls when shuffle and loop present', (
    tester,
  ) async {
    final status = FF1PlayerStatus(
      playlistId: 'pl',
      shuffle: true,
      loopMode: LoopMode.none,
      items: dp1Items(2),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ff1CurrentPlayerStatusProvider.overrideWith((ref) => status),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: CollapsedNowPlayingBar(
              playingObject: playingObjectWithItemCount(itemCount: 2),
            ),
          ),
        ),
      ),
    );
    expect(find.byType(ShuffleButton), findsOneWidget);
    expect(find.byType(LoopButton), findsOneWidget);
  });

  testWidgets(
    'single-work: hides shuffle and loop even when device supports them',
    (tester) async {
      final status = FF1PlayerStatus(
        playlistId: 'pl',
        shuffle: true,
        loopMode: LoopMode.playlist,
        items: dp1Items(1),
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ff1CurrentPlayerStatusProvider.overrideWith((ref) => status),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: CollapsedNowPlayingBar(
                playingObject: playingObjectWithItemCount(itemCount: 1),
              ),
            ),
          ),
        ),
      );
      expect(find.byType(ShuffleButton), findsNothing);
      expect(find.byType(LoopButton), findsNothing);
    },
  );

  testWidgets(
    'multi-work: unknown loopMode fromJson still allows shuffle control',
    (tester) async {
      final status = FF1PlayerStatus.fromJson({
        'playlistId': 'pl',
        'shuffle': false,
        'loopMode': 'future_mode',
        'items': [
          {'id': 'w0', 'duration': 0, 'title': 'A'},
          {'id': 'w1', 'duration': 0, 'title': 'B'},
        ],
      });
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ff1CurrentPlayerStatusProvider.overrideWith((ref) => status),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: CollapsedNowPlayingBar(
                playingObject: playingObjectWithItemCount(itemCount: 2),
              ),
            ),
          ),
        ),
      );
      expect(status.loopMode, isNull);
      expect(find.byType(ShuffleButton), findsOneWidget);
      expect(find.byType(LoopButton), findsNothing);
    },
  );
}
