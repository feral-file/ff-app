import 'package:app/app/routing/routes.dart';
import 'package:app/app/utils/html/prepare_truncated_html.dart';
import 'package:app/design/app_typography.dart';
import 'package:app/design/build/primitives.dart';
import 'package:app/design/layout_constants.dart';
import 'package:app/domain/extensions/extensions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

/// Channel Header - displays channel title and summary
class ChannelHeader extends StatelessWidget {
  /// Creates a ChannelHeader.
  const ChannelHeader({
    required this.channelId,
    required this.channelTitle,
    this.channelSummary,
    this.clickable = true,
    this.maxLines,
    this.renderSummaryAsHtml = false,
    super.key,
  });

  /// Channel ID for navigation.
  final String channelId;

  /// Channel title to display.
  final String channelTitle;

  /// Optional channel summary/description.
  final String? channelSummary;

  /// Whether the header is clickable for navigation.
  final bool clickable;

  /// Max lines for summary text.
  final int? maxLines;

  /// Whether the summary should be rendered as HTML.
  ///
  /// When enabled, [maxLines] is ignored because HTML rendering does not
  /// reliably support line-based truncation.
  final bool renderSummaryAsHtml;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        if (clickable) {
          context.push('${Routes.channels}/$channelId');
        }
      },
      child: ColoredBox(
        color: Colors.transparent,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: LayoutConstants.pageHorizontalDefault,
                vertical: LayoutConstants.space4,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    channelTitle,
                    style: AppTypography.body(context).white,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (channelSummary != null && channelSummary!.isNotEmpty) ...[
                    SizedBox(height: LayoutConstants.space5),
                    if (renderSummaryAsHtml)
                      SelectionArea(
                        child: HtmlWidget(
                          prepareHtmlForRender(channelSummary!),
                          textStyle: AppTypography.body(context).grey,
                          onTapUrl: (url) async {
                            await launchUrl(
                              Uri.parse(url),
                              mode: LaunchMode.externalApplication,
                            );
                            return true;
                          },
                          customStylesBuilder: (element) {
                            if (element.localName == 'p') {
                              return {
                                'margin': '0 0 12px 0',
                              };
                            }
                            if (element.localName == 'a') {
                              return {
                                'color': PrimitivesTokens.colorsGrey
                                    .toHexString(),
                              };
                            }
                            return null;
                          },
                        ),
                      )
                    else
                      Text(
                        channelSummary!,
                        maxLines: maxLines,
                        overflow: maxLines != null
                            ? TextOverflow.ellipsis
                            : TextOverflow.visible,
                        style: AppTypography.body(context).grey,
                      ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
