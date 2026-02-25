import 'package:app/theme/app_color.dart';
import 'package:app/design/layout_constants.dart';
import 'package:app/widgets/loading_view.dart';
import 'package:flutter/material.dart';

/// Load more indicator widget
class LoadMoreIndicator extends StatelessWidget {
  /// Creates a LoadMoreIndicator.
  const LoadMoreIndicator({
    required this.isLoadingMore,
    this.padding,
    this.width,
    this.height,
    this.frameRate,
    this.showText,
    this.text,
    super.key,
  });

  /// Whether currently loading more items.
  final bool isLoadingMore;
  
  /// Optional padding.
  final EdgeInsets? padding;
  
  /// Optional width.
  final int? width;
  
  /// Optional height.
  final int? height;
  
  /// Optional frame rate.
  final int? frameRate;
  
  /// Whether to show loading text.
  final bool? showText;
  
  /// Optional custom loading text.
  final String? text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding ?? EdgeInsets.all(LayoutConstants.space4),
      alignment: Alignment.center,
      child: isLoadingMore
          ? LoadingWidget(
              backgroundColor: AppColor.auGreyBackground,
              width: width,
              height: height,
              frameRate: frameRate,
              showText: showText ?? true,
              text: text,
            )
          : const SizedBox.shrink(),
    );
  }
}
