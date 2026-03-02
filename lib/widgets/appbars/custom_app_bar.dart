import 'package:app/design/layout_constants.dart';
import 'package:app/theme/app_color.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';

/// Custom app bar for device config screens
AppBar getCustomBackAppBar(
  BuildContext context, {
  required Widget title,
  required List<Widget> actions,
  bool canGoBack = true,
}) {
  const switchDeviceIconSize = 40.0;
  final backIconSize =
      LayoutConstants.pageHorizontalDefault * 2 +
      LayoutConstants.iconSizeMedium;
  final leadingWidth = actions.length > 1
      ? backIconSize + switchDeviceIconSize
      : backIconSize;
  return AppBar(
    elevation: 0,
    shadowColor: Colors.transparent,
    leading: canGoBack
        ? Semantics(
            label: 'Back Button',
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    color: Colors.transparent,
                    padding: EdgeInsets.all(
                      LayoutConstants.pageHorizontalDefault,
                    ),
                    child: SvgPicture.asset(
                      'assets/images/icon_back.svg',
                      height: LayoutConstants.iconSizeMedium,
                      width: LayoutConstants.iconSizeMedium,
                    ),
                  ),
                ),
              ],
            ),
          )
        : SizedBox(width: leadingWidth),
    leadingWidth: leadingWidth,
    titleSpacing: 0,
    toolbarHeight: 66,
    backgroundColor: AppColor.auGreyBackground,
    automaticallyImplyLeading: false,
    centerTitle: true,
    title: title,
    actions: actions.isNotEmpty
        ? actions
        : [
            SizedBox(width: leadingWidth),
          ],
    bottom: const PreferredSize(
      preferredSize: Size.fromHeight(0.25),
      child: Divider(
        height: 1,
        thickness: 0.25,
        color: AppColor.auQuickSilver,
      ),
    ),
  );
}
