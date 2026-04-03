/// Payload passed with route `push` so the next screen can label the back
/// control with the title of the screen the user is leaving.
final class PreviousPageTitleExtra {
  /// Creates extra with the prior screen’s visible title.
  const PreviousPageTitleExtra(this.title);

  /// Title shown on the previous screen (tab label, channel name, etc.).
  final String title;
}

const _genericIndexTitle = 'Index';

/// Creates [PreviousPageTitleExtra] from a raw title string.
///
/// Returns null when the title is missing/blank or matches the generic shell
/// title ("Index"), which is not a user-visible surface in this app.
PreviousPageTitleExtra? previousPageTitleExtraFromTitle(String? title) {
  if (title == null) return null;

  final normalizedTitle = title.trim();
  if (normalizedTitle.isEmpty || normalizedTitle == _genericIndexTitle) {
    return null;
  }
  return PreviousPageTitleExtra(normalizedTitle);
}

/// Returns the wrapped title when [extra] is [PreviousPageTitleExtra];
/// otherwise null.
String? previousPageTitleFromExtra(Object? extra) {
  if (extra is! PreviousPageTitleExtra) return null;

  final normalizedTitle = extra.title.trim();
  if (normalizedTitle.isEmpty || normalizedTitle == _genericIndexTitle) {
    // "Index" is the shell page title, not the user-visible sub-surface the
    // user navigated from. Treat it as missing so route-specific fallbacks like
    // "Playlists" or "Channels" can provide the correct back label.
    return null;
  }

  return normalizedTitle;
}
