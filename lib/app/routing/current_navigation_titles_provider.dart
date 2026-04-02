import 'package:flutter_riverpod/flutter_riverpod.dart';

final class _NavigationTitleEntry {
  const _NavigationTitleEntry({
    required this.token,
    required this.title,
  });

  final Object token;
  final String title;
}

/// Notifier for the current visible page title.
class CurrentVisiblePageTitleNotifier extends Notifier<String?> {
  final List<_NavigationTitleEntry> _entries = <_NavigationTitleEntry>[];

  @override
  String? build() => null;

  /// Upsert a new title entry.
  void upsert({
    required Object token,
    required String? title,
  }) {
    if (!ref.mounted) return;
    final index = _entries.indexWhere((entry) => identical(entry.token, token));
    if (title != null && title.isNotEmpty) {
      // Keep each scope's original stack position when its title changes.
      // Re-appending a lower route during rebuild turns the mirror into
      // "last writer wins", which lets background routes steal the back label
      // from the top-most visible route.
      final nextEntry = _NavigationTitleEntry(token: token, title: title);
      if (index == -1) {
        _entries.add(nextEntry);
      } else {
        _entries[index] = nextEntry;
      }
    } else if (index != -1) {
      _entries.removeAt(index);
    }
    state = _entries.isEmpty ? null : _entries.last.title;
  }

  /// Removes a title entry.
  void remove(Object token) {
    if (!ref.mounted) return;
    _entries.removeWhere((entry) => identical(entry.token, token));
    state = _entries.isEmpty ? null : _entries.last.title;
  }
}

/// Current user-visible page title for the active screen.
///
/// Global overlays like Now Displaying sit outside the Navigator subtree, so
/// they cannot read `PreviousPageTitleScope` directly. This provider mirrors
/// the nearest active screen title for those flows.
final currentVisiblePageTitleProvider =
    NotifierProvider<CurrentVisiblePageTitleNotifier, String?>(
      CurrentVisiblePageTitleNotifier.new,
    );
