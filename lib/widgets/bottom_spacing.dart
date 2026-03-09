import 'package:app/app/providers/now_displaying_visibility_provider.dart';
import 'package:app/design/layout_constants.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Bottom spacing widget for consistent spacing at the bottom of scrollable content.
class BottomSpacing extends ConsumerWidget {
  /// Creates a BottomSpacing widget.
  ///
  /// When [checkNowDisplayingVisibility] is true (default), reserved height for
  /// the now displaying bar is added only when it should be shown.
  /// When false, [LayoutConstants.nowDisplayingBarReservedHeight] is always
  /// added regardless of visibility.
  const BottomSpacing({
    super.key,
    this.checkNowDisplayingVisibility = true,
  });

  /// When true, adds reserved height for the now displaying bar only when
  /// [nowDisplayingVisibilityProvider] indicates it should show.
  /// When false, always adds [LayoutConstants.nowDisplayingBarReservedHeight].
  final bool checkNowDisplayingVisibility;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final baseHeight = bottomPadding + LayoutConstants.space20;

    if (!checkNowDisplayingVisibility) {
      return SizedBox(
        height: baseHeight + LayoutConstants.nowDisplayingBarReservedHeight,
      );
    }

    final shouldShow = ref.watch(
      nowDisplayingVisibilityProvider.select((s) => s.shouldShow),
    );

    if (!shouldShow) {
      return SizedBox(height: baseHeight);
    }

    return SizedBox(
      height: baseHeight + LayoutConstants.nowDisplayingBarReservedHeight,
    );
  }
}
