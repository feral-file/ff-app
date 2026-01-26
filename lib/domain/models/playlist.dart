/// Playlist (DP-1 domain object).
/// Both personal and curated playlists are Playlists.
/// Exhibition/Season/Program are playlistRole values (UI chrome),
/// not separate domain objects.
class Playlist {
  /// Creates a Playlist.
  const Playlist({
    required this.id,
    required this.name,
    this.description,
    this.channelId,
    this.playlistRole,
    this.playlistSource = PlaylistSource.personal,
  });

  /// DP-1 playlist ID (e.g., pl_*)
  final String id;

  /// Playlist name.
  final String name;

  /// Optional playlist description.
  final String? description;

  /// Optional channel this playlist belongs to.
  final String? channelId;

  /// Optional role for UI rendering (exhibition, season, program).
  final PlaylistRole? playlistRole;

  /// Source type for distinguishing personal vs curated.
  final PlaylistSource playlistSource;

  /// Creates a copy with updated values.
  Playlist copyWith({
    String? id,
    String? name,
    String? description,
    String? channelId,
    PlaylistRole? playlistRole,
    PlaylistSource? playlistSource,
  }) {
    return Playlist(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      channelId: channelId ?? this.channelId,
      playlistRole: playlistRole ?? this.playlistRole,
      playlistSource: playlistSource ?? this.playlistSource,
    );
  }
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
