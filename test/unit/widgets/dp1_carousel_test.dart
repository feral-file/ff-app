import 'package:app/domain/models/playlist_item.dart';
import 'package:app/widgets/dp1_carousel.dart';
import 'package:app/widgets/work_item_thumbnail.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DP1Carousel', () {
    testWidgets(
      'renders SizedBox.shrink when items empty and not loading',
      (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: DP1Carousel(
                items: [],
              ),
            ),
          ),
        );

        expect(find.byType(CustomScrollView), findsNothing);
        expect(find.byType(SizedBox), findsWidgets);
      },
    );

    testWidgets(
      'delays loading skeleton by 500ms when items empty and isLoading true',
      (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: DP1Carousel(
                items: [],
                isLoading: true,
              ),
            ),
          ),
        );

        // Delayed state keeps layout height but hides skeleton.
        expect(find.byType(CustomScrollView), findsNothing);
        expect(find.byType(WorkItemThumbnail), findsNothing);

        await tester.pump(const Duration(milliseconds: 500));

        expect(find.byType(CustomScrollView), findsOneWidget);
        expect(find.byType(WorkItemThumbnail), findsWidgets);
      },
    );

    testWidgets(
      'renders carousel with items when items not empty',
      (tester) async {
        const items = [
          PlaylistItem(
            id: 'item_1',
            kind: PlaylistItemKind.dp1Item,
            title: 'Work 1',
          ),
        ];

        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: DP1Carousel(
                items: items,
              ),
            ),
          ),
        );

        expect(find.byType(CustomScrollView), findsOneWidget);
        expect(find.byType(WorkItemThumbnail), findsOneWidget);
      },
    );

    testWidgets(
      'when items not empty, isLoading is ignored',
      (tester) async {
        const items = [
          PlaylistItem(
            id: 'item_1',
            kind: PlaylistItemKind.dp1Item,
            title: 'Work 1',
          ),
        ];

        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: DP1Carousel(
                items: items,
                isLoading: true,
              ),
            ),
          ),
        );

        // Should show actual items, not placeholder count
        expect(find.byType(WorkItemThumbnail), findsOneWidget);
      },
    );
  });
}
