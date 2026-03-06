import 'package:app/design/app_typography.dart';
import 'package:app/design/layout_constants.dart';
import 'package:app/ui/screens/tabs/search/search_filter_models.dart';
import 'package:app/ui/ui_helper.dart';
import 'package:flutter/material.dart';

/// Type selector bar matching old repo SearchPage FilterBar UI.
class FilterBar extends StatelessWidget {
  /// Creates a [FilterBar].
  const FilterBar({
    required this.selectedFilterType,
    required this.onFilterTypeChanged,
    required this.availableTypes,
    required this.sortOrder,
    required this.onSortOrderChanged,
    required this.sourceFilter,
    required this.onSourceFilterChanged,
    required this.dateFilter,
    required this.onDateFilterChanged,
    super.key,
  });

  /// Currently selected type filter shown in the UI.
  final SearchFilterType selectedFilterType;

  /// Called when the user selects a new [SearchFilterType].
  final void Function(SearchFilterType) onFilterTypeChanged;

  /// List of filter types that should be offered to the user.
  ///
  /// This is derived from the current search results and mirrors the old app
  /// UI.
  /// Only non-empty result types are selectable.
  final List<SearchFilterType> availableTypes;

  /// Currently selected sort option shown in the UI.
  final SearchSortOrder sortOrder;

  /// Called when the user selects a new [SearchSortOrder].
  final void Function(SearchSortOrder) onSortOrderChanged;

  /// Currently selected source filter shown in the UI.
  final SearchSourceFilter sourceFilter;

  /// Called when the user selects a new [SearchSourceFilter].
  final void Function(SearchSourceFilter) onSourceFilterChanged;

  /// Currently selected date filter shown in the UI.
  final SearchDateFilter dateFilter;

  /// Called when the user selects a new [SearchDateFilter].
  final void Function(SearchDateFilter) onDateFilterChanged;

