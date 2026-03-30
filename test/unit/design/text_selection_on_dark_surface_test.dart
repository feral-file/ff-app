import 'package:app/design/text_selection_on_dark_surface.dart';
import 'package:app/theme/app_color.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'dark content surface selection uses feralFileLightBlue at 0.45 alpha',
    () {
      final theme = textSelectionThemeForDarkContentSurface();
      final expectedSelection =
          AppColor.feralFileLightBlue.withValues(alpha: 0.45);
      expect(theme.selectionColor, equals(expectedSelection));
      expect(theme.cursorColor, equals(AppColor.feralFileLightBlue));
      expect(
        theme.selectionHandleColor,
        equals(AppColor.feralFileLightBlue),
      );
    },
  );
}
