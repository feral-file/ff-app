import 'package:meta/meta.dart';

/// Channel (DP-1 domain object).
/// Represents a feed of content (playlists, works).
/// Note: "My Collection" is modeled as a pinned personal Channel,
/// not a separate domain object.
@immutable
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
    this.publisherId,
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

  /// Optional publisher reference.
  final int? publisherId;

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

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Channel &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name &&
          type == other.type &&
          description == other.description &&
          isPinned == other.isPinned &&
          baseUrl == other.baseUrl &&
          slug == other.slug &&
          publisherId == other.publisherId &&
          curator == other.curator &&
          coverImageUrl == other.coverImageUrl &&
          createdAt == other.createdAt &&
          updatedAt == other.updatedAt &&
          sortOrder == other.sortOrder;

  @override
  int get hashCode => Object.hash(
    id,
    name,
    type,
    description,
    isPinned,
    baseUrl,
    slug,
    publisherId,
    curator,
    coverImageUrl,
    createdAt,
    updatedAt,
    sortOrder,
  );

  /// Creates a copy with updated values.
  Channel copyWith({
    String? id,
    String? name,
    ChannelType? type,
    String? description,
    bool? isPinned,
    String? baseUrl,
    String? slug,
    int? publisherId,
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
      publisherId: publisherId ?? this.publisherId,
      curator: curator ?? this.curator,
      coverImageUrl: coverImageUrl ?? this.coverImageUrl,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }

  /// Channel ID for "My Collection" (personal, pinned).
  static const String myCollectionId = 'my_collection';
}

/// Channel type enumeration.
enum ChannelType {
  /// DP1 channel from feed server.
  dp1(0),

  /// Local virtual channel (e.g., My Collection).
  localVirtual(1)
  ;

  final int value;

  const ChannelType(this.value);

  /// Serializes to string for query params / persistence.
  String toQueryParamString() {
    switch (this) {
      case ChannelType.dp1:
        return 'dp1';
      case ChannelType.localVirtual:
        return 'localVirtual';
    }
  }

  /// Parses from string (e.g. query param). Returns null if invalid.
  static ChannelType? fromString(String value) {
    switch (value.trim()) {
      case 'dp1':
        return ChannelType.dp1;
      case 'localVirtual':
        return ChannelType.localVirtual;
      default:
        return null;
    }
  }
}
