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

    const sortOptions = <SearchSortOrder>[SearchSortOrder.relevance];
    final currentSortLabel = sortOrder.label;

    return Padding(
      padding: EdgeInsets.symmetric(
        vertical: LayoutConstants.space3,
      ),
      child: Row(
        children: [
          TextButton(
            onPressed: () async {
              final optionItems = typeOptions
                  .map(
                    (type) => OptionItem(
                      title: type.label,
                      onTap: () async {
                        Navigator.of(context).pop();
                        if (type != selectedFilterType) {
                          onFilterTypeChanged(type);
                        }
                      },
                    ),
                  )
                  .toList();

              await UIHelper.showCenterMenu(context, options: optionItems);
            },
            style: TextButton.styleFrom(
              padding: EdgeInsets.symmetric(
                horizontal: LayoutConstants.space3,
                vertical: LayoutConstants.space2,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  currentType.label,
                  style: AppTypography.body(context).white,
                ),
                SizedBox(width: LayoutConstants.space1),
                Icon(
                  Icons.expand_more,
                  size: LayoutConstants.iconSizeDefault,
                  color: Colors.white,
                ),
              ],
            ),
          ),
          const Spacer(),
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
                padding: EdgeInsets.symmetric(
                  horizontal: LayoutConstants.space3,
                  vertical: LayoutConstants.space2,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    currentSortLabel,
                    style: AppTypography.body(context).white,
                  ),
                  SizedBox(width: LayoutConstants.space1),
                  Icon(
                    Icons.expand_more,
                    size: LayoutConstants.iconSizeDefault,
                    color: Colors.white,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
