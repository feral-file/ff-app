import 'package:app/domain/models/dp1/dp1_playlist_item.dart';
import 'package:app/domain/models/indexer/asset_token.dart';
import 'package:app/domain/models/playlist_item.dart';
import 'package:app/infra/database/converters.dart';

/// Builds the list of [PlaylistItem]s to persist from missing DP1 items and
/// indexer tokens. Only items that have a matching token (by cid) are included,
/// so we do not save bare DP1 items without enrichment.
List<PlaylistItem> buildEnrichedPlaylistItemsToSave({
  required List<DP1PlaylistItem> missingItems,
  required List<AssetToken> tokens,
}) {
  if (missingItems.isEmpty || tokens.isEmpty) return [];
  final tokensByCid = <String, AssetToken>{for (final t in tokens) t.cid: t};
  final toSave = <PlaylistItem>[];
  for (final item in missingItems) {
    final cid = item.cid;
    if (cid == null) continue;
    final token = tokensByCid[cid];
    if (token == null) continue;
    toSave.add(
      DatabaseConverters.dp1PlaylistItemToPlaylistItem(item, token: token),
    );
  }
  return toSave;
}
