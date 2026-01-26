import 'dart:convert';

import '../../domain/models/playlist_item.dart';

/// Transforms indexer tokens to PlaylistItem domain models.
class TokenTransformer {
  /// Transform a token from indexer API to PlaylistItem domain model.
  /// 
  /// The token JSON should contain:
  /// - id: CID
  /// - title: Display title
  /// - owners: List of owner objects with address/blockchain
  /// - provenance: List of provenance events
  /// - thumbnailUrl: Thumbnail URL
  /// - etc.
  static PlaylistItem tokenToPlaylistItem({
    required Map<String, dynamic> tokenJson,
    String? ownerAddress,
  }) {
    final id = tokenJson['id'] as String;
    final title = tokenJson['title'] as String? ?? 'Untitled';
    
    // Extract artists (subtitle)
    String? subtitle;
    final metadata = tokenJson['metadata'] as Map<String, dynamic>?;
    if (metadata != null) {
      final artists = metadata['artists'] as List?;
      if (artists != null && artists.isNotEmpty) {
        subtitle = artists
            .map((a) => (a as Map<String, dynamic>)['name'])
            .join(', ');
      }
    }

    // Get thumbnail URL
    final thumbnailUrl = tokenJson['thumbnailUrl'] as String?;

    // Extract duration if available
    int? durationSec;
    if (metadata != null && metadata['duration'] != null) {
      durationSec = metadata['duration'] as int?;
    }

    // Compute sort key from provenance
    final sortKeyUs = _computeSortKeyFromProvenance(
      tokenJson,
      ownerAddress?.toUpperCase(),
    );

    // Store full token data for reconstruction
    final tokenData = Map<String, dynamic>.from(tokenJson);

    return PlaylistItem(
      id: id,
      kind: PlaylistItemKind.indexerToken,
      title: title,
      subtitle: subtitle,
      thumbnailUrl: thumbnailUrl,
      durationSec: durationSec,
      tokenData: tokenData,
      provenance: {
        'sortKeyUs': sortKeyUs,
      },
      updatedAt: DateTime.now(),
    );
  }

  /// Compute sort key from provenance events.
  /// Returns the timestamp of the latest event where the owner is the recipient.
  static int _computeSortKeyFromProvenance(
    Map<String, dynamic> tokenJson,
    String? ownerAddress,
  ) {
    if (ownerAddress == null) {
      return 0;
    }

    final provenance = tokenJson['provenance'] as List?;
    if (provenance == null || provenance.isEmpty) {
      return 0;
    }

    int latestTimestamp = 0;

    for (final event in provenance) {
      final eventMap = event as Map<String, dynamic>;
      final toAddress = eventMap['toAddress'] as String?;
      final timestamp = eventMap['timestamp'] as int?;

      if (toAddress != null &&
          toAddress.toUpperCase() == ownerAddress &&
          timestamp != null &&
          timestamp > latestTimestamp) {
        latestTimestamp = timestamp;
      }
    }

    return latestTimestamp;
  }

  /// Filter tokens by owner address.
  /// Returns only tokens owned by the specified address.
  static List<Map<String, dynamic>> filterTokensByOwner({
    required List<Map<String, dynamic>> tokens,
    required String ownerAddress,
  }) {
    final normalizedOwner = ownerAddress.toUpperCase();

    return tokens.where((token) {
      final owners = token['owners'] as List?;
      if (owners == null || owners.isEmpty) {
        // Fallback to currentOwner field
        final currentOwner = token['currentOwner'] as String?;
        return currentOwner?.toUpperCase() == normalizedOwner;
      }

      // Check if owner is in the owners list
      return owners.any((owner) {
        final address = (owner as Map<String, dynamic>)['address'] as String?;
        return address?.toUpperCase() == normalizedOwner;
      });
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
      return tokenToPlaylistItem(
        tokenJson: tokenData,
        ownerAddress: ownerAddress,
      );
    } catch (e) {
      // If reconstruction fails, return null
      return null;
    }
  }
}
