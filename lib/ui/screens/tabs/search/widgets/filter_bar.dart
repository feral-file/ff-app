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
    final typeOptions = availableTypes.toList(growable: false);
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
                  child: _TypeFilterPill(
                    type: type,
                    isSelected: type == currentType,
                    height: pillHeight,
                    padding: pillPadding,
                    textStyle: textStyle,
                    onSelected: onFilterTypeChanged,
                  ),
                ),
              )
            else
              _StaticFilterLabel(
                label: currentType.label,
                height: pillHeight,
                padding: pillPadding,
                textStyle: textStyle,
              ),
            SizedBox(width: LayoutConstants.space1),
            if (sortOptions.length > 1)
              _FacetMenuButton<SearchSortOrder>(
                selected: sortOrder,
                options: sortOptions,
                optionLabel: (option) => option.label,
                onChanged: onSortOrderChanged,
                width: sortControlWidth,
                height: pillHeight,
                padding: pillPadding,
                textStyle: textStyle,
                iconSize: iconSize,
              ),
            SizedBox(width: LayoutConstants.space2),
            if (sourceOptions.length > 1)
              _FacetMenuButton<SearchSourceFilter>(
                selected: sourceFilter,
                options: sourceOptions,
                optionLabel: (option) => option.label,
                onChanged: onSourceFilterChanged,
                width: sourceControlWidth,
                height: pillHeight,
                padding: pillPadding,
                textStyle: textStyle,
                iconSize: iconSize,
              )
            else
              _StaticFilterLabel(
                label: sourceFilter.label,
                height: pillHeight,
                padding: pillPadding,
                textStyle: textStyle,
              ),
            SizedBox(width: LayoutConstants.space2),
            if (dateOptions.length > 1)
              _FacetMenuButton<SearchDateFilter>(
                selected: dateFilter,
                options: dateOptions,
                optionLabel: (option) => option.label,
                onChanged: onDateFilterChanged,
                width: dateControlWidth,
                height: pillHeight,
                padding: pillPadding,
                textStyle: textStyle,
                iconSize: iconSize,
              )
            else
              _StaticFilterLabel(
                label: dateFilter.label,
                height: pillHeight,
                padding: pillPadding,
                textStyle: textStyle,
              ),
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

class _TypeFilterPill extends StatelessWidget {
  const _TypeFilterPill({
    required this.type,
    required this.isSelected,
    required this.height,
    required this.padding,
    required this.textStyle,
    required this.onSelected,
  });

  final SearchFilterType type;
  final bool isSelected;
  final double height;
  final EdgeInsets padding;
  final TextStyle textStyle;
  final ValueChanged<SearchFilterType> onSelected;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: () {
        if (!isSelected) {
          onSelected(type);
        }
      },
      style: TextButton.styleFrom(
        padding: padding,
        minimumSize: Size(0, height),
        backgroundColor: isSelected
            ? Colors.white.withValues(alpha: 0.16)
            : Colors.transparent,
      ),
      child: Text(
        type.label,
        style: textStyle,
      ),
    );
  }
}

class _StaticFilterLabel extends StatelessWidget {
  const _StaticFilterLabel({
    required this.label,
    required this.height,
    required this.padding,
    required this.textStyle,
  });

  final String label;
  final double height;
  final EdgeInsets padding;
  final TextStyle textStyle;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: Align(
        alignment: Alignment.center,
        child: Padding(
          padding: padding,
          child: Text(
            label,
            style: textStyle,
          ),
        ),
      ),
    );
  }
}

class _FacetMenuButton<T> extends StatelessWidget {
  const _FacetMenuButton({
    required this.selected,
    required this.options,
    required this.optionLabel,
    required this.onChanged,
    required this.width,
    required this.height,
    required this.padding,
    required this.textStyle,
    required this.iconSize,
  });

  final T selected;
  final List<T> options;
  final String Function(T) optionLabel;
  final ValueChanged<T> onChanged;
  final double width;
  final double height;
  final EdgeInsets padding;
  final TextStyle textStyle;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: () async {
        final optionItems = options
            .map(
              (option) => OptionItem(
                title: optionLabel(option),
                onTap: () async {
                  Navigator.of(context).pop();
                  if (option != selected) {
                    onChanged(option);
                  }
                },
              ),
            )
            .toList();

        await UIHelper.showCenterMenu(context, options: optionItems);
      },
      style: TextButton.styleFrom(
        padding: padding,
        minimumSize: Size(0, height),
      ),
      child: SizedBox(
        width: width,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: Text(
                optionLabel(selected),
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
    );
  }
}
