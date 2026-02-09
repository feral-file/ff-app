import 'package:app/domain/models/playlist_item.dart';

/// Convenience extensions for DP-1 work items ([PlaylistItem]).
extension PlaylistItemExt on PlaylistItem {
  /// Thumbnail URL or empty string when missing.
  String get thumbnailUrlOrEmpty => thumbnailUrl ?? '';

  /// Artist name or empty string when missing.
  String get artistName => artists?.map((a) => a.name).join(', ') ?? '';

  /// A compact label suitable for UI lists.
  ///
  /// Keep this pure (no Flutter) so it’s safe to use in `domain/`.
  String get compactLabel {
    final artist = artistName;
    if (artist.isEmpty) return title;
    return '$title • $artist';
  }
}
