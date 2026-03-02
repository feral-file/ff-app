import 'package:app/design/app_typography.dart';
import 'package:app/design/layout_constants.dart';
import 'package:flutter/material.dart';

/// Section details header for "All" screens.
///
/// Displays an icon, a title, and a short description.
class SectionDetailsHeader extends StatelessWidget {
  /// Creates a [SectionDetailsHeader].
  const SectionDetailsHeader({
    required this.icon,
    required this.title,
    required this.description,
    this.onTap,
    super.key,
  });

  /// Leading icon.
  final Widget icon;

  /// Header title.
  final String title;

  /// Short description.
  final String description;

  /// Optional tap handler.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: LayoutConstants.pageHorizontalDefault,
          vertical: LayoutConstants.space4,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: LayoutConstants.iconSizeDefault,
                  height: LayoutConstants.iconSizeDefault,
                  child: icon,
                ),
                SizedBox(width: LayoutConstants.space3),
                Expanded(
                  child: Text(
                    title,
                    style: AppTypography.h4(context).white,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            SizedBox(height: LayoutConstants.space5),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    description,
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.body(context).grey,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
