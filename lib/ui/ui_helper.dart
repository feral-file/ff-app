import 'dart:async';

import 'package:app/design/app_typography.dart';
import 'package:app/design/build/primitives.dart';
import 'package:app/design/layout_constants.dart';
import 'package:app/domain/models/playlist_item.dart';
import 'package:app/theme/app_color.dart';
import 'package:app/widgets/work_grid_card.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// UI helpers for reusable UI patterns.
///
/// Note: This is UI-layer only. It must not include transport/protocol logic.
class UIHelper {
  UIHelper._();

  static String currentDialogTitle = '';

  /// Builds a DP-1 works grid as a sliver (domain [PlaylistItem] only).
  static SliverGrid worksSliverGrid({
    required List<PlaylistItem> works,
    required void Function(PlaylistItem item) onItemTap,
  }) {
    return SliverGrid.builder(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: LayoutConstants.worksGridChildAspectRatio,
        crossAxisSpacing: LayoutConstants.space4,
        mainAxisSpacing: LayoutConstants.space4,
      ),
      itemCount: works.length,
      itemBuilder: (context, index) => WorkGridCard(
        item: works[index],
        onTap: () => onItemTap(works[index]),
      ),
    );
  }

  /// Shows a confirmation dialog for destructive actions.
  static Future<bool> showDeleteConfirmation({
    required BuildContext context,
    required String title,
    required String message,
    required String confirmText,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppColor.primaryBlack,
          title: Text(
            title,
            style: AppTypography.h4(context).white,
          ),
          content: Text(
            message,
            style: AppTypography.body(context).grey,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(
                'Cancel',
                style: AppTypography.body(context).grey,
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(
                confirmText,
                style: AppTypography.body(context).white,
              ),
            ),
          ],
        );
      },
    );

    return result ?? false;
  }

  /// Shows a center menu (Cupertino style) with options.
  static Future<void> showCenterMenu(
    BuildContext context, {
    required List<OptionItem> options,
    Widget? bottomWidget,
  }) async {
    await showCupertinoModalPopup<void>(
      context: context,
      builder: (context) {
        final screenWidth = MediaQuery.of(context).size.width;
        return Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: screenWidth * 0.62,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(5),
                    color: PrimitivesTokens.colorsDarkGrey,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: ListView.separated(
                      shrinkWrap: true,
                      padding: EdgeInsets.zero,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: options.length,
                      itemBuilder: (BuildContext context, int index) {
                        final option = options[index];
                        if (option.builder != null) {
                          return option.builder!.call(context, option);
                        }
                        return _CenterMenuItem(option: option);
                      },
                      separatorBuilder: (context, index) => const SizedBox(
                        height: 24,
                      ),
                    ),
                  ),
                ),
                if (bottomWidget != null) ...[
                  const SizedBox(height: 10),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(5),
                      color: PrimitivesTokens.colorsDarkGrey,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: bottomWidget,
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _CenterMenuItem extends StatefulWidget {
  const _CenterMenuItem({required this.option});

  final OptionItem option;

  @override
  State<_CenterMenuItem> createState() => _CenterMenuItemState();
}

class _CenterMenuItemState extends State<_CenterMenuItem> {
  bool _isProcessing = false;

  @override
  Widget build(BuildContext context) {
    final option = widget.option;
    final baseTextStyle =
        option.titleStyle ?? AppTypography.body(context).white;
    final processingTextStyle = option.titleStyleOnPrecessing ??
        baseTextStyle.copyWith(color: AppColor.disabledColor);
    final disabledTextStyle = option.titleStyleOnDisable ??
        baseTextStyle.copyWith(color: AppColor.disabledColor);
    final textStyle = !option.isEnable
        ? disabledTextStyle
        : _isProcessing
            ? processingTextStyle
            : baseTextStyle;
    final icon = !option.isEnable
        ? option.iconOnDisable
        : _isProcessing
            ? (option.iconOnProcessing ??
                loadingIndicator(
                  valueColor: AppColor.disabledColor,
                  size: LayoutConstants.iconSizeSmall,
                ))
            : option.icon;

    return GestureDetector(
      onTap: () async {
        if (!option.isEnable || _isProcessing) return;
        setState(() => _isProcessing = true);
        await option.onTap?.call();
        if (!mounted) return;
        setState(() => _isProcessing = false);
      },
      behavior: HitTestBehavior.opaque,
      child: Row(
        children: [
          if (icon != null)
            SizedBox(
              width: LayoutConstants.iconSizeMedium,
              height: LayoutConstants.iconSizeMedium,
              child: IconTheme(
                data: const IconThemeData(color: AppColor.white),
                child: icon,
              ),
            ),
          if (icon != null) const SizedBox(width: 15),
          Text(option.title ?? '', style: textStyle),
        ],
      ),
    );
  }
}

/// Option item for center menu.
class OptionItem {
  OptionItem({
    this.title,
    this.titleStyle,
    this.titleStyleOnPrecessing,
    this.titleStyleOnDisable,
    this.onTap,
    this.isEnable = true,
    this.icon,
    this.iconOnProcessing,
    this.iconOnDisable,
    this.builder,
    this.separator,
  });

  String? title;
  TextStyle? titleStyle;
  TextStyle? titleStyleOnPrecessing;
  TextStyle? titleStyleOnDisable;
  FutureOr<dynamic> Function()? onTap;
  bool isEnable;
  Widget? icon;
  Widget? iconOnProcessing;
  Widget? iconOnDisable;
  Widget Function(BuildContext context, OptionItem item)? builder;
  Widget? separator;

  static OptionItem emptyOptionItem = OptionItem(title: '');
}

Widget loadingIndicator({
  double size = 27,
  Color valueColor = Colors.black,
  Color backgroundColor = Colors.black54,
  double strokeWidth = 2.0,
}) =>
    SizedBox(
      width: size,
      height: size,
      child: CircularProgressIndicator(
        backgroundColor: backgroundColor,
        color: valueColor,
        strokeWidth: strokeWidth,
      ),
    );

Widget redDotIcon() => dotIcon(color: Colors.red);

Widget dotIcon({required Color color, double size = 10}) => Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
    );

Widget iconWithRedDot({
  required Widget icon,
  EdgeInsetsGeometry? padding,
  bool withReddot = true,
}) =>
    withReddot
        ? Stack(
            alignment: Alignment.topRight,
            children: [
              Padding(
                padding: padding ?? const EdgeInsets.only(right: 5),
                child: icon,
              ),
              redDotIcon(),
            ],
          )
        : icon;
