import 'package:app/domain/models/dp1/dp1_playlist_item.dart';
import 'package:app/domain/models/indexer/asset_token.dart';
import 'package:app/domain/models/playlist_item.dart';
import 'package:app/infra/database/converters.dart';

/// Builds the list of [PlaylistItem]s to persist from missing DP1 items and
/// indexer tokens. Only items with tokens from indexer are saved; items not
/// found in indexer are not cached, allowing them to be re-queried later.
///
/// This preserves the cache-first contract: only indexer-verified enriched
/// data is cached locally.
List<PlaylistItem> buildEnrichedPlaylistItemsToSave({
  required List<DP1PlaylistItem> missingItems,
  required List<AssetToken> tokens,
}) {
  if (missingItems.isEmpty) return [];
  final tokensByCid = <String, AssetToken>{for (final t in tokens) t.cid: t};
  final toSave = <PlaylistItem>[];
  for (final item in missingItems) {
    final cid = item.cid;
    if (cid == null) {
      // Item has no CID; cannot be enriched from indexer, skip it
      continue;
    }
    // Only save items that have a token from indexer
    final token = tokensByCid[cid];
    if (token != null) {
      toSave.add(
        DatabaseConverters.dp1PlaylistItemToPlaylistItem(item, token: token),
      );
    }
  }
  return toSave;
}
