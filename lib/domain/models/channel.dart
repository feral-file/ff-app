/// Channel (DP-1 domain object).
/// Represents a feed of content (playlists, works).
/// Note: "My Collection" is modeled as a pinned personal Channel,
/// not a separate domain object.
class Channel {
  /// Creates a Channel.
  const Channel({
    required this.id,
    required this.name,
    required this.type,
    this.description,
    this.isPinned = false,
    this.baseUrl,
    this.slug,
    this.curator,
    this.coverImageUrl,
    this.createdAt,
    this.updatedAt,
    this.sortOrder,
  });

  /// DP-1 channel ID (e.g., ch_*)
  final String id;

  /// Channel name.
  final String name;

  /// Channel type (DP1 or local virtual).
  final ChannelType type;

  /// Optional channel description.
  final String? description;

  /// Whether this channel is pinned (e.g., My Collection).
  final bool isPinned;

  /// Feed server base URL for DP1 channels.
  final String? baseUrl;

  /// URL-friendly identifier.
  final String? slug;

  /// Curator name.
  final String? curator;

  /// Cover image URL.
  final String? coverImageUrl;

  /// Creation timestamp.
  final DateTime? createdAt;

  /// Last update timestamp.
  final DateTime? updatedAt;

  /// Display order.
  final int? sortOrder;

  /// Creates a copy with updated values.
  Channel copyWith({
    String? id,
    String? name,
    ChannelType? type,
    String? description,
    bool? isPinned,
    String? baseUrl,
    String? slug,
    String? curator,
    String? coverImageUrl,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? sortOrder,
  }) {
    return Channel(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      description: description ?? this.description,
      isPinned: isPinned ?? this.isPinned,
      baseUrl: baseUrl ?? this.baseUrl,
      slug: slug ?? this.slug,
      curator: curator ?? this.curator,
      coverImageUrl: coverImageUrl ?? this.coverImageUrl,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }
}

/// Channel type enumeration.
enum ChannelType {
  /// DP1 channel from feed server.
  dp1,

  /// Local virtual channel (e.g., My Collection).
  localVirtual,
}
