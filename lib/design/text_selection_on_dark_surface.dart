import 'package:app/theme/app_color.dart';
import 'package:flutter/material.dart';

/// Text selection styling for [SelectionArea] on [AppColor.auGreyBackground].
///
/// The app theme uses [AppColor.auQuickSilver] for
/// [TextSelectionThemeData.selectionColor], which is too close to light body
/// copy on dark surfaces. Selected text then reads as low-contrast
/// gray-on-gray. A semi-transparent light blue keeps both white and light-gray
/// body text readable.
TextSelectionThemeData textSelectionThemeForDarkContentSurface() {
  return TextSelectionThemeData(
    selectionColor: AppColor.feralFileLightBlue.withValues(alpha: 0.45),
    cursorColor: AppColor.feralFileLightBlue,
    selectionHandleColor: AppColor.feralFileLightBlue,
  );
}
