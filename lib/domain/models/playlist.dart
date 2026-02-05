import 'package:app/domain/models/dp1/dp1_playlist.dart';
import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';

/// Playlist (DP-1 domain object).
/// Both personal and curated playlists are Playlists.
/// Exhibition/Season/Program are playlistRole values (UI chrome),
/// not separate domain objects.
@immutable
class Playlist {
  /// Creates a Playlist.
  const Playlist({
    required this.id,
    required this.name,
    required this.type,
    this.description,
    this.channelId,
    this.playlistRole,
    this.playlistSource = PlaylistSource.personal,
    this.baseUrl,
    this.dpVersion,
    this.slug,
    this.createdAt,
    this.updatedAt,
    this.signatures,
    this.defaults,
    this.dynamicQueries,
    this.ownerAddress,
    this.ownerChain,
    this.ownerName,
    this.sortMode = PlaylistSortMode.position,
    this.itemCount = 0,
  });

  /// DP-1 playlist ID (e.g., pl_*)
  final String id;

  /// Playlist name.
  final String name;

  /// Playlist type (DP1 or address-based).
  final PlaylistType type;

  /// Optional playlist description.
  final String? description;

  /// Optional channel this playlist belongs to.
  final String? channelId;

  /// Optional role for UI rendering (exhibition, season, program).
  final PlaylistRole? playlistRole;

  /// Source type for distinguishing personal vs curated.
  final PlaylistSource playlistSource;

  /// Feed server base URL for DP1 playlists.
  final String? baseUrl;

  /// DP1 protocol version.
  final String? dpVersion;

  /// URL-friendly identifier.
  final String? slug;

  /// Creation timestamp.
  final DateTime? createdAt;

  /// Last update timestamp.
  final DateTime? updatedAt;

  /// DP1 signatures as JSON array.
  final List<String>? signatures;

  /// DP1 defaults configuration.
  final Map<String, dynamic>? defaults;

  /// Dynamic query configuration for fetching tokens.
  final List<DynamicQuery>? dynamicQueries;

  /// Owner address for address-based playlists (uppercase).
  final String? ownerAddress;

  /// Blockchain type (e.g., "ETH", "BTC").
  final String? ownerChain;

  /// Owner name
  final String? ownerName;

  /// Sort mode for playlist entries.
  final PlaylistSortMode sortMode;

  /// Number of items in the playlist.
  final int itemCount;

  /// Deep equality for `Map<String, dynamic>?` (defaults).
  static bool _mapEquals(Map<String, dynamic>? a, Map<String, dynamic>? b) {
    if (a == null && b == null) return true;
    if (a == null || b == null) return false;
    return const DeepCollectionEquality().equals(a, b);
  }

  static const _deepEquality = DeepCollectionEquality();

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Playlist &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name &&
          type == other.type &&
          description == other.description &&
          channelId == other.channelId &&
          playlistRole == other.playlistRole &&
          playlistSource == other.playlistSource &&
          baseUrl == other.baseUrl &&
          dpVersion == other.dpVersion &&
          slug == other.slug &&
          createdAt == other.createdAt &&
          updatedAt == other.updatedAt &&
          listEquals(signatures, other.signatures) &&
          _mapEquals(defaults, other.defaults) &&
          listEquals(dynamicQueries, other.dynamicQueries) &&
          ownerAddress == other.ownerAddress &&
          ownerChain == other.ownerChain &&
          sortMode == other.sortMode &&
          itemCount == other.itemCount;

  @override
  int get hashCode => Object.hash(
        id,
        name,
        type,
        description,
        channelId,
        playlistRole,
        playlistSource,
        baseUrl,
        dpVersion,
        slug,
        createdAt,
        updatedAt,
        Object.hashAll(signatures ?? []),
        defaults != null ? _deepEquality.hash(defaults) : null,
        Object.hashAll(dynamicQueries ?? []),
        ownerAddress,
        ownerChain,
        sortMode,
        itemCount,
      );

  /// Creates a copy with updated values.
  Playlist copyWith({
    String? id,
    String? name,
    PlaylistType? type,
    String? description,
    String? channelId,
    PlaylistRole? playlistRole,
    PlaylistSource? playlistSource,
    String? baseUrl,
    String? dpVersion,
    String? slug,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<String>? signatures,
    Map<String, dynamic>? defaults,
    List<DynamicQuery>? dynamicQueries,
    String? ownerAddress,
    String? ownerChain,
    String? ownerName,
    PlaylistSortMode? sortMode,
    int? itemCount,
  }) {
    return Playlist(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      description: description ?? this.description,
      channelId: channelId ?? this.channelId,
      playlistRole: playlistRole ?? this.playlistRole,
      playlistSource: playlistSource ?? this.playlistSource,
      baseUrl: baseUrl ?? this.baseUrl,
      dpVersion: dpVersion ?? this.dpVersion,
      slug: slug ?? this.slug,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      signatures: signatures ?? this.signatures,
      defaults: defaults ?? this.defaults,
      dynamicQueries: dynamicQueries ?? this.dynamicQueries,
      ownerAddress: ownerAddress ?? this.ownerAddress,
      ownerChain: ownerChain ?? this.ownerChain,
      ownerName: ownerName ?? this.ownerName,
      sortMode: sortMode ?? this.sortMode,
      itemCount: itemCount ?? this.itemCount,
    );
  }
}

/// Playlist type enumeration.
enum PlaylistType {
  /// DP1 playlist from feed server.
  dp1,

  /// Address-based playlist (user's collection).
  addressBased,
}

/// Playlist role for UI chrome (not a separate domain object).
enum PlaylistRole {
  /// Exhibition role for UI rendering.
  exhibition,

  /// Season role for UI rendering.
  season,

  /// Program role for UI rendering.
  program,
}

/// Source type to distinguish personal vs curated playlists.
enum PlaylistSource {
  /// Personal playlist.
  personal,

  /// Curated playlist.
  curated,

  /// Followed playlist.
  followed,

  /// Global playlist.
  global,
}

/// Sort mode for playlist entries.
enum PlaylistSortMode {
  /// Position-based sorting (static order).
  position,

  /// Provenance-based sorting (chronological by acquisition).
  provenance,
}
