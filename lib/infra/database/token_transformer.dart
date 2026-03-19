import 'package:app/domain/extensions/asset_token_ext.dart';
import 'package:app/domain/models/blockchain.dart';
import 'package:app/domain/models/dp1/dp1_manifest.dart';
import 'package:app/domain/models/dp1/dp1_playlist_item.dart';
import 'package:app/domain/models/dp1/dp1_provenance.dart';
import 'package:app/domain/models/indexer/asset_token.dart';
import 'package:app/domain/models/playlist_item.dart';
import 'package:app/domain/utils/address_deduplication.dart';

/// Transforms indexer tokens to PlaylistItem domain models.
class TokenTransformer {
  static const String _fallbackThumbnailUri = 'assets/images/no_thumbnail.svg';

  /// Transform an [AssetToken] (indexer model) into a [PlaylistItem].
  ///
  /// Builds [DP1Provenance] from chain, standard, and contract fields when
  /// address and tokenId are present. Preserves DP-1 compatibility for
  /// source, thumbnail, artists, sort key, and token data.
  static PlaylistItem assetTokenToPlaylistItem({
    required AssetToken token,
    String? ownerAddress,
  }) {
    final title = token.displayTitle ?? 'Untitled';
    final artists = token.enrichmentSource?.artists ?? token.metadata?.artists;
    final dp1Artists = artists
        ?.map((a) => DP1Artist(name: a.name, id: a.did))
        .toList();

    final normalizedOwner = ownerAddress?.toNormalizedAddress();
    final sortKeyUs = computeSortKeyUsForToken(
      token: token,
      ownerAddress: normalizedOwner,
    );

    final provenance = _buildProvenanceFromToken(token);

    final item = PlaylistItem(
      id: token.cid,
      kind: PlaylistItemKind.indexerToken,
      title: title,
      source: token.getPreviewUrl(),
      thumbnailUrl: _resolveThumbnailUrl(token),
      provenance: provenance,
      sortKeyUs: sortKeyUs,
      updatedAt: DateTime.now(),
      artists: dp1Artists,
      duration: 300,
      license: ArtworkDisplayLicense.open,
    );
    return item;
  }

  /// Build [DP1Provenance] from [AssetToken] chain/standard/contract fields.
  ///
  /// Returns null when chain mapping fails or address/tokenId are empty.
  static DP1Provenance? _buildProvenanceFromToken(AssetToken token) {
    final address = token.contractAddress.trim();
    final tokenId = token.tokenNumber.trim();
    if (address.isEmpty || tokenId.isEmpty) {
      return null;
    }

    DP1ProvenanceChain chain;
    try {
      chain = DP1ProvenanceChain.fromBlockchain(
        Blockchain.fromChain(token.chain),
      );
    } on Object {
      chain = DP1ProvenanceChain.other;
    }

    final standardStr = token.standard.trim().toLowerCase().replaceAll('-', '');
    final standard = standardStr.isEmpty
        ? null
        : DP1ProvenanceStandard.fromString(standardStr);

    final contract = DP1Contract(
      chain: chain,
      standard: standard,
      address: address,
      tokenId: tokenId,
    );
    return DP1Provenance(type: DP1ProvenanceType.onChain, contract: contract);
  }

  /// Compute sort key in microseconds for playlist entry ordering.
  ///
  /// Prefer `provenance_events` when available; fall back to
  /// `owner_provenances` (legacy token summary query shape) when
  /// provenance events are not present.
  static int computeSortKeyUsForToken({
    required AssetToken token,
    required String? ownerAddress,
  }) {
    if (ownerAddress == null) {
      return 0;
    }

    final events = token.provenanceEvents?.items ?? const <ProvenanceEvent>[];
    if (events.isEmpty) {
      return computeSortKeyUsFromOwnerProvenances(
        token: token,
        ownerAddress: ownerAddress,
      );
    }

    var latestUs = 0;
    for (final event in events) {
      final toAddress = event.toAddress;
      if (toAddress == null) continue;
      if (toAddress.toNormalizedAddress() != ownerAddress) continue;

      final tsUs = event.timestamp.microsecondsSinceEpoch;
      if (tsUs > latestUs) {
        latestUs = tsUs;
      }
    }

    return latestUs;
  }

  /// Compute sort key from owner_provenances when provenance_events absent.
  ///
  /// Uses the latest timestamp where owner matches [ownerAddress].
  static int computeSortKeyUsFromOwnerProvenances({
    required AssetToken token,
    required String ownerAddress,
  }) {
    final provenances = token.ownerProvenances?.items ?? const [];
    if (provenances.isEmpty) return 0;

    var latestUs = 0;
    for (final p in provenances) {
      if (p.ownerAddress.toNormalizedAddress() != ownerAddress) continue;
      final tsUs = p.lastTimestamp.microsecondsSinceEpoch;
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
    final normalizedOwner = ownerAddress.toNormalizedAddress();

    return tokens.where((token) {
      final owners = token.owners?.items ?? const <Owner>[];
      if (owners.isNotEmpty) {
        return owners.any(
          (o) => o.ownerAddress.toNormalizedAddress() == normalizedOwner,
        );
      }

      final ownerProvenances = token.ownerProvenances?.items ?? const [];
      if (ownerProvenances.isNotEmpty) {
        return ownerProvenances.any(
          (p) => p.ownerAddress.toNormalizedAddress() == normalizedOwner,
        );
      }

      return token.currentOwner?.toNormalizedAddress() == normalizedOwner;
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
    return '${tokenId}_${ownerAddress.toNormalizedAddress()}';
  }

  /// Reconstruct PlaylistItem from token data JSON.
  /// Used when reading from database.
  static PlaylistItem? reconstructPlaylistItemFromTokenData(
    Map<String, dynamic> tokenData, {
    String? ownerAddress,
  }) {
    try {
      final token = AssetToken.fromJson(tokenData);
      return assetTokenToPlaylistItem(token: token, ownerAddress: ownerAddress);
    } on Object {
      // If reconstruction fails, return null
      return null;
    }
  }

  static String? _resolveThumbnailUrl(AssetToken token) {
    final gallery = token.getGalleryThumbnailUrl();
    if (gallery != null && gallery.isNotEmpty) {
      return gallery;
    }

    final preview = token.getPreviewUrl();
    if (preview != null && preview.isNotEmpty) {
      return preview;
    }

    final mediaAssets = <MediaAsset>[
      ...?token.enrichmentSourceMediaAssets,
      ...?token.metadataMediaAssets,
    ];
    for (final mediaAsset in mediaAssets) {
      final firstVariant = mediaAsset.variantUrls.values
          .map((value) => value.toString())
          .firstWhere(
            (value) => value.isNotEmpty,
            orElse: () => '',
          );
      if (firstVariant.isNotEmpty) {
        return firstVariant;
      }
      if (mediaAsset.sourceUrl.isNotEmpty) {
        return mediaAsset.sourceUrl;
      }
    }

    return _fallbackThumbnailUri;
  }
}
