import 'package:app/app/patrol/gold_path_patrol_keys.dart';
import 'package:app/widgets/home_index_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('HomeIndexHeader avoids overflow on narrow widths', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 184,
            child: HomeIndexHeader(
              selectedTab: HomeIndexHeaderTab.playlists,
              onTabChanged: (_) {},
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byKey(GoldPathPatrolKeys.playlistsTab), findsOneWidget);
    expect(find.byKey(GoldPathPatrolKeys.channelsTab), findsOneWidget);
    expect(find.text('Works'), findsOneWidget);
  });
}
