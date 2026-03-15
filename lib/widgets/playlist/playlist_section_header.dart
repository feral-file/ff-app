import 'package:app/design/app_typography.dart';
import 'package:app/design/content_rhythm.dart';
import 'package:app/design/layout_constants.dart';
import 'package:app/theme/app_color.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Playlist Section Header - Displays section name with view all button
class PlaylistSectionHeader extends StatelessWidget {
  /// Creates a PlaylistSectionHeader.
  const PlaylistSectionHeader({
    required this.sectionName,
    this.sectionIcon,
    this.onViewAllTap,
    this.hasMore = true,
    super.key,
  });

  /// Section name to display.
  final String sectionName;

  /// Optional icon widget to show before section name.
  final Widget? sectionIcon;

  /// Callback when "View All" is tapped.
  final VoidCallback? onViewAllTap;

  /// Whether to show the "View All" button.
  final bool hasMore;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: ContentRhythm.horizontalRail,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Left: Section name with icon
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              sectionIcon ??
                  SvgPicture.asset(
                    'assets/images/icon_account.svg',
                    width: LayoutConstants.iconSizeDefault,
                    height: LayoutConstants.iconSizeDefault,
                    colorFilter: const ColorFilter.mode(
                      AppColor.white,
                      BlendMode.srcIn,
                    ),
                  ),
              SizedBox(
                width: ContentRhythm.sectionIconGap,
              ),
              Text(
                sectionName,
                style: ContentRhythm.sectionTitle(context),
              ),
            ],
          ),
          // Right: View all button
          if (hasMore && onViewAllTap != null)
            GestureDetector(
              onTap: onViewAllTap,
              behavior: HitTestBehavior.opaque,
              child: ColoredBox(
                color: Colors.transparent,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minWidth: LayoutConstants.minTouchTarget,
                    minHeight: LayoutConstants.minTouchTarget,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SvgPicture.asset(
                        'assets/images/icon_arrow_left.svg',
                        width: LayoutConstants.iconSizeSmall,
                        height: LayoutConstants.iconSizeSmall,
                        colorFilter: const ColorFilter.mode(
                          AppColor.auQuickSilver,
                          BlendMode.srcIn,
                        ),
                      ),
                      SizedBox(width: LayoutConstants.space2),
                      Text(
                        'All',
                        style: AppTypography.body(context).grey,
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
