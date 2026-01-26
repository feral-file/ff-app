/// Work (DP-1 domain object).
/// Represents an artwork (not "Artwork" - use correct DP-1 terminology).
class Work {
  /// Creates a Work.
  const Work({
    required this.id,
    required this.title,
    this.artistName,
    this.thumbnailUrl,
    this.mediaUrl,
  });

  /// DP-1 work ID (e.g., wk_*)
  final String id;

  /// Work title.
  final String title;

  /// Optional artist name.
  final String? artistName;

  /// Optional thumbnail URL.
  final String? thumbnailUrl;

  /// Optional media URL.
  final String? mediaUrl;

  /// Creates a copy with updated values.
  Work copyWith({
    String? id,
    String? title,
    String? artistName,
    String? thumbnailUrl,
    String? mediaUrl,
  }) {
    return Work(
      id: id ?? this.id,
      title: title ?? this.title,
      artistName: artistName ?? this.artistName,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      mediaUrl: mediaUrl ?? this.mediaUrl,
    );
  }
}
