import 'package:app/widgets/playlist/playlist_details_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('PlaylistDetailsHeader shows singular "1 work" when total is 1',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: PlaylistDetailsHeader(
            title: 'My playlist',
            total: 1,
          ),
        ),
      ),
    );

    expect(find.text('1 work'), findsOneWidget);
    expect(find.textContaining('works'), findsNothing);
  });

  testWidgets('PlaylistDetailsHeader shows plural works label when total > 1',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: PlaylistDetailsHeader(
            title: 'My playlist',
            total: 3,
          ),
        ),
      ),
    );

    expect(find.text('3 works'), findsOneWidget);
  });
}
