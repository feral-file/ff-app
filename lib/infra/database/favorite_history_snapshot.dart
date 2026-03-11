import 'package:flutter/foundation.dart';

/// Snapshot of a Favorite or History playlist entry for rebuild-metadata restore.
@immutable
class FavoriteHistoryEntrySnapshot {
  const FavoriteHistoryEntrySnapshot({
    required this.playlistId,
    required this.itemId,
    required this.sortKeyUs,
  });

  final String playlistId;
  final String itemId;
  final int sortKeyUs;
}
