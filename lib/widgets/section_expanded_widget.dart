import 'package:app/design/app_typography.dart';
import 'package:app/design/layout_constants.dart';
import 'package:app/theme/app_color.dart';
import 'package:flutter/material.dart';

/// A widget that displays a section with a header and a child.
class SectionExpandedWidget extends StatefulWidget {
  /// Creates a SectionExpandedWidget.
  const SectionExpandedWidget({
    super.key,
    this.header,
    this.headerStyle,
    this.headerPadding,
    this.child,
    this.iconOnExpanded,
    this.iconOnUnExpanded,
    this.withDivider = true,
    this.padding = EdgeInsets.zero,
    this.isExpandedDefault = false,
  });

  /// The header of the section.
  final String? header;

  /// The style of the header.
  final TextStyle? headerStyle;

  /// The padding of the header.
  final EdgeInsets? headerPadding;

  /// The child of the section.
  final Widget? child;

  /// The icon to display when the section is expanded.
  final Widget? iconOnExpanded;

  /// The icon to display when the section is unexpanded.
  final Widget? iconOnUnExpanded;

  /// Whether to display a divider between the header and the child.
  final bool withDivider;

  /// The padding of the section.
  final EdgeInsets padding;

  /// Whether the section is expanded by default.
  final bool isExpandedDefault;

  @override
  State<SectionExpandedWidget> createState() => _SectionExpandedWidgetState();
}

class _SectionExpandedWidgetState extends State<SectionExpandedWidget> {
  late bool _isExpanded;

  @override
  void initState() {
    super.initState();
    _isExpanded = widget.isExpandedDefault;
  }

  @override
  Widget build(BuildContext context) {
    const defaultIcon = Icon(
      Icons.arrow_forward_ios,
      size: 12,
      color: AppColor.white,
    );
    return Padding(
      padding: widget.padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.withDivider)
                const Divider(
                  height: 1,
                  color: AppColor.white,
                  thickness: 1,
                ),
              GestureDetector(
                onTap: () {
                  setState(() {
                    _isExpanded = !_isExpanded;
                  });
                },
                child: ColoredBox(
                  color: Colors.transparent,
                  child: Padding(
                    padding:
                        widget.headerPadding ??
                        EdgeInsets.only(top: LayoutConstants.space4),
                    child: Row(
                      children: [
                        Text(
                          widget.header ?? '',
                          style:
                              widget.headerStyle ??
                              AppTypography.body(context).white,
                        ),
                        const Spacer(),
                        if (_isExpanded)
                          widget.iconOnExpanded ??
                              const RotatedBox(
                                quarterTurns: 1,
                                child: defaultIcon,
                              )
                        else
                          widget.iconOnUnExpanded ??
                              const RotatedBox(
                                quarterTurns: 2,
                                child: defaultIcon,
                              ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          Visibility(
            visible: _isExpanded,
            child: Column(
              children: [
                const SizedBox(height: 23),
                widget.child ?? const SizedBox(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
