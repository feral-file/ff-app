import 'package:app/app/now_displaying/now_displaying_visibility_sync.dart';
import 'package:app/widgets/now_displaying_bar/now_displaying_bar.dart';
import 'package:app/widgets/now_displaying_bar/two_stop_draggable_sheet.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// App-level shell that overlays the Now Displaying bar.
///
/// Keeps the bar global (screen-agnostic) and wires scroll/keyboard signals
/// into the visibility provider via [NowDisplayingVisibilitySync].
class NowDisplayingAppShell extends StatelessWidget {
  const NowDisplayingAppShell({
    required this.child,
    required this.router,
    super.key,
  });

  final Widget child;
  final GoRouter router;

  @override
  Widget build(BuildContext context) {
    return NowDisplayingVisibilitySync(
      router: router,
      child: Stack(
        children: [
          child,
          ValueListenableBuilder<bool>(
            valueListenable: isNowDisplayingBarExpanded,
            builder: (context, expanded, _) {
              if (!expanded) {
                return const SizedBox.shrink();
              }

              return Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTap: () {
                    NowDisplayingSheetController.collapse();
                  },
                  child: const ColoredBox(
                    color: Colors.transparent,
                  ),
                ),
              );
            },
          ),
          const NowDisplayingBarOverlay(),
        ],
      ),
    );
  }
}
