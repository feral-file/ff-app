import 'package:app/design/app_typography.dart';
import 'package:app/design/layout_constants.dart';
import 'package:app/theme/app_color.dart';
import 'package:flutter/material.dart';

/// Playlist details header.
///
/// Used on playlist detail screens and list rows that need a “detail” header
/// style (title, optional total, optional channel, optional actions).
class PlaylistDetailsHeader extends StatelessWidget {
  /// Creates a [PlaylistDetailsHeader].
  const PlaylistDetailsHeader({
    required this.title,
    this.total,
    this.subtitle,
    this.onTap,
    this.onSubtitleTap,
    this.trailing,
    this.showDivider = true,
    super.key,
  });

  /// Playlist title.
  final String title;

  /// Optional total number of works.
  final int? total;

  /// Optional subtitle (typically channel name).
  final String? subtitle;

  /// Tap handler for the whole header.
  final VoidCallback? onTap;

  /// Tap handler for the subtitle line.
  final VoidCallback? onSubtitleTap;

  /// Optional trailing widget (e.g., menu button).
  final Widget? trailing;

  /// Whether to render a divider line under the header.
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: LayoutConstants.pageHorizontalDefault,
              vertical: LayoutConstants.space4, // 16px (old repo)
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: AppTypography.body(context).white,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (subtitle != null && subtitle!.isNotEmpty) ...[
                        SizedBox(height: LayoutConstants.space1),
                        GestureDetector(
                          onTap: onSubtitleTap,
                          behavior: HitTestBehavior.opaque,
                          child: Text(
                            subtitle!,
                            style: AppTypography.body(context).grey,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                      if (total != null) ...[
                        SizedBox(height: LayoutConstants.space1),
                        Text(
                          '$total works',
                          style: AppTypography.bodySmall(context).grey,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
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
          if (showDivider)
            const Divider(
              height: 1,
              thickness: 1,
              color: AppColor.primaryBlack,
            ),
        ],
      ),
    );
  }
}
