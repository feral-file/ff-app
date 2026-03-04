import 'package:app/design/app_typography.dart';
import 'package:app/design/layout_constants.dart';
import 'package:app/infra/config/app_config.dart';
import 'package:app/ui/markdown_changelog_style.dart';
import 'package:app/theme/app_color.dart';
import 'package:app/widgets/appbars/setup_app_bar.dart';
import 'package:app/widgets/loading_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

/// Document type for Settings agreements (EULA, Privacy Policy).
enum SettingsDocument {
  /// End User License Agreement.
  eula('EULA', 'ff-app-eula'),
  /// Privacy Policy.
  privacy('Privacy Policy', 'ff-app-privacy');

  const SettingsDocument(this.title, this.path);

  final String title;
  final String path;

  /// Full markdown URL from [AppConfig.feralfileDocsUrl]/agreements/{path}.
  Uri get markdownUri {
    final base = AppConfig.feralfileDocsUrl;
    final normalized = base.endsWith('/') ? base : '$base/';
    return Uri.parse('${normalized}agreements/$path/en_US.md');
  }
}

/// Page that fetches and displays EULA or Privacy Policy markdown from GitHub.
class DocumentViewerPage extends StatelessWidget {
  /// Creates a [DocumentViewerPage].
  const DocumentViewerPage({required this.document, super.key});

  /// Which document to display.
  final SettingsDocument document;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColor.auGreyBackground,
      appBar: SetupAppBar(title: document.title),
      body: FutureBuilder<http.Response>(
        future: http.get(document.markdownUri),
        builder: (context, snapshot) {
          if (snapshot.hasData && snapshot.data!.statusCode == 200) {
            return CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Markdown(
                    key: const Key('documentMarkdown'),
                    data: snapshot.data!.body,
                    softLineBreak: true,
                    shrinkWrap: true,
                    selectable: true,
                    physics: const NeverScrollableScrollPhysics(),
                    styleSheet: markdownDocsStyle(context),
                    padding: EdgeInsets.fromLTRB(
                      LayoutConstants.pageHorizontalDefault,
                      LayoutConstants.space8,
                      LayoutConstants.pageHorizontalDefault,
                      LayoutConstants.space8 +
                          MediaQuery.of(context).padding.bottom +
                          56,
                    ),
                    onTapLink: (text, href, title) async {
                      if (href == null) return;
                      final uri = Uri.tryParse(href);
                      if (uri != null && await canLaunchUrl(uri)) {
                        await launchUrl(
                          uri,
                          mode: LaunchMode.externalApplication,
                        );
                      }
                    },
                  ),
                ),
              ],
            );
          }
          if (snapshot.hasError ||
              (snapshot.hasData && snapshot.data!.statusCode != 200)) {
            return Center(
              child: Text(
                'We could not load this document. Check your connection, then try again.',
                style: AppTypography.body(context).copyWith(
                  color: AppColor.disabledColor,
                ),
                textAlign: TextAlign.center,
              ),
            );
          }
          return const LoadingView();
        },
      ),
    );
  }
}
