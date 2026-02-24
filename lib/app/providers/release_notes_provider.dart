import 'package:app/infra/services/release_notes_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Provider for loading release notes from pubdoc.
final releaseNotesServiceProvider = Provider<ReleaseNotesService>((ref) {
  return ReleaseNotesService();
});

/// Release notes list source of truth for the UI.
final releaseNotesListProvider = FutureProvider<List<ReleaseNoteEntry>>((
  ref,
) async {
  final service = ref.watch(releaseNotesServiceProvider);
  return service.getReleaseNotes();
});