  @override
  Widget build(BuildContext context) {
    final typeOptions = availableTypes.toList();
    if (typeOptions.isEmpty) {
      return const SizedBox.shrink();
    }

    final currentType = typeOptions.firstWhere(
      (type) => type == selectedFilterType,
      orElse: () => typeOptions.first,
    );

    const sortOptions = SearchSortOrder.values;
    const sourceOptions = SearchSourceFilter.values;
    const dateOptions = SearchDateFilter.values;
    final textStyle = AppTypography.body(context).white;
    final currentSortLabel = sortOrder.label;
    final currentSourceLabel = sourceFilter.label;
    final currentDateLabel = dateFilter.label;
    final pillHeight = LayoutConstants.buttonHeightDefault;
    final pillPadding = EdgeInsets.symmetric(
      horizontal: LayoutConstants.space3,
      vertical: LayoutConstants.space2,
    );
    final iconSize = LayoutConstants.iconSizeDefault;
    final sortControlWidth = _menuControlWidth(
      context,
      labels: sortOptions.map((option) => option.label).toList(growable: false),
      textStyle: textStyle,
      horizontalPadding: LayoutConstants.space3,
      iconSize: iconSize,
      iconGap: LayoutConstants.space1,
    );
    final sourceControlWidth = _menuControlWidth(
      context,
      labels: sourceOptions
          .map((option) => option.label)
          .toList(growable: false),
      textStyle: textStyle,
      horizontalPadding: LayoutConstants.space3,
      iconSize: iconSize,
      iconGap: LayoutConstants.space1,
    );
    final dateControlWidth = _menuControlWidth(
      context,
      labels: dateOptions.map((option) => option.label).toList(growable: false),
      textStyle: textStyle,
      horizontalPadding: LayoutConstants.space3,
      iconSize: iconSize,
      iconGap: LayoutConstants.space1,
    );

    Widget staticLabel(String label) {
      return SizedBox(
        height: pillHeight,
        child: Align(
          alignment: Alignment.center,
          child: Padding(
            padding: pillPadding,
            child: Text(
              label,
              style: AppTypography.body(context).white,
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: EdgeInsets.symmetric(
        vertical: LayoutConstants.space3,
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (typeOptions.length > 1)
              ...typeOptions.map(
                (type) => Padding(
                  padding: EdgeInsets.only(right: LayoutConstants.space2),
                  child: TextButton(
                    onPressed: () {
                      if (type != selectedFilterType) {
                        onFilterTypeChanged(type);
                      }
                    },
                    style: TextButton.styleFrom(
                      padding: pillPadding,
                      minimumSize: Size(0, pillHeight),
                      backgroundColor: type == currentType
                          ? Colors.white.withValues(alpha: 0.16)
                          : Colors.transparent,
                    ),
                    child: Text(
                      type.label,
                      style: AppTypography.body(context).white,
                    ),
                  ),
                ),
              )
            else
              staticLabel(currentType.label),
            SizedBox(width: LayoutConstants.space1),
            if (sortOptions.length > 1)
              TextButton(
                onPressed: () async {
                  final optionItems = sortOptions
                      .map(
                        (order) => OptionItem(
                          title: order.label,
                          onTap: () async {
                            Navigator.of(context).pop();
                            if (order != sortOrder) {
                              onSortOrderChanged(order);
                            }
                          },
                        ),
                      )
                      .toList();

                  await UIHelper.showCenterMenu(context, options: optionItems);
                },
                style: TextButton.styleFrom(
                  padding: pillPadding,
                  minimumSize: Size(0, pillHeight),
                ),
                child: SizedBox(
                  width: sortControlWidth,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Text(
                          currentSortLabel,
                          style: textStyle,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      SizedBox(width: LayoutConstants.space1),
                      Icon(
                        Icons.expand_more,
                        size: iconSize,
                        color: Colors.white,
                      ),
                    ],
                  ),
                ),
              ),
            SizedBox(width: LayoutConstants.space2),
            if (sourceOptions.length > 1)
              TextButton(
                onPressed: () async {
                  final optionItems = sourceOptions
                      .map(
                        (source) => OptionItem(
                          title: source.label,
                          onTap: () async {
                            Navigator.of(context).pop();
                            if (source != sourceFilter) {
                              onSourceFilterChanged(source);
                            }
                          },
                        ),
                      )
                      .toList();

                  await UIHelper.showCenterMenu(context, options: optionItems);
                },
                style: TextButton.styleFrom(
                  padding: pillPadding,
                  minimumSize: Size(0, pillHeight),
                ),
                child: SizedBox(
                  width: sourceControlWidth,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Text(
                          currentSourceLabel,
                          style: textStyle,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      SizedBox(width: LayoutConstants.space1),
                      Icon(
                        Icons.expand_more,
                        size: iconSize,
                        color: Colors.white,
                      ),
                    ],
                  ),
                ),
              )
            else
              staticLabel(currentSourceLabel),
            SizedBox(width: LayoutConstants.space2),
            if (dateOptions.length > 1)
              TextButton(
                onPressed: () async {
                  final optionItems = dateOptions
                      .map(
                        (date) => OptionItem(
                          title: date.label,
                          onTap: () async {
                            Navigator.of(context).pop();
                            if (date != dateFilter) {
                              onDateFilterChanged(date);
                            }
                          },
                        ),
                      )
                      .toList();

                  await UIHelper.showCenterMenu(context, options: optionItems);
                },
                style: TextButton.styleFrom(
                  padding: pillPadding,
                  minimumSize: Size(0, pillHeight),
                ),
                child: SizedBox(
                  width: dateControlWidth,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Text(
                          currentDateLabel,
                          style: textStyle,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      SizedBox(width: LayoutConstants.space1),
                      Icon(
                        Icons.expand_more,
                        size: iconSize,
                        color: Colors.white,
                      ),
                    ],
                  ),
                ),
              )
            else
              staticLabel(currentDateLabel),
          ],
        ),
      ),
    );
  }

  double _menuControlWidth(
    BuildContext context, {
    required List<String> labels,
    required TextStyle textStyle,
    required double horizontalPadding,
    required double iconSize,
    required double iconGap,
  }) {
    final maxLabelWidth = labels
        .map(
          (label) => _measureTextWidth(
            context,
            text: label,
            style: textStyle,
          ),
        )
        .fold<double>(0, (max, value) => value > max ? value : max);

    return maxLabelWidth + iconSize + iconGap + (horizontalPadding * 2);
  }

  double _measureTextWidth(
    BuildContext context, {
    required String text,
    required TextStyle style,
  }) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      maxLines: 1,
      textDirection: Directionality.of(context),
    )..layout();
    return painter.width;
  }
}
