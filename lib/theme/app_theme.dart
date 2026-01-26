import 'package:app/theme/app_color.dart';
import 'package:flutter/material.dart';

/// Application theme configuration
class AppTheme {
  /// PP Mori font family name
  static const String ppMori = 'PP Mori';
  
  /// IBM Plex Mono font family name
  static const String ibmPlexMono = 'IBMPlexMono';

  /// Light theme configuration
  static ThemeData lightTheme() {
    return ThemeData(
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
      primaryIconTheme:
          const IconThemeData(color: AppColor.primaryBlack, size: 24),
      textTheme: const TextTheme(
        displayLarge: TextStyle(
          color: AppColor.primaryBlack,
          fontSize: 40,
          fontWeight: FontWeight.w700,
          fontFamily: ppMori,
        ),
        displayMedium: TextStyle(
          color: AppColor.primaryBlack,
          fontSize: 28,
          fontWeight: FontWeight.w700,
          fontFamily: ppMori,
        ),
        displaySmall: TextStyle(
          color: AppColor.primaryBlack,
          fontSize: 22,
          fontWeight: FontWeight.w700,
          fontFamily: ppMori,
        ),
        headlineMedium: TextStyle(
          color: AppColor.primaryBlack,
          fontSize: 18,
          fontWeight: FontWeight.w700,
          fontFamily: ppMori,
        ),
        headlineSmall: TextStyle(
          color: AppColor.primaryBlack,
          fontSize: 16,
          fontWeight: FontWeight.w700,
          fontFamily: ppMori,
        ),
        labelLarge: TextStyle(
          color: AppColor.primaryBlack,
          fontSize: 14,
          fontWeight: FontWeight.w700,
          fontFamily: ppMori,
        ),
        bodySmall: TextStyle(
          color: AppColor.primaryBlack,
          fontSize: 14,
          fontFamily: ppMori,
        ),
        bodyLarge: TextStyle(
          color: AppColor.primaryBlack,
          fontSize: 16,
          fontFamily: ppMori,
          fontWeight: FontWeight.w400,
        ),
        bodyMedium: TextStyle(
          color: AppColor.primaryBlack,
          fontSize: 16,
          fontFamily: ppMori,
        ),
        titleMedium: TextStyle(
          color: AppColor.primaryBlack,
          fontSize: 16,
          fontFamily: ppMori,
        ),
        titleSmall: TextStyle(
          color: AppColor.primaryBlack,
          fontSize: 12,
          fontFamily: ppMori,
        ),
      ),
      primaryTextTheme: const TextTheme(
        displayLarge: TextStyle(
          color: AppColor.white,
          fontSize: 40,
          fontWeight: FontWeight.w700,
          fontFamily: ppMori,
        ),
        displayMedium: TextStyle(
          color: AppColor.white,
          fontSize: 28,
          fontWeight: FontWeight.w700,
          fontFamily: ppMori,
        ),
        displaySmall: TextStyle(
          color: AppColor.white,
          fontSize: 22,
          fontWeight: FontWeight.w700,
          fontFamily: ppMori,
        ),
        headlineMedium: TextStyle(
          color: AppColor.white,
          fontSize: 18,
          fontWeight: FontWeight.w700,
          fontFamily: ppMori,
        ),
        headlineSmall: TextStyle(
          color: AppColor.white,
          fontSize: 16,
          fontWeight: FontWeight.w700,
          fontFamily: ppMori,
        ),
        labelLarge: TextStyle(
          color: AppColor.white,
          fontSize: 14,
          fontWeight: FontWeight.w700,
          fontFamily: ppMori,
        ),
        bodySmall: TextStyle(
          color: AppColor.white,
          fontSize: 14,
          fontFamily: ppMori,
        ),
        bodyLarge: TextStyle(
          color: AppColor.white,
          fontSize: 16,
          fontFamily: ppMori,
          fontWeight: FontWeight.w400,
        ),
        bodyMedium: TextStyle(
          color: AppColor.white,
          fontSize: 16,
          fontFamily: ppMori,
        ),
        titleMedium: TextStyle(
          color: AppColor.white,
          fontSize: 16,
          fontFamily: ppMori,
        ),
        titleSmall: TextStyle(
          color: AppColor.white,
          fontSize: 12,
          fontFamily: ppMori,
        ),
      ),
    );
  }

