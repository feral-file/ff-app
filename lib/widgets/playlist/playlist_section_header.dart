import 'package:app/design/app_typography.dart';
import 'package:app/design/layout_constants.dart';
import 'package:app/theme/app_color.dart';
import 'package:flutter/material.dart';

/// Token values for PlaylistSectionHeader layout
class PlaylistSectionHeaderTokens {
  /// Horizontal padding for section header.
  static const double paddingHorizontal = 12.0;
  
  /// Width of the "view all" arrow icon.
  static const double viewAllIconWidth = 9.78;
  
  /// Height of the "view all" arrow icon.
  static const double viewAllIconHeight = 8.0;
  
  /// Gap between arrow icon and "All" text.
  static const double buttonGap = 8.0;
}

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
      padding: const EdgeInsets.symmetric(
        horizontal: PlaylistSectionHeaderTokens.paddingHorizontal,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Left: Section name with icon
          Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (sectionIcon != null) 
                sectionIcon!
              else
                Icon(
                  Icons.playlist_play,
                  size: LayoutConstants.iconSizeDefault,
                  color: AppColor.white,
                ),
              SizedBox(
                width: LayoutConstants.space4,
              ),
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
              child: Container(
                constraints: const BoxConstraints(
                  minWidth: 9.78,
                  minHeight: 8,
                ),
                color: Colors.transparent,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.arrow_back,
                      size: PlaylistSectionHeaderTokens.viewAllIconWidth,
                      color: AppColor.auQuickSilver,
                    ),
                    const SizedBox(
                      width: PlaylistSectionHeaderTokens.buttonGap,
                    ),
                    Padding(
                      padding: const EdgeInsets.only(right: 1),
                      child: Text(
                        'All',
                        style: AppTypography.body(context).grey,
                      ),
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
