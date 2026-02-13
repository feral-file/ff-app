import 'package:flutter/material.dart';

/// Quick setting view for the now displaying bar (collapsed state).
///
/// Matches old repo NowDisplayingQuickSettingView placeholder.
/// In collapsed bar, isExpandedListenable is false so this is never shown.
/// Placeholder until full implementation.
class NowDisplayingQuickSettingView extends StatelessWidget {
  const NowDisplayingQuickSettingView({super.key});

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}
