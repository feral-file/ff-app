import 'package:app/domain/models/dp1/dp1_manifest.dart';
import 'package:app/domain/models/dp1/dp1_playlist_item.dart';
import 'package:app/domain/models/dp1/dp1_provenance.dart';
import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';

/// PlaylistItem (DP-1 domain object).
/// Extends [DP1PlaylistItem] with app-specific fields (kind, enrichment, token data).
/// Represents an item in a playlist (not "Work" or "Item" - use correct terminology).
/// This corresponds to "Items" in the database schema.
/// UI layer can refer to this as "work" when displaying to users.
class PlaylistItem extends DP1PlaylistItem {
  /// Creates a PlaylistItem.
  const PlaylistItem({
    required super.id,
    required this.kind,
    super.title,
    this.artists,
    this.thumbnailUrl,
    super.duration = 0,
    super.provenance,
    super.source,
    super.ref,
    super.license,
    super.repro,
    super.display,
    this.overrideData,
    this.tokenData,
    this.sortKeyUs,
    this.updatedAt,
  });

  /// Create from JSON.
  factory PlaylistItem.fromJson(Map<String, dynamic> json) {
    List<DP1Artist>? artists;
    if (json['artists'] != null && (json['artists'] as List).isNotEmpty) {
      artists = (json['artists'] as List)
          .map((e) => DP1Artist.fromJson(e as Map<String, dynamic>))
          .toList();
    }

    DP1Provenance? provenance;
    if (json['provenance'] is Map<String, dynamic>) {
      try {
        provenance = DP1Provenance.fromJson(
          json['provenance'] as Map<String, dynamic>,
        );
      } catch (_) {
        // Ignore parse errors
      }
    }

    ReproBlock? repro;
    if (json['repro'] is Map<String, dynamic>) {
      try {
        repro = ReproBlock.fromJson(
          json['repro'] as Map<String, dynamic>,
        );
      } catch (_) {
        // Ignore parse errors
      }
    }

    DP1PlaylistDisplay? display;
    if (json['display'] is Map<String, dynamic>) {
      try {
        display = DP1PlaylistDisplay.fromJson(
          Map<String, dynamic>.from(json['display'] as Map),
        );
      } catch (_) {
        // Ignore parse errors
      }
    }

    return PlaylistItem(
      id: json['id'] as String,
      kind: PlaylistItemKind.values[json['kind'] as int],
      title: json['title'] as String?,
      artists: artists,
      thumbnailUrl: json['thumbnailUrl'] as String?,
      duration: json['duration'] as int? ?? 0,
      provenance: provenance,
      source: json['source'] as String?,
      ref: json['ref'] as String?,
      license: json['license'] != null
          ? ArtworkDisplayLicense.fromString(json['license'] as String)
          : null,
      repro: repro,
      overrideData: json['override'] as Map<String, dynamic>?,
      display: display,
      tokenData: json['tokenData'] as Map<String, dynamic>?,
      sortKeyUs: json['sortKeyUs'] as int?,
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : null,
    );
  }

  /// Item kind (DP1 item or indexer token).
  final PlaylistItemKind kind;

  /// Optional list of artists (DP1 manifest).
  final List<DP1Artist>? artists;

  /// Optional thumbnail URL.
  final String? thumbnailUrl;

  /// Override configuration (no DP1 type; stored as JSON).
  final Map<String, dynamic>? overrideData;

  /// Complete token JSON for reconstruction (indexer tokens).
  final Map<String, dynamic>? tokenData;

  /// Sort key in microseconds (e.g. for address playlist by provenance time).
  final int? sortKeyUs;

  /// Last update timestamp.
  final DateTime? updatedAt;

  static const _deepEquality = DeepCollectionEquality();

  static bool _mapEquals(Map<String, dynamic>? a, Map<String, dynamic>? b) {
    if (a == null && b == null) return true;
    if (a == null || b == null) return false;
    return const DeepCollectionEquality().equals(a, b);
  }

  // ignore: annotate_overrides - equality override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PlaylistItem &&
          runtimeType == other.runtimeType &&
          super == other &&
          kind == other.kind &&
          listEquals(artists, other.artists) &&
          thumbnailUrl == other.thumbnailUrl &&
          _mapEquals(overrideData, other.overrideData) &&
          _mapEquals(tokenData, other.tokenData) &&
          sortKeyUs == other.sortKeyUs &&
          updatedAt == other.updatedAt;

  // ignore: annotate_overrides - hashCode override
  int get hashCode => Object.hash(
    super.hashCode,
    kind,
    Object.hashAll(artists ?? []),
    thumbnailUrl,
    overrideData != null ? _deepEquality.hash(overrideData) : null,
    tokenData != null ? _deepEquality.hash(tokenData) : null,
    sortKeyUs,
    updatedAt,
  );

  /// Creates a copy with updated values.
  PlaylistItem copyWith({
    String? id,
    PlaylistItemKind? kind,
    String? title,
    List<DP1Artist>? artists,
    String? thumbnailUrl,
    int? duration,
    DP1Provenance? provenance,
    String? source,
    String? ref,
    ArtworkDisplayLicense? license,
    ReproBlock? repro,
    Map<String, dynamic>? overrideData,
    DP1PlaylistDisplay? display,
    Map<String, dynamic>? tokenData,
    int? sortKeyUs,
    DateTime? updatedAt,
  }) {
    return PlaylistItem(
      id: id ?? this.id,
      kind: kind ?? this.kind,
      title: title ?? this.title,
      artists: artists ?? this.artists,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      duration: duration ?? this.duration,
      provenance: provenance ?? this.provenance,
      source: source ?? this.source,
      ref: ref ?? this.ref,
      license: license ?? this.license,
      repro: repro ?? this.repro,
      overrideData: overrideData ?? this.overrideData,
      display: display ?? this.display,
      tokenData: tokenData ?? this.tokenData,
      sortKeyUs: sortKeyUs ?? this.sortKeyUs,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Convert to JSON.
  @override
  Map<String, dynamic> toJson() {
    final j = super.toJson();
    j['kind'] = kind.index;
    if (artists != null) {
      j['artists'] = artists!.map((e) => e.toJson()).toList();
    }
    j['thumbnailUrl'] = thumbnailUrl;
    j['duration'] = duration;
    j['source'] = source;
    j['ref'] = ref;
    j['license'] = license?.value;
    j['repro'] = repro?.toJson();
    j['override'] = overrideData;
    j['tokenData'] = tokenData;
    j['sortKeyUs'] = sortKeyUs;
    j['updatedAt'] = updatedAt?.toIso8601String();
    return j;
  }
}

/// Playlist item kind enumeration.
enum PlaylistItemKind {
  /// DP1 item.
  dp1Item,

  /// Indexer token.
  indexerToken,
}
