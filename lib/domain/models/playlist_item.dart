import 'dart:convert';

/// PlaylistItem (DP-1 domain object).
/// Represents an item in a playlist (not "Work" or "Item" - use correct terminology).
/// This corresponds to "Items" in the database schema.
/// UI layer can refer to this as "work" when displaying to users.
class PlaylistItem {
  /// Creates a PlaylistItem.
  const PlaylistItem({
    required this.id,
    required this.kind,
    required this.title,
    this.subtitle,
    this.artistName,
    this.thumbnailUrl,
    this.mediaUrl,
    this.durationSec,
    this.provenance,
    this.sourceUri,
    this.refUri,
    this.license,
    this.reproduction,
    this.override,
    this.display,
    this.tokenData,
    this.updatedAt,
  });

  /// Item ID (CID for tokens, DP1 item ID for DP1 items).
  final String id;

  /// Item kind (DP1 item or indexer token).
  final PlaylistItemKind kind;

  /// Item title.
  final String title;

  /// Optional subtitle (artists string).
  final String? subtitle;

  /// Optional artist name.
  final String? artistName;

  /// Optional thumbnail URL.
  final String? thumbnailUrl;

  /// Optional media URL.
  final String? mediaUrl;

  /// Duration in seconds for media items.
  final int? durationSec;

  /// Provenance data.
  final Map<String, dynamic>? provenance;

  // DP1 fields
  /// Source URI for DP1 items.
  final String? sourceUri;

  /// Reference URI for DP1 items.
  final String? refUri;

  /// License information.
  final String? license;

  /// Reproduction data.
  final Map<String, dynamic>? reproduction;

  /// Override configuration.
  final Map<String, dynamic>? override;

  /// Display configuration.
  final Map<String, dynamic>? display;

  // Token data
  /// Complete token JSON for reconstruction (indexer tokens).
  final Map<String, dynamic>? tokenData;

  /// Last update timestamp.
  final DateTime? updatedAt;

  /// Creates a copy with updated values.
  PlaylistItem copyWith({
    String? id,
    PlaylistItemKind? kind,
    String? title,
    String? subtitle,
    String? artistName,
    String? thumbnailUrl,
    String? mediaUrl,
    int? durationSec,
    Map<String, dynamic>? provenance,
    String? sourceUri,
    String? refUri,
    String? license,
    Map<String, dynamic>? reproduction,
    Map<String, dynamic>? override,
    Map<String, dynamic>? display,
    Map<String, dynamic>? tokenData,
    DateTime? updatedAt,
  }) {
    return PlaylistItem(
      id: id ?? this.id,
      kind: kind ?? this.kind,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      artistName: artistName ?? this.artistName,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      mediaUrl: mediaUrl ?? this.mediaUrl,
      durationSec: durationSec ?? this.durationSec,
      provenance: provenance ?? this.provenance,
      sourceUri: sourceUri ?? this.sourceUri,
      refUri: refUri ?? this.refUri,
      license: license ?? this.license,
      reproduction: reproduction ?? this.reproduction,
      override: override ?? this.override,
      display: display ?? this.display,
      tokenData: tokenData ?? this.tokenData,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Convert to JSON.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'kind': kind.index,
      'title': title,
      'subtitle': subtitle,
      'artistName': artistName,
      'thumbnailUrl': thumbnailUrl,
      'mediaUrl': mediaUrl,
      'durationSec': durationSec,
      'provenance': provenance,
      'sourceUri': sourceUri,
      'refUri': refUri,
      'license': license,
      'reproduction': reproduction,
      'override': override,
      'display': display,
      'tokenData': tokenData,
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  /// Create from JSON.
  factory PlaylistItem.fromJson(Map<String, dynamic> json) {
    return PlaylistItem(
      id: json['id'] as String,
      kind: PlaylistItemKind.values[json['kind'] as int],
      title: json['title'] as String,
      subtitle: json['subtitle'] as String?,
      artistName: json['artistName'] as String?,
      thumbnailUrl: json['thumbnailUrl'] as String?,
      mediaUrl: json['mediaUrl'] as String?,
      durationSec: json['durationSec'] as int?,
      provenance: json['provenance'] as Map<String, dynamic>?,
      sourceUri: json['sourceUri'] as String?,
      refUri: json['refUri'] as String?,
      license: json['license'] as String?,
      reproduction: json['reproduction'] as Map<String, dynamic>?,
      override: json['override'] as Map<String, dynamic>?,
      display: json['display'] as Map<String, dynamic>?,
      tokenData: json['tokenData'] as Map<String, dynamic>?,
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : null,
    );
  }
}

/// Playlist item kind enumeration.
enum PlaylistItemKind {
  /// DP1 item.
  dp1Item,

  /// Indexer token.
  indexerToken,
}
