import 'package:app/design/app_typography.dart';
import 'package:app/design/layout_constants.dart';
import 'package:app/theme/app_color.dart';
import 'package:flutter/material.dart';

/// Shared rhythm tokens for primary content surfaces.
///
/// This keeps layout and typography choices token-driven and readable on
/// mobile while preserving the compact FF1 visual structure.
class ContentRhythm {
  ContentRhythm._();

  /// Base spacing grid unit.
  static const double baseGrid = 4;

  /// Readability floors for mobile text roles.
  ///
  /// Keep primary copy at 16sp+, supporting copy at 14sp+, and reserve 12sp
  /// for low-priority metadata.
  static const double minPrimaryTextSp = 16;

  /// Minimum supporting text size.
  static const double minSupportingTextSp = 14;

  /// Minimum metadata text size for non-primary labels.
  static const double minMetaTextSp = 12;

  /// Shared horizontal rail for list/tab/detail content.
  static double get horizontalRail => LayoutConstants.space3;

  /// Standard list-row vertical padding.
  static double get rowVerticalPadding => LayoutConstants.space3;

  /// Gap between icon and section text labels.
  static double get sectionIconGap => LayoutConstants.space3;

  /// Gap between top-level tabs.
  static double get tabGap => LayoutConstants.space3;

  /// Gap between title and supporting/description text.
  static double get titleSupportGap => LayoutConstants.space3;

  /// Compact section spacing used around channel/playlist headers.
  static double get sectionSpacing => LayoutConstants.space4;

  /// Tab label style with selected/unselected state.
  static TextStyle tabLabel(
    BuildContext context, {
    required bool selected,
  }) {
    final base = AppTypography.bodySmall(context);
    return selected ? base.white : base.grey;
  }

  /// Section title style.
  static TextStyle sectionTitle(BuildContext context) {
    return AppTypography.bodySmall(context).white;
  }

  /// Primary content title style.
  static TextStyle title(BuildContext context) {
    return AppTypography.body(context).white;
  }

  /// Supporting metadata and descriptive text style.
  static TextStyle supporting(BuildContext context) {
    return AppTypography.bodySmall(context).grey;
  }

  /// Long-form paragraph copy on dark content surfaces.
  static TextStyle longForm(BuildContext context) {
    return AppTypography.body(context).copyWith(color: AppColor.auLightGrey);
  }

  /// Status message style.
  static TextStyle status(BuildContext context) {
    return AppTypography.bodySmall(context).grey;
  }

  /// Compact control label style.
  static TextStyle controlLabel(BuildContext context) {
    return AppTypography.bodySmall(context).grey;
  }
}
