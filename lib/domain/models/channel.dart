/// Channel (DP-1 domain object).
/// Represents a feed of content (playlists, works).
/// Note: "My Collection" is modeled as a pinned personal Channel,
/// not a separate domain object.
class Channel {
  /// Creates a Channel.
  const Channel({
    required this.id,
    required this.name,
    this.description,
    this.isPinned = false,
  });

  /// DP-1 channel ID (e.g., ch_*)
  final String id;

  /// Channel name.
  final String name;

  /// Optional channel description.
  final String? description;

  /// Whether this channel is pinned (e.g., My Collection).
  final bool isPinned;

  /// Creates a copy with updated values.
  Channel copyWith({
    String? id,
    String? name,
    String? description,
    bool? isPinned,
  }) {
    return Channel(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      isPinned: isPinned ?? this.isPinned,
    );
  }
}
