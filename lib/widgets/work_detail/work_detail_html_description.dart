import 'package:app/widgets/dark_surface_html_selection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:html/dom.dart' as dom;

/// Work detail description: HTML with [SelectionArea] and contrast-safe
/// selection on the dark info panel.
class WorkDetailHtmlDescription extends StatelessWidget {
  /// Creates the work detail HTML description block.
  const WorkDetailHtmlDescription({
    required this.descriptionHtml,
    required this.textStyle,
    required this.customStylesBuilder,
    required this.onTapUrl,
    this.focusNode,
    super.key,
  });

  /// Raw HTML string from the indexer token.
  final String descriptionHtml;

  /// Body text style for rendered HTML.
  final TextStyle textStyle;

  /// Per-element CSS overrides (e.g. app auHtmlStyle helper).
  final Map<String, String>? Function(dom.Element element) customStylesBuilder;

  /// Focus for the selection region (work detail uses a dedicated node).
  final FocusNode? focusNode;

  /// Opens tapped links; must return whether the tap was handled.
  final Future<bool> Function(String url) onTapUrl;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Desc',
      child: DarkSurfaceHtmlSelection(
        focusNode: focusNode,
        child: HtmlWidget(
          descriptionHtml,
          customStylesBuilder: customStylesBuilder,
          textStyle: textStyle,
          onTapUrl: onTapUrl,
        ),
      ),
    );
  }
}
