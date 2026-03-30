import 'package:app/design/text_selection_on_dark_surface.dart';
import 'package:app/widgets/dark_surface_html_selection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'DarkSurfaceHtmlSelection applies textSelectionTheme to subtree',
    (tester) async {
      const label = 'Selectable';
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: DarkSurfaceHtmlSelection(
              child: Text(label),
            ),
          ),
        ),
      );

      expect(find.byType(DarkSurfaceHtmlSelection), findsOneWidget);
      expect(find.byType(SelectionArea), findsOneWidget);

      final selectionContext = tester.element(find.byType(SelectionArea));
      final resolved = Theme.of(selectionContext).textSelectionTheme;
      final expected = textSelectionThemeForDarkContentSurface();
      expect(resolved.selectionColor, expected.selectionColor);
      expect(resolved.cursorColor, expected.cursorColor);
      expect(resolved.selectionHandleColor, expected.selectionHandleColor);
    },
  );
}