  /// Tablet-specific theme with larger text sizes
  static ThemeData tabletLightTheme() {
    return ThemeData(
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
      primaryIconTheme:
          const IconThemeData(color: AppColor.primaryBlack, size: 24),
      textTheme: const TextTheme(
        displayLarge: TextStyle(
          color: AppColor.primaryBlack,
          fontSize: 48,
          fontWeight: FontWeight.w700,
          fontFamily: ppMori,
        ),
        displayMedium: TextStyle(
          color: AppColor.primaryBlack,
          fontSize: 32,
          fontWeight: FontWeight.w700,
          fontFamily: ppMori,
        ),
        displaySmall: TextStyle(
          color: AppColor.primaryBlack,
          fontSize: 26,
          fontWeight: FontWeight.w700,
          fontFamily: ppMori,
        ),
        headlineMedium: TextStyle(
          color: AppColor.primaryBlack,
          fontSize: 22,
          fontWeight: FontWeight.w700,
          fontFamily: ppMori,
        ),
        headlineSmall: TextStyle(
          color: AppColor.primaryBlack,
          fontSize: 20,
          fontWeight: FontWeight.w700,
          fontFamily: ppMori,
        ),
        labelLarge: TextStyle(
          color: AppColor.primaryBlack,
          fontSize: 18,
          fontWeight: FontWeight.w700,
          fontFamily: ppMori,
        ),
        bodySmall: TextStyle(
          color: AppColor.primaryBlack,
          fontSize: 18,
          fontFamily: ppMori,
        ),
        bodyLarge: TextStyle(
          color: AppColor.primaryBlack,
          fontSize: 20,
          fontFamily: ppMori,
          fontWeight: FontWeight.w400,
        ),
        bodyMedium: TextStyle(
          color: AppColor.primaryBlack,
          fontSize: 20,
          fontFamily: ppMori,
        ),
        titleMedium: TextStyle(
          color: AppColor.primaryBlack,
          fontSize: 20,
          fontFamily: ppMori,
        ),
        titleSmall: TextStyle(
          color: AppColor.primaryBlack,
          fontSize: 16,
          fontFamily: ppMori,
        ),
      ),
      primaryTextTheme: const TextTheme(
        displayLarge: TextStyle(
          color: AppColor.white,
          fontSize: 48,
          fontWeight: FontWeight.w700,
          fontFamily: ppMori,
        ),
        displayMedium: TextStyle(
          color: AppColor.white,
          fontSize: 32,
          fontWeight: FontWeight.w700,
          fontFamily: ppMori,
        ),
        displaySmall: TextStyle(
          color: AppColor.white,
          fontSize: 26,
          fontWeight: FontWeight.w700,
          fontFamily: ppMori,
        ),
        headlineMedium: TextStyle(
          color: AppColor.white,
          fontSize: 22,
          fontWeight: FontWeight.w700,
          fontFamily: ppMori,
        ),
        headlineSmall: TextStyle(
          color: AppColor.white,
          fontSize: 20,
          fontWeight: FontWeight.w700,
          fontFamily: ppMori,
        ),
        labelLarge: TextStyle(
          color: AppColor.white,
          fontSize: 18,
          fontWeight: FontWeight.w700,
          fontFamily: ppMori,
        ),
        bodySmall: TextStyle(
          color: AppColor.white,
          fontSize: 18,
          fontFamily: ppMori,
        ),
        bodyLarge: TextStyle(
          color: AppColor.white,
          fontSize: 20,
          fontFamily: ppMori,
          fontWeight: FontWeight.w400,
        ),
        bodyMedium: TextStyle(
          color: AppColor.white,
          fontSize: 20,
          fontFamily: ppMori,
        ),
        titleMedium: TextStyle(
          color: AppColor.white,
          fontSize: 20,
          fontFamily: ppMori,
        ),
        titleSmall: TextStyle(
          color: AppColor.white,
          fontSize: 16,
          fontFamily: ppMori,
        ),
      ),
    );
  }
}
