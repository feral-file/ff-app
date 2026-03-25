import 'package:app/domain/models/dp1/dp1_playlist_item.dart';
import 'package:app/domain/models/indexer/asset_token.dart';
import 'package:app/domain/models/playlist_item.dart';
import 'package:app/infra/database/converters.dart';

/// Builds the list of [PlaylistItem]s to persist from missing DP1 items and
/// indexer tokens. Attempts to enrich items with tokens; items not found in
/// indexer are saved as fallback DP1 items.
///
/// This allows all items to be cached locally, with enriched data (token info)
/// when available from indexer, and fallback DP1 data when not.
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
      // Item has no CID; save as fallback DP1 item
      toSave.add(
        PlaylistItem(
          id: item.id,
          kind: PlaylistItemKind.dp1Item,
          title: item.title,
          duration: item.duration,
          provenance: item.provenance,
          source: item.source,
          ref: item.ref,
          license: item.license,
          repro: item.repro,
          display: item.display,
        ),
      );
      continue;
    }
    // Try to find token from indexer; save as enriched if found, else fallback
    final token = tokensByCid[cid];
    if (token != null) {
      toSave.add(
        DatabaseConverters.dp1PlaylistItemToPlaylistItem(item, token: token),
      );
    } else {
      // No token found; save as fallback DP1 item
      toSave.add(
        PlaylistItem(
          id: item.id,
          kind: PlaylistItemKind.dp1Item,
          title: item.title,
          duration: item.duration,
          provenance: item.provenance,
          source: item.source,
          ref: item.ref,
          license: item.license,
          repro: item.repro,
          display: item.display,
        ),
      );
    }
  }
  return toSave;
}
