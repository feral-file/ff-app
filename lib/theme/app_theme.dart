import 'package:app/design/app_typography.dart';
import 'package:app/design/layout_constants.dart';
import 'package:app/theme/app_color.dart';
import 'package:flutter/material.dart';

/// Application theme configuration.
///
/// Note: UI text must use [AppTypography]. We keep [ThemeData] minimal to avoid
/// duplicating typography scale in multiple places.
class AppTheme {
  static const double _cupertinoPressedOpacity = 0.12;

  static final WidgetStateProperty<Color?> _cupertinoOverlayColor =
      WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.pressed)) {
          return AppColor.primaryBlack.withValues(
            alpha: _cupertinoPressedOpacity,
          );
        }
        if (states.contains(WidgetState.focused) ||
            states.contains(WidgetState.hovered)) {
          return AppColor.primaryBlack.withValues(alpha: 0.04);
        }
        return Colors.transparent;
      });

  /// Light theme configuration.
  static ThemeData lightTheme() {
    return ThemeData(
      fontFamily: AppTypography.ppMori,
      splashFactory: NoSplash.splashFactory,
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      textSelectionTheme: const TextSelectionThemeData(
        cursorColor: AppColor.auQuickSilver,
        selectionHandleColor: AppColor.auQuickSilver,
        selectionColor: AppColor.auQuickSilver,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ButtonStyle(
          splashFactory: NoSplash.splashFactory,
          overlayColor: _cupertinoOverlayColor,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: ButtonStyle(
          splashFactory: NoSplash.splashFactory,
          overlayColor: _cupertinoOverlayColor,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: ButtonStyle(
          splashFactory: NoSplash.splashFactory,
          overlayColor: _cupertinoOverlayColor,
        ),
      ),
      primaryColor: AppColor.primaryBlack,
      scaffoldBackgroundColor: AppColor.white,
      colorScheme: const ColorScheme(
        primary: AppColor.primaryBlack,
        onPrimary: AppColor.primaryBlack,
        secondary: AppColor.white,
        onSecondary: AppColor.white,
        brightness: Brightness.dark,
        error: AppColor.red,
        onError: AppColor.red,
        surface: AppColor.secondaryDimGrey,
        onSurface: AppColor.auLightGrey,
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
