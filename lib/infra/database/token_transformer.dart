import 'package:app/domain/extensions/asset_token_ext.dart';
import 'package:app/domain/models/indexer/asset_token.dart';
import 'package:app/domain/models/playlist_item.dart';

/// Transforms indexer tokens to PlaylistItem domain models.
class TokenTransformer {
  /// Transform an [AssetToken] (indexer model) into a [PlaylistItem].
  static PlaylistItem assetTokenToPlaylistItem({
    required AssetToken token,
    String? ownerAddress,
  }) {
    final title = token.displayTitle ?? 'Untitled';
    final subtitle = token.metadata?.artists
        ?.map((a) => a.name)
        .where((n) => n.isNotEmpty)
        .join(', ');

    final normalizedOwner = ownerAddress?.toUpperCase();
    final sortKeyUs = _computeSortKeyUsFromProvenanceEvents(
      token: token,
      ownerAddress: normalizedOwner,
    );

    return PlaylistItem(
      id: token.cid,
      kind: PlaylistItemKind.indexerToken,
      title: title,
      subtitle: (subtitle == null || subtitle.isEmpty) ? null : subtitle,
      thumbnailUrl: token.getGalleryThumbnailUrl(),
      tokenData: token.toRestJson(),
      provenance: {
        'sortKeyUs': sortKeyUs,
      },
      updatedAt: DateTime.now(),
    );
  }

  /// Compute sort key from provenance events.
  /// Returns the timestamp of the latest event where the owner is the recipient.
  static int _computeSortKeyUsFromProvenanceEvents({
    required AssetToken token,
    required String? ownerAddress,
  }) {
    if (ownerAddress == null) {
      return 0;
    }

    final events = token.provenanceEvents?.items ?? const <ProvenanceEvent>[];
    if (events.isEmpty) return 0;

    var latestUs = 0;
    for (final event in events) {
      final toAddress = event.toAddress;
      if (toAddress == null) continue;
      if (toAddress.toUpperCase() != ownerAddress) continue;

      final tsUs = event.timestamp.microsecondsSinceEpoch;
      if (tsUs > latestUs) {
        latestUs = tsUs;
      }
    }

    return latestUs;
  }

  /// Filter tokens by owner address.
  /// Returns only tokens owned by the specified address.
  static List<AssetToken> filterTokensByOwner({
    required List<AssetToken> tokens,
    required String ownerAddress,
  }) {
    final normalizedOwner = ownerAddress.toUpperCase();

    return tokens.where((token) {
      final owners = token.owners?.items ?? const <Owner>[];
      if (owners.isEmpty) {
        return token.currentOwner?.toUpperCase() == normalizedOwner;
      }
      return owners.any((o) => o.ownerAddress.toUpperCase() == normalizedOwner);
    }).toList();
  }

  /// Generate item ID from token and owner address.
  /// This ensures the same token can appear in multiple address playlists.
  static String generateItemId({
    required String tokenId,
    String? ownerAddress,
  }) {
    if (ownerAddress == null) {
      return tokenId;
    }

    // Create a unique ID combining token ID and owner
    // This allows the same token to exist multiple times
    // in different contexts
    return '${tokenId}_${ownerAddress.toUpperCase()}';
  }

  /// Reconstruct PlaylistItem from token data JSON.
  /// Used when reading from database.
  static PlaylistItem? reconstructPlaylistItemFromTokenData(
    Map<String, dynamic> tokenData, {
    String? ownerAddress,
  }) {
    try {
      final token = AssetToken.fromRest(tokenData);
      return assetTokenToPlaylistItem(token: token, ownerAddress: ownerAddress);
    } catch (e) {
      // If reconstruction fails, return null
      return null;
    }
  }
}
