import 'package:app/design/app_typography.dart';
import 'package:app/design/build/primitives.dart';
import 'package:app/theme/app_color.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

/// Markdown style for EULA and Privacy Policy docs.
/// Copied from old Feral File app [markDownLightStyle] (github_doc.dart).
/// Adapted for ff-app dark theme (white text on auGreyBackground).
MarkdownStyleSheet markdownDocsStyle(BuildContext context) {
  final theme = Theme.of(context);
  const textColor = AppColor.white;
  final bodyText2 =
      AppTypography.body(context).black.copyWith(color: textColor);
  return MarkdownStyleSheet(
    a: TextStyle(
      color: Colors.transparent,
      fontWeight: FontWeight.w500,
      shadows: [Shadow(color: textColor, offset: const Offset(0, -1))],
      decoration: TextDecoration.underline,
      decorationStyle: TextDecorationStyle.solid,
      decorationColor: textColor,
      decorationThickness: 1,
    ),
    p: bodyText2,
    pPadding: const EdgeInsets.only(bottom: 15),
    code: bodyText2.copyWith(backgroundColor: Colors.transparent),
    h1: AppTypography.body(context).bold.copyWith(color: textColor),
    h1Padding: const EdgeInsets.only(bottom: 40),
    h2: AppTypography.body(context).bold.copyWith(color: textColor),
    h2Padding: EdgeInsets.zero,
    h3: AppTypography.body(context).bold.copyWith(color: textColor),
    h3Padding: EdgeInsets.zero,
    h4: AppTypography.body(context).bold.copyWith(color: textColor),
    h4Padding: EdgeInsets.zero,
    h5: AppTypography.body(context).bold.copyWith(color: textColor),
    h5Padding: EdgeInsets.zero,
    h6: AppTypography.body(context).bold.copyWith(color: textColor),
    h6Padding: EdgeInsets.zero,
    em: TextStyle(fontStyle: FontStyle.italic, color: textColor),
    strong: TextStyle(fontWeight: FontWeight.bold, color: textColor),
    del: TextStyle(decoration: TextDecoration.lineThrough, color: textColor),
    blockquote: bodyText2,
    img: bodyText2,
    checkbox: bodyText2.copyWith(color: theme.colorScheme.secondary),
    blockSpacing: 15,
    listIndent: 24,
    listBullet: bodyText2,
    listBulletPadding: const EdgeInsets.only(right: 4),
    tableHead: const TextStyle(fontWeight: FontWeight.w600),
    tableBody: bodyText2,
    tableHeadAlign: TextAlign.center,
    tableBorder: TableBorder.all(color: theme.dividerColor),
    tableColumnWidth: const FlexColumnWidth(),
    tableCellsPadding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
    tableCellsDecoration: const BoxDecoration(),
    blockquotePadding: const EdgeInsets.all(8),
    blockquoteDecoration: const BoxDecoration(
      border: Border(
        left: BorderSide(width: 2, color: AppColor.feralFileHighlight),
      ),
    ),
    codeblockPadding: const EdgeInsets.all(8),
    codeblockDecoration: BoxDecoration(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(2),
    ),
    horizontalRuleDecoration: BoxDecoration(
      border: Border(
        top: BorderSide(width: 5, color: theme.dividerColor),
      ),
    ),
  );
}

/// Shared markdown style for changelog (release notes).
/// Used by [ReleaseNoteDetailScreen]. Copied from old app [markDownChangeLogStyle].
MarkdownStyleSheet markdownChangelogStyle(BuildContext context) {
  final theme = Theme.of(context);
  final textStyleBody = AppTypography.body(context).black;
  final textStyleGrey = AppTypography.body(context).grey;

  return MarkdownStyleSheet(
    a: const TextStyle(
      color: Colors.transparent,
      fontWeight: FontWeight.w500,
      shadows: [Shadow(offset: Offset(0, -1))],
      decoration: TextDecoration.underline,
      decorationStyle: TextDecorationStyle.solid,
      decorationColor: PrimitivesTokens.colorsWhite,
      decorationThickness: 1,
    ),
    p: textStyleBody.white,
    pPadding: const EdgeInsets.only(bottom: 16),
    code: textStyleBody.white.copyWith(backgroundColor: Colors.transparent),
    h1: AppTypography.h2(context).white,
    h1Padding: const EdgeInsets.only(bottom: 24),
    h2: AppTypography.h3(context).white,
    h2Padding: const EdgeInsets.symmetric(vertical: 15),
    h3: AppTypography.h3(context).white,
    h3Padding: const EdgeInsets.symmetric(vertical: 15),
    h4: AppTypography.h3(context).white,
    h4Padding: EdgeInsets.zero,
    h5: AppTypography.h3(context).white,
    h5Padding: EdgeInsets.zero,
    h6: AppTypography.h3(context).white,
    h6Padding: EdgeInsets.zero,
    em: textStyleGrey,
    strong: const TextStyle(
      fontWeight: FontWeight.bold,
      color: PrimitivesTokens.colorsWhite,
    ),
    del: const TextStyle(
      decoration: TextDecoration.lineThrough,
      color: PrimitivesTokens.colorsWhite,
    ),
    blockquote: textStyleBody.white,
    img: textStyleBody.white,
    checkbox: textStyleBody.white.copyWith(color: theme.colorScheme.secondary),
    blockSpacing: 15,
    listIndent: 24,
    listBullet: textStyleBody.white,
    listBulletPadding: const EdgeInsets.only(right: 4),
    tableHead: const TextStyle(fontWeight: FontWeight.w600),
    tableBody: textStyleBody,
    tableHeadAlign: TextAlign.center,
    tableBorder: TableBorder.all(color: theme.dividerColor),
    tableColumnWidth: const FlexColumnWidth(),
    tableCellsPadding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
    tableCellsDecoration: const BoxDecoration(),
    blockquotePadding: const EdgeInsets.only(left: 20),
    blockquoteDecoration: const BoxDecoration(
      border: Border(
        left: BorderSide(width: 2, color: AppColor.feralFileHighlight),
      ),
    ),
    codeblockPadding: const EdgeInsets.all(8),
    codeblockDecoration: BoxDecoration(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(2),
    ),
    horizontalRuleDecoration: const BoxDecoration(),
  );
}
