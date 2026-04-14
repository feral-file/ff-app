import 'package:app/app/providers/now_displaying_visibility_provider.dart';
import 'package:app/design/layout_constants.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Bottom spacing widget for consistent spacing at the bottom of
/// scrollable content.
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

    if (!checkNowDisplayingVisibility) {
      return SizedBox(
        height: bottomPadding +
            LayoutConstants.space20 +
            LayoutConstants.nowDisplayingBarReservedHeight,
      );
    }

    final shouldShow = ref.watch(
      nowDisplayingVisibilityProvider.select((s) => s.shouldShow),
    );

    // When the bar is visible (not scrolling) use a taller base so
    // content clears the gradient + bar. When hidden (scrolling) use
    // a smaller base so an extra row of thumbnails is reachable.
    if (!shouldShow) {
      return SizedBox(height: bottomPadding);
    }

    return SizedBox(
      height: bottomPadding +
          LayoutConstants.space20 +
          LayoutConstants.nowDisplayingBarReservedHeight,
    );
  }
}
