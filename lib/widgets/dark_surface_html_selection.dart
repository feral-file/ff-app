import 'package:app/design/text_selection_on_dark_surface.dart';
import 'package:flutter/material.dart';

/// [Theme] with [TextSelectionThemeData] plus [SelectionArea] for HTML on dark
/// content surfaces (grey info panels).
///
/// Keeps selection highlight and body copy readable on dark surfaces.
class DarkSurfaceHtmlSelection extends StatelessWidget {
  /// Creates a wrapper that applies dark-surface text selection styling.
  const DarkSurfaceHtmlSelection({
    required this.child,
    this.focusNode,
    super.key,
  });

  /// Optional focus node for the selection area (e.g. work detail).
  final FocusNode? focusNode;

  /// Typically an HTML widget (e.g. from flutter_widget_from_html).
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(
        textSelectionTheme: textSelectionThemeForDarkContentSurface(),
      ),
      child: SelectionArea(
        focusNode: focusNode,
        child: child,
      ),
    );
  }
}
