import 'package:flutter/widgets.dart';

/// Provides an [Overlay] boundary for widgets rendered in `MaterialApp.builder`.
///
/// Widgets rendered as siblings of the router child in the app builder do not
/// inherit the navigator overlay. Wrapping them with this scope allows widgets
/// that depend on [Overlay], such as [OverlayPortal], to build safely.
class BuilderOverlayScope extends StatelessWidget {
  /// Creates a [BuilderOverlayScope].
  const BuilderOverlayScope({
    required this.child,
    super.key,
  });

  /// The subtree that needs an overlay boundary.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Overlay(
      initialEntries: [
        OverlayEntry(
          builder: (context) => child,
        ),
      ],
    );
  }
}
