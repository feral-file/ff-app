import 'package:app/design/text_selection_on_dark_surface.dart';
import 'package:app/widgets/channel_item.dart';
import 'package:app/widgets/dark_surface_html_selection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';

void main() {
  testWidgets(
    'ChannelHeader renders summary as plain Text by default',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ChannelHeader(
              channelId: 'ch_1',
              channelTitle: 'A channel',
              channelSummary: '<em>Hello</em>',
              clickable: false,
            ),
          ),
        ),
      );

      expect(find.byType(HtmlWidget), findsNothing);
      expect(find.text('<em>Hello</em>'), findsOneWidget);
    },
  );

  testWidgets(
    'ChannelHeader renders summary via HtmlWidget when enabled',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ChannelHeader(
              channelId: 'ch_1',
              channelTitle: 'A channel',
              channelSummary: '<em>Hello</em>',
              clickable: false,
              renderSummaryAsHtml: true,
            ),
          ),
        ),
      );

      expect(find.byType(HtmlWidget), findsOneWidget);
      expect(find.text('<em>Hello</em>'), findsNothing);
    },
  );

  testWidgets(
    'ChannelHeader HTML summary uses dark-surface text selection theme',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ChannelHeader(
              channelId: 'ch_1',
              channelTitle: 'A channel',
              channelSummary: '<p>Summary</p>',
              clickable: false,
              renderSummaryAsHtml: true,
            ),
          ),
        ),
      );

      expect(find.byType(DarkSurfaceHtmlSelection), findsOneWidget);
      final selectionContext = tester.element(find.byType(SelectionArea));
      final resolved = Theme.of(selectionContext).textSelectionTheme;
      final expected = textSelectionThemeForDarkContentSurface();
      expect(resolved.selectionColor, expected.selectionColor);
      expect(resolved.cursorColor, expected.cursorColor);
      expect(resolved.selectionHandleColor, expected.selectionHandleColor);
    },
  );

  testWidgets(
    r'ChannelHeader preserves blank lines from \n\n when rendered as HTML',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ChannelHeader(
              channelId: 'ch_1',
              channelTitle: 'A channel',
              channelSummary: 'Title\n\nDescription',
              clickable: false,
              renderSummaryAsHtml: true,
            ),
          ),
        ),
      );

      final richTexts = tester.widgetList<RichText>(find.byType(RichText));
      final combinedPlainText = richTexts
          .map((rt) => rt.text.toPlainText())
          .join('\n---\n');

      expect(combinedPlainText.contains('Title\n\nDescription'), isTrue);
    },
  );
}
