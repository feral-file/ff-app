import 'package:app/design/app_typography.dart';
import 'package:app/design/layout_constants.dart';
import 'package:app/theme/app_color.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Search bar matching old repo SearchPage UI.
class SearchBar extends StatefulWidget {
  /// Creates a [SearchBar].
  const SearchBar({
    required this.controller,
    required this.onSubmitted,
    super.key,
    this.hintText,
    this.autoFocus = false,
  });

  /// Controller for the underlying input field.
  final TextEditingController controller;

  /// Called when the user submits a search query.
  final void Function(String) onSubmitted;

  /// Placeholder text shown when the input is empty.
  final String? hintText;

  /// Whether the input should request focus after first build.
  final bool autoFocus;

  @override
  State<SearchBar> createState() => _SearchBarState();
}

class _SearchBarState extends State<SearchBar> {
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();

    if (widget.autoFocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _focusNode.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(
          color: AppColor.auGrey,
        ),
        borderRadius: BorderRadius.circular(5),
      ),
      padding: EdgeInsets.all(LayoutConstants.space2),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              focusNode: _focusNode,
              controller: widget.controller,
              style: AppTypography.body(context).white,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: widget.hintText ?? 'Search',
                hintStyle: AppTypography.body(context).copyWith(
                  color: AppColor.auGrey,
                ),
                border: InputBorder.none,
                contentPadding: EdgeInsets.all(LayoutConstants.space2),
                isDense: true,
              ),
              onSubmitted: widget.onSubmitted,
            ),
          ),
          SizedBox(width: LayoutConstants.space5),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              _focusNode.unfocus();
              widget.onSubmitted(widget.controller.text);
            },
            child: SizedBox(
              width: LayoutConstants.minTouchTarget,
              height: LayoutConstants.minTouchTarget,
              child: Center(
                child: SvgPicture.asset(
                  'assets/images/search.svg',
                  width: LayoutConstants.iconSizeMedium,
                  height: LayoutConstants.iconSizeMedium,
                  colorFilter: const ColorFilter.mode(
                    AppColor.white,
                    BlendMode.srcIn,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
