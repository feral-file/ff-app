import 'package:app/design/app_typography.dart';
import 'package:app/design/content_rhythm.dart';
import 'package:app/design/layout_constants.dart';
import 'package:app/theme/app_color.dart';
import 'package:flutter/material.dart';

/// Delegate for sticky publisher section headers in grouped channel layout.
///
/// Renders a pinned section header with publisher title, matching the existing
/// grouped mode styling while providing sticky behavior for better navigation
/// context during scroll.
///
/// Used with [SliverPersistentHeader] inside [SliverMainAxisGroup] to ensure
/// only one header is visible at a time (the header of the currently visible
/// section). When scrolling to a new section, its header pushes the previous
/// header off-screen, preventing header stacking.
class PublisherSectionHeaderDelegate extends SliverPersistentHeaderDelegate {
  /// Creates a [PublisherSectionHeaderDelegate].
  ///
  /// [title] is the publisher name displayed in the header.
  /// [topPadding] is additional spacing above the header for visual separation
  /// between sections (typically 0 for first section, space4 for subsequent).
  PublisherSectionHeaderDelegate({
    required this.title,
    required this.topPadding,
  });

  /// Publisher title displayed in the header.
  final String title;

  /// Top padding for visual section separation.
  final double topPadding;

  @override
  double get maxExtent => _headerHeight + topPadding;

  @override
  double get minExtent => _headerHeight + topPadding;

  /// Base header height: text line height + bottom padding.
  ///
  /// Approximates h3 text height (~28px) + space3 bottom padding (12px).
  /// This keeps headers compact while ensuring sufficient touch/visual space.
  static const double _headerHeight = 40;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(
      color: AppColor.auGreyBackground,
      padding: EdgeInsets.only(
        left: ContentRhythm.horizontalRail,
        right: ContentRhythm.horizontalRail,
        bottom: LayoutConstants.space3,
        top: topPadding,
      ),
      alignment: Alignment.bottomLeft,
      child: Text(
        title,
        style: AppTypography.h3(context).white,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  @override
  bool shouldRebuild(covariant PublisherSectionHeaderDelegate oldDelegate) {
    // Rebuild if title or top padding changes (e.g., dynamic publisher data).
    return oldDelegate.title != title || oldDelegate.topPadding != topPadding;
  }
}
