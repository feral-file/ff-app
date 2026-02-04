import 'package:app/design/app_typography.dart';
import 'package:app/design/layout_constants.dart';
import 'package:app/theme/app_color.dart';
import 'package:flutter/material.dart';

/// Application theme configuration.
///
/// Note: UI text must use [AppTypography]. We keep [ThemeData] minimal to avoid
/// duplicating typography scale in multiple places.
class AppTheme {
  /// Light theme configuration.
  static ThemeData lightTheme() {
    return ThemeData(
      fontFamily: AppTypography.ppMori,
      textSelectionTheme: const TextSelectionThemeData(
        cursorColor: AppColor.auQuickSilver,
        selectionHandleColor: AppColor.auQuickSilver,
        selectionColor: AppColor.auQuickSilver,
      ),
      primaryColor: AppColor.primaryBlack,
      scaffoldBackgroundColor: AppColor.white,
      colorScheme: const ColorScheme(
        primary: AppColor.primaryBlack,
        onPrimary: AppColor.white,
        secondary: AppColor.white,
        onSecondary: AppColor.primaryBlack,
        brightness: Brightness.light,
        error: AppColor.error,
        onError: AppColor.white,
        surface: AppColor.white,
        onSurface: AppColor.primaryBlack,
      ),
      primaryIconTheme: IconThemeData(
          color: AppColor.primaryBlack,
        size: LayoutConstants.iconSizeLarge,
      ),
    );
  }

  /// Tablet theme configuration.
  ///
  /// We keep this aligned with [lightTheme] for now. If tablet-specific
  /// typography is needed later, implement it via [AppTypography] + layout
  /// breakpoints (not hard-coded font sizes in ThemeData).
  static ThemeData tabletLightTheme() => lightTheme();
}
