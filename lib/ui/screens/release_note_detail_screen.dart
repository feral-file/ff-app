import 'package:app/design/app_typography.dart';
import 'package:app/design/build/primitives.dart';
import 'package:app/infra/services/release_notes_service.dart';
import 'package:app/theme/app_color.dart';
import 'package:app/widgets/appbars/setup_app_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:url_launcher/url_launcher.dart';

/// Full markdown detail for a single release note.
class ReleaseNoteDetailScreen extends StatelessWidget {
  /// Creates a [ReleaseNoteDetailScreen].
  const ReleaseNoteDetailScreen({
    required this.releaseNote,
    super.key,
  });

  /// Selected release note.
  final ReleaseNoteEntry releaseNote;

  @override
  Widget build(BuildContext context) {
    final markdownStyleSheet = _changeLogMarkdownStyle(context);

    return Scaffold(
      backgroundColor: AppColor.auGreyBackground,
      appBar: SetupAppBar(
        title: releaseNote.date,
      ),
      body: SingleChildScrollView(
        child: Markdown(
          data: releaseNote.content,
          physics: const NeverScrollableScrollPhysics(),
          shrinkWrap: true,
          softLineBreak: true,
          selectable: true,
          styleSheet: markdownStyleSheet,
          padding: const EdgeInsets.symmetric(horizontal: 24),
          onTapLink: (text, href, title) async {
            if (href == null) {
              return;
            }
            final uri = Uri.tryParse(href);
            if (uri != null && await canLaunchUrl(uri)) {
              await launchUrl(uri, mode: LaunchMode.externalApplication);
            }
          },
        ),
      ),
    );
  }
}

MarkdownStyleSheet _changeLogMarkdownStyle(BuildContext context) {
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
