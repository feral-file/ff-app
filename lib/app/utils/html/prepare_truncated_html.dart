/// Prepares potentially-truncated HTML for safe rendering.
///
/// Some upstream descriptions can be cut mid-tag (for example ending with
/// `</e` or `<em`), which may break HTML rendering widgets. This helper applies
/// a minimal, conservative fix: if the string ends with a dangling '<...'
/// fragment (i.e., the last '<' appears after the last '>'), it drops that
/// fragment and optionally appends an ellipsis.
String prepareTruncatedHtmlForRender(
  String html, {
  bool addEllipsisOnTrim = true,
}) {
  final lastLt = html.lastIndexOf('<');
  if (lastLt < 0) return html;

  final lastGt = html.lastIndexOf('>');
  if (lastLt <= lastGt) return html;

  final trimmed = html.substring(0, lastLt).trimRight();
  if (!addEllipsisOnTrim) return trimmed;
  if (trimmed.isEmpty) return trimmed;

  return '$trimmed…';
}

/// Prepares HTML for rendering while keeping upstream markup intact.
///
/// In addition to [prepareTruncatedHtmlForRender], this helper can convert
/// newline characters into `<br/>` to preserve spacing when upstream content
/// uses plain text line breaks instead of paragraph tags.
///
/// Conversion is intentionally conservative:
/// - If the input already contains `<p` or `<br`, newlines are left as-is.
/// - Windows newlines (`\r\n`) are normalized.
String prepareHtmlForRender(
  String html, {
  bool addEllipsisOnTrim = true,
}) {
  final truncated = prepareTruncatedHtmlForRender(
    html,
    addEllipsisOnTrim: addEllipsisOnTrim,
  );

  return _convertNewlinesToBrIfNeeded(truncated);
}

String _convertNewlinesToBrIfNeeded(String html) {
  if (!html.contains('\n') && !html.contains('\r')) return html;

  final lowered = html.toLowerCase();
  if (lowered.contains('<p') || lowered.contains('<br')) return html;

  final normalized = html.replaceAll('\r\n', '\n');
  return normalized.replaceAll('\n', '<br/>');
}
