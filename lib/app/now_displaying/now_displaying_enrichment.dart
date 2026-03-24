import 'package:app/domain/models/dp1/dp1_playlist_item.dart';
import 'package:app/domain/models/indexer/asset_token.dart';
import 'package:app/domain/models/playlist_item.dart';
import 'package:app/infra/database/converters.dart';

/// Builds the list of [PlaylistItem]s to persist from missing DP1 items and
/// indexer tokens. Items are always saved, enriched with tokens when available
/// or created from DP1 fallback data when token is missing.
///
/// This ensures all items in now displaying bar are cached locally, allowing
/// seamless navigation even if indexer is temporarily unavailable.
List<PlaylistItem> buildEnrichedPlaylistItemsToSave({
  required List<DP1PlaylistItem> missingItems,
  required List<AssetToken> tokens,
}) {
  if (missingItems.isEmpty) return [];
  final tokensByCid = <String, AssetToken>{for (final t in tokens) t.cid: t};
  final toSave = <PlaylistItem>[];
  for (final item in missingItems) {
    final cid = item.cid;
    // Try to get enriched data from token if available
    final token = cid != null ? tokensByCid[cid] : null;
    
    if (token != null) {
      // Save with enriched token data
      toSave.add(
        DatabaseConverters.dp1PlaylistItemToPlaylistItem(item, token: token),
      );
    } else {
      // Fall back to DP1 data without token enrichment
      toSave.add(
        DatabaseConverters.dp1PlaylistItemToPlaylistItem(item),
      );
    }
  }
  return toSave;
}
