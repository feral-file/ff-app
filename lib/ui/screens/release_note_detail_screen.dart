import 'package:app/design/layout_constants.dart';
import 'package:app/infra/services/release_notes_service.dart';
import 'package:app/theme/app_color.dart';
import 'package:app/ui/markdown_changelog_style.dart';
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
          styleSheet: markdownChangelogStyle(context),
          padding: EdgeInsets.fromLTRB(
            LayoutConstants.pageHorizontalDefault,
            LayoutConstants.space8,
            LayoutConstants.pageHorizontalDefault,
            LayoutConstants.space8,
          ),
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
