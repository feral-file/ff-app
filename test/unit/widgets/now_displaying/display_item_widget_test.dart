import 'package:app/domain/models/dp1/dp1_manifest.dart';
import 'package:app/domain/models/playlist_item.dart';
import 'package:app/widgets/now_displaying_bar/display_item.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'expanded row tap counts in padding above thumbnail (transparent hit fill)',
    (tester) async {
      var tapCount = 0;
      const item = PlaylistItem(
        id: 'id',
        kind: PlaylistItemKind.indexerToken,
        title: 'Short',
        artists: [DP1Artist(name: 'Artist', id: '1')],
        thumbnailUrl: null,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: SizedBox(
              width: 360,
              child: NowDisplayingDisplayItem(
                item: item,
                isPlaying: false,
                isInExpandedView: true,
                onTap: () => tapCount++,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final rect = tester.getRect(find.byType(NowDisplayingDisplayItem));
      // Row can be taller than the thumbnail; centered thumbnail leaves a
      // vertical strip above the image that deferToChild would not hit.
      await tester.tapAt(Offset(rect.left + 12, rect.top + 1));
      await tester.pump();
      expect(tapCount, 1);
    },
  );
}
