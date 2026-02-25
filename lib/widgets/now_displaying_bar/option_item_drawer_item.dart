import 'dart:async';

import 'package:app/design/app_typography.dart';
import 'package:app/design/layout_constants.dart';
import 'package:app/theme/app_color.dart';
import 'package:flutter/material.dart';

/// Option item model for drawer/settings list rows.
/// Copied from old Feral File app (util/ui_helper.dart).
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
  FutureOr<void> Function()? onTap;
  bool isEnable;
  Widget? icon;
  Widget? iconOnProcessing;
  Widget? iconOnDisable;
  Widget Function(BuildContext context, OptionItem item)? builder;
  Widget? separator;

  static OptionItem get emptyOptionItem => OptionItem(title: '');
}

/// Loading indicator for processing state. Inline copy from old repo style.
Widget _loadingIndicator({
  double size = 14,
  Color valueColor = AppColor.disabledColor,
}) =>
    SizedBox(
      width: size,
      height: size,
      child: CircularProgressIndicator(
        strokeWidth: 2.0,
        color: valueColor,
      ),
    );

/// Drawer/settings list row. Copied from old Feral File app (view/artwork_common_widget.dart).
class DrawerItem extends StatefulWidget {
  const DrawerItem({
    required this.item,
    super.key,
    this.color,
    this.padding = const EdgeInsets.symmetric(vertical: 16, horizontal: 13),
  });

  final OptionItem item;
  final Color? color;
  final EdgeInsets padding;

  @override
  State<DrawerItem> createState() => _DrawerItemState();
}

class _DrawerItemState extends State<DrawerItem> {
  bool isProcessing = false;

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final color = widget.color;
    final defaultTextStyle = AppTypography.body(context).black;
    final customTextStyle = defaultTextStyle.copyWith(color: color);
    final defaultProcessingTextStyle =
        defaultTextStyle.copyWith(color: AppColor.disabledColor);
    final defaultDisabledTextStyle =
        defaultTextStyle.copyWith(color: AppColor.disabledColor);
    final icon = !item.isEnable
        ? (item.iconOnDisable ?? item.icon)
        : isProcessing
            ? (item.iconOnProcessing ?? _loadingIndicator(
                valueColor: AppColor.disabledColor,
                size: LayoutConstants.iconSizeSmall,
              ))
            : item.icon;
    final titleStyle = !item.isEnable
        ? (item.titleStyleOnDisable ?? defaultDisabledTextStyle)
        : isProcessing
            ? (item.titleStyleOnPrecessing ?? defaultProcessingTextStyle)
            : (item.titleStyle ?? customTextStyle);

    final child = Container(
      color: Colors.transparent,
      width: MediaQuery.of(context).size.width,
      child: Padding(
        padding: widget.padding,
        child: Row(
          children: [
            if (icon != null) ...[
              SizedBox(
                width: 30,
                child: Center(child: icon),
              ),
              const SizedBox(width: 34),
            ],
            Expanded(
              child: Text(
                item.title ?? '',
                style: titleStyle,
              ),
            ),
          ],
        ),
      ),
    );
    return GestureDetector(
      onTap: () async {
        if (!item.isEnable || isProcessing) return;
        setState(() => isProcessing = true);
        await item.onTap?.call();
        if (mounted) setState(() => isProcessing = false);
      },
      child: child,
    );
  }
}
