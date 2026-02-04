import 'package:app/design/app_typography.dart';
import 'package:app/design/layout_constants.dart';
import 'package:app/theme/app_color.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Work detail screen.
/// Shows details for a specific work.
class WorkDetailScreen extends StatelessWidget {
  /// Creates a WorkDetailScreen.
  const WorkDetailScreen({
    required this.workId,
    super.key,
  });

  /// The work ID to display.
  final String workId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColor.auGreyBackground,
      appBar: AppBar(
        backgroundColor: AppColor.auGreyBackground,
        title: Text(
          'Work',
          style: AppTypography.h4(context).white,
        ),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SvgPicture.asset(
              'assets/images/artwork_item.svg',
              width: LayoutConstants.space16,
              height: LayoutConstants.space16,
              colorFilter:
                  const ColorFilter.mode(AppColor.white, BlendMode.srcIn),
            ),
            SizedBox(height: LayoutConstants.space4),
            Text(
              'Work Details',
              style: AppTypography.h3(context).white,
            ),
            SizedBox(height: LayoutConstants.space2),
            Text(
              'ID: $workId',
              style: AppTypography.body(context).grey,
            ),
          ],
        ),
      ),
    );
  }
}
