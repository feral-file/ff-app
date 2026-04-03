import 'package:app/app/routing/current_navigation_titles_provider.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Inherited scope that describes the current screen's *user-visible* title.
///
/// Widgets that trigger navigation (playlist rows, channel headers, etc.) can
/// read this title and pass it to the next route so the next screen can label
/// its back control with the previous page title.
final class PreviousPageTitleScope extends ConsumerStatefulWidget {
  /// Creates a [PreviousPageTitleScope].
  const PreviousPageTitleScope({
    required this.title,
    required this.child,
    this.publishToNavigationMirror = true,
    super.key,
  });

  /// User-visible title of the current screen (tab label, channel name, etc.).
  final String title;

  /// Screen subtree that should inherit this title.
  final Widget child;

  /// Whether this scope should publish its title to global navigation mirrors.
  ///
  /// Keep this `false` for offstage tabs that stay mounted while inactive: they
  /// still need local inherited access for descendant taps, but they should not
  /// override the title used by global overlays like Now Displaying.
  final bool publishToNavigationMirror;

  /// Returns the nearest scoped title, or null when none is provided.
  static String? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<_PreviousPageTitleInherited>()
        ?.title;
  }

  @override
  ConsumerState<PreviousPageTitleScope> createState() =>
      _PreviousPageTitleScopeState();
}

class _PreviousPageTitleScopeState
    extends ConsumerState<PreviousPageTitleScope> {
  final Object _mirrorToken = Object();
  late final CurrentVisiblePageTitleNotifier _mirrorNotifier;

  @override
  void initState() {
    super.initState();
    _mirrorNotifier = ref.read(currentVisiblePageTitleProvider.notifier);
    _publishTitle(widget.title);
  }

  @override
  void didUpdateWidget(covariant PreviousPageTitleScope oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.title != widget.title ||
        oldWidget.publishToNavigationMirror !=
            widget.publishToNavigationMirror) {
      _publishTitle(widget.title);
    }
  }

  @override
  void dispose() {
    // Riverpod forbids notifier updates while the element tree is mid-build.
    // [dispose] can run synchronously during a parent rebuild (old child torn
    // down while build still runs), so a synchronous [remove] throws here.
    //
    // Do not gate on [mounted]: after [super.dispose] the widget is unmounted,
    // but the mirror entry must still be cleared. Unlike [_publishTitle], we
    // intentionally omit [mounted] so cleanup always runs.
    final notifier = _mirrorNotifier;
    final token = _mirrorToken;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      notifier.remove(token);
    });
    super.dispose();
  }

  void _publishTitle(String title) {
    final notifier = _mirrorNotifier;
    final token = _mirrorToken;
    // Microtasks ([Future]) can run mid-frame between siblings' builds.
    // Post-frame runs after this frame completes.
    void runIfStillMounted(VoidCallback fn) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        fn();
      });
    }

    if (!widget.publishToNavigationMirror) {
      runIfStillMounted(() => notifier.remove(token));
      return;
    }
    runIfStillMounted(() => notifier.upsert(token: token, title: title));
  }

  @override
  Widget build(BuildContext context) {
    return _PreviousPageTitleInherited(
      title: widget.title,
      child: widget.child,
    );
  }
}

final class _PreviousPageTitleInherited extends InheritedWidget {
  const _PreviousPageTitleInherited({
    required this.title,
    required super.child,
  });

  final String title;

  @override
  bool updateShouldNotify(_PreviousPageTitleInherited oldWidget) =>
      title != oldWidget.title;
}
