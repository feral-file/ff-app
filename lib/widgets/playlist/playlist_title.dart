import 'package:app/design/app_typography.dart';
import 'package:app/design/layout_constants.dart';
import 'package:flutter/material.dart';

/// Playlist Title - Displays playlist info with primary and secondary text
class PlaylistTitle extends StatelessWidget {
  /// Creates a PlaylistTitle.
  const PlaylistTitle({
    required this.primaryText,
    required this.secondaryText,
    this.total,
    this.onTap,
    this.statusText,
    this.onRetry,
    this.padding,
    super.key,
  });

  /// Primary text (playlist title).
  final String primaryText;

  /// Secondary text (creator, channel, etc.).
  final String secondaryText;

  /// Optional total number of items.
  final int? total;

  /// Optional tap callback.
  final VoidCallback? onTap;

  /// Optional status text shown under the title (e.g., sync state).
  final String? statusText;

  /// Optional retry callback shown when [statusText] is present.
  final VoidCallback? onRetry;

  /// Optional custom padding.
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) {
    final effectivePadding =
        padding ??
        EdgeInsets.symmetric(
          horizontal: LayoutConstants.pageHorizontalDefault,
          vertical: LayoutConstants.space4,
        );

    return GestureDetector(
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
                          style: AppTypography.body(context).white,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      SizedBox(width: LayoutConstants.space2),
                      Text(
                        secondaryText,
                        style: AppTypography.body(context).italic.grey,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                  // Total count if available
                  if (total != null) ...[
                    SizedBox(height: LayoutConstants.space1),
                    Text(
                      '$total works',
                      style: AppTypography.bodySmall(context).grey.italic,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  if (statusText != null && statusText!.isNotEmpty) ...[
                    SizedBox(height: LayoutConstants.space1),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            statusText!,
                            style: AppTypography.bodySmall(context).grey.italic,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (onRetry != null) ...[
                          Text(
                            ' • ',
                            style: AppTypography.bodySmall(context).grey.italic,
                          ),
                          GestureDetector(
                            onTap: onRetry,
                            behavior: HitTestBehavior.opaque,
                            child: Text(
                              'Tap to retry',
                              style: AppTypography.bodySmall(
                                context,
                              ).grey.italic.underline,
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
          ],
        ),
      ),
    );
  }
}
