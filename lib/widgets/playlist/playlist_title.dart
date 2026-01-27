import 'package:app/design/app_typography.dart';
import 'package:app/design/layout_constants.dart';
import 'package:flutter/material.dart';

/// Token values for PlaylistTitle layout
class PlaylistTitleTokens {
  /// Horizontal padding for playlist title.
  static const double paddingHorizontal = 12.0;
  
  /// Vertical padding for playlist title.
  static const double paddingVertical = 16.0;
}

/// Playlist Title - Displays playlist info with primary and secondary text
class PlaylistTitle extends StatelessWidget {
  /// Creates a PlaylistTitle.
  const PlaylistTitle({
    required this.primaryText,
    required this.secondaryText,
    this.total,
    this.onTap,
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
  
  /// Optional custom padding.
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) {
    final effectivePadding = padding ??
        const EdgeInsets.symmetric(
          horizontal: PlaylistTitleTokens.paddingHorizontal,
          vertical: PlaylistTitleTokens.paddingVertical,
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
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
