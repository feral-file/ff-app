import 'package:app/design/layout_constants.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:app/app/providers/now_displaying_visibility_provider.dart';

/// Bottom spacing widget for consistent spacing at the bottom of scrollable content.
class BottomSpacing extends ConsumerWidget {
  /// Creates a BottomSpacing widget.
  const BottomSpacing({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final shouldShow = ref.watch(
      nowDisplayingVisibilityProvider.select((s) => s.shouldShow),
    );

    if (!shouldShow) {
      return SizedBox(height: bottomPadding + LayoutConstants.space20);
    }

    return SizedBox(
      height:
          bottomPadding +
          LayoutConstants.space20 +
          LayoutConstants.nowDisplayingBarReservedHeight,
    );
  }
}
