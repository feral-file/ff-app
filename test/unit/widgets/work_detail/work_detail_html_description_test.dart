import 'package:app/design/text_selection_on_dark_surface.dart';
import 'package:app/widgets/dark_surface_html_selection.dart';
import 'package:app/widgets/work_detail/work_detail_html_description.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:html/dom.dart' as dom;

void main() {
  testWidgets(
    'WorkDetailHtmlDescription wraps HtmlWidget with dark-surface selection',
    (tester) async {
      Map<String, String>? styles(dom.Element element) => null;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WorkDetailHtmlDescription(
              descriptionHtml: '<p>Hello</p>',
              textStyle: const TextStyle(color: Colors.white),
              customStylesBuilder: styles,
              onTapUrl: (_) async => false,
            ),
          ),
        ),
      );

      expect(find.byType(WorkDetailHtmlDescription), findsOneWidget);
      expect(find.byType(DarkSurfaceHtmlSelection), findsOneWidget);
      expect(find.byType(HtmlWidget), findsOneWidget);

      final selectionContext = tester.element(find.byType(SelectionArea));
      final resolved = Theme.of(selectionContext).textSelectionTheme;
      final expected = textSelectionThemeForDarkContentSurface();
      expect(resolved.selectionColor, expected.selectionColor);
      expect(resolved.cursorColor, expected.cursorColor);
      expect(resolved.selectionHandleColor, expected.selectionHandleColor);
    },
  );
}
