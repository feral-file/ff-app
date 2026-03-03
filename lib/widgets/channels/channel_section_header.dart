import 'package:app/design/app_typography.dart';
import 'package:app/design/layout_constants.dart';
import 'package:app/theme/app_color.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Channel Section Header - Displays section name with view all button
class ChannelSectionHeader extends StatelessWidget {
  /// Creates a ChannelSectionHeader.
  const ChannelSectionHeader({
    required this.sectionName,
    this.sectionIcon,
    this.onViewAllTap,
    this.hasMore = true,
    super.key,
  });

  /// Section name to display.
  final String sectionName;

  /// Optional icon widget for the section.
  final Widget? sectionIcon;

  /// Callback when "View All" is tapped.
  final VoidCallback? onViewAllTap;

  /// Whether there are more items to view.
  final bool hasMore;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: LayoutConstants.pageHorizontalDefault,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Left: Section name with icon
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (sectionIcon != null) ...[
                sectionIcon!,
                SizedBox(
                  width: LayoutConstants.space4,
                ),
              ] else ...[
                SvgPicture.asset(
                  'assets/images/icon_account.svg',
                  width: LayoutConstants.iconSizeDefault,
                  height: LayoutConstants.iconSizeDefault,
                  colorFilter: const ColorFilter.mode(
                    AppColor.white,
                    BlendMode.srcIn,
                  ),
                ),
                SizedBox(width: LayoutConstants.space4),
              ],
              Text(
                sectionName,
                style: AppTypography.h4(context).white,
              ),
            ],
          ),
          // Right: View all button
          if (hasMore && onViewAllTap != null)
            GestureDetector(
              onTap: onViewAllTap,
              behavior: HitTestBehavior.opaque,
              child: Container(
                color: Colors.transparent,
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
        ],
      ),
    );
  }
}
