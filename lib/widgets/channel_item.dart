import 'package:app/app/routing/routes.dart';
import 'package:app/design/app_typography.dart';
import 'package:app/design/layout_constants.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Channel Header - displays channel title and summary
class ChannelHeader extends StatelessWidget {
  /// Creates a ChannelHeader.
  const ChannelHeader({
    required this.channelId,
    required this.channelTitle,
    this.channelSummary,
    this.clickable = true,
    this.maxLines,
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

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        if (clickable) {
          context.push('${Routes.channels}/${channelId}');
        }
      },
      child: Container(
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
