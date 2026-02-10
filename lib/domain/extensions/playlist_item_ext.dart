import 'package:app/domain/models/playlist_item.dart';

/// Convenience extensions for DP-1 work items ([PlaylistItem]).
extension PlaylistItemExt on PlaylistItem {
  /// Thumbnail URL or empty string when missing.
  String get thumbnailUrlOrEmpty => thumbnailUrl ?? '';

  /// Artist name or empty string when missing.
  String get artistName => artists?.map((a) => a.name).join(', ') ?? '';

  /// Preview/source URL for media (DP1 source).
  String? get sourceUrl => source;
}
