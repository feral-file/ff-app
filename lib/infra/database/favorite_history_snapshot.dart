import 'package:app/domain/models/playlist.dart';
import 'package:app/infra/database/app_database.dart';
import 'package:flutter/foundation.dart';

/// Snapshot of a single Favorite playlist for rebuild-metadata restore.
///
/// Contains playlist metadata and item rows. Entries are recreated on restore.
@immutable
class FavoritePlaylistSnapshot {
  /// Creates a [FavoritePlaylistSnapshot].
  const FavoritePlaylistSnapshot({
    required this.playlist,
    required this.items,
  });

  /// Playlist metadata (type = favorite).
  final Playlist playlist;

  /// Full item rows for works in this playlist.
  final List<ItemData> items;
}
