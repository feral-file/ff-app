import 'package:app/design/text_selection_on_dark_surface.dart';
import 'package:app/theme/app_color.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'dark content surface selection uses distinct highlight, not auQuickSilver',
    () {
      final theme = textSelectionThemeForDarkContentSurface();
      expect(theme.selectionColor, isNot(equals(AppColor.auQuickSilver)));
      expect(theme.selectionColor!.a, greaterThan(0));
      expect(theme.selectionColor!.a, lessThanOrEqualTo(1));
      expect(theme.cursorColor, equals(AppColor.feralFileLightBlue));
      expect(theme.selectionHandleColor, equals(AppColor.feralFileLightBlue));
    },
  );
}
