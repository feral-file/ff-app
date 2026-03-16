import 'package:app/design/app_typography.dart';
import 'package:app/design/content_rhythm.dart';
import 'package:app/design/layout_constants.dart';
import 'package:app/theme/app_color.dart';
import 'package:flutter/material.dart';

/// Playlist Title - Displays playlist info with primary and secondary text.
///
/// Mirrors old repo layout: total is grouped into [statusText] (e.g. "Up to date • X works"),
/// not shown as a separate row. When [showDivider] is true, secondary is hidden and a
/// divider is rendered below (detail page style).
class PlaylistTitle extends StatelessWidget {
  /// Creates a PlaylistTitle.
  const PlaylistTitle({
    required this.primaryText,
    required this.secondaryText,
    this.statusText,
    this.onTap,
    this.onRetry,
    this.subtitle,
    this.onSubtitleTap,
    this.trailing,
    this.showDivider = false,
    this.padding,
    super.key,
  });

  /// Primary text (playlist title).
  final String primaryText;

  /// Secondary text (creator, address, etc.). Hidden when [showDivider] is true.
  final String secondaryText;

  /// Optional status text (e.g. "Up to date • X works", "Syncing • X ready • Y found").
  /// Total is included in status, not as a separate row.
  final String? statusText;

  /// Optional tap callback.
  final VoidCallback? onTap;

  /// Optional retry callback shown when [statusText] is present and failed/canceled.
  final VoidCallback? onRetry;

  /// Optional subtitle (e.g. channel name). Shown as a separate tappable line.
  final String? subtitle;

  /// Tap handler for the subtitle line.
  final VoidCallback? onSubtitleTap;

  /// Optional trailing widget (e.g. options menu button).
  final Widget? trailing;

  /// When true, hides secondary text, uses 16px vertical padding, and adds a divider below.
  final bool showDivider;

  /// Optional custom padding.
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) {
    final effectivePadding =
        padding ??
        EdgeInsets.symmetric(
          horizontal: ContentRhythm.horizontalRail,
          vertical: ContentRhythm.rowVerticalPadding,
        );

    final content = GestureDetector(
      onTap: onTap,
      child: Container(
        color: Colors.transparent,
        padding: effectivePadding,
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Title row
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          primaryText,
                          style: ContentRhythm.title(context),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (!showDivider) ...[
                        SizedBox(width: LayoutConstants.space2),
                        Text(
                          secondaryText,
                          style: ContentRhythm.supporting(context),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                  // Subtitle (channel)
                  if (subtitle != null && subtitle!.isNotEmpty) ...[
                    SizedBox(height: LayoutConstants.space1),
                    GestureDetector(
                      onTap: onSubtitleTap,
                      behavior: HitTestBehavior.opaque,
                      child: Text(
                        subtitle!,
                        style: ContentRhythm.supporting(context),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                  // Status (includes total when applicable, e.g. "Up to date • X works")
                  if (statusText != null && statusText!.isNotEmpty) ...[
                    SizedBox(height: LayoutConstants.space1),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            statusText!,
                            style: ContentRhythm.status(context),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (onRetry != null) ...[
                          Text(
                            ' • ',
                            style: ContentRhythm.status(context),
                          ),
                          GestureDetector(
                            onTap: onRetry,
                            behavior: HitTestBehavior.opaque,
                            child: Text(
                              'Tap to retry',
                              style: ContentRhythm.status(
                                context,
                              ).underline,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ],
              ),
            ),
            if (trailing != null) ...[
              SizedBox(width: LayoutConstants.space2),
              SizedBox(
                width: LayoutConstants.minTouchTarget,
                height: LayoutConstants.minTouchTarget,
                child: Center(child: trailing),
              ),
            ],
          ],
        ),
      ),
    );

    if (showDivider) {
      return Column(
        children: [
          content,
          const Divider(
            height: 1,
            thickness: 1,
            color: AppColor.primaryBlack,
          ),
        ],
      );
    }
    return content;
  }
}
