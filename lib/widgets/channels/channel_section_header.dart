import 'package:app/design/app_typography.dart';
import 'package:app/design/layout_constants.dart';
import 'package:flutter/material.dart';

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
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
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
              if (sectionIcon != null) ...[
                sectionIcon!,
                SizedBox(
                  width: LayoutConstants.space4,
                ),
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
              child: Container(
                constraints: BoxConstraints(
                  minWidth: LayoutConstants.iconSizeSmall,
                  minHeight: LayoutConstants.iconSizeSmall,
                ),
                color: Colors.transparent,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.arrow_back,
                      size: LayoutConstants.iconSizeSmall,
                      color: const Color(0xFFA0A0A0),
                    ),
                    const SizedBox(
                      width: 8,
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
