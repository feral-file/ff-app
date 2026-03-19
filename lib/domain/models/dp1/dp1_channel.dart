// ignore_for_file: public_member_api_docs, always_put_required_named_parameters_first // Reason: copied from the legacy mobile app; keep DP-1 channel wire model stable.

class DP1Channel {
  DP1Channel({
    required this.id,
    required this.slug,
    required this.title,
    this.curator,
    this.summary,
    required this.playlists,
    required this.created,
    this.coverImage,
  });

  factory DP1Channel.fromJson(Map<String, dynamic> json) {
    return DP1Channel(
      id: json['id'] as String,
      slug: json['slug'] as String,
      title: json['title'] as String,
      curator: json['curator'] as String?,
      summary: json['summary'] as String?,
      playlists: (json['playlists'] as List<dynamic>)
          .map((e) => e as String)
          .toList(),
      created: DateTime.parse(json['created'] as String),
      coverImage: json['coverImage'] as String?,
    );
  }

  final String id;
  final String slug;
  final String title;
  final String? curator;
  final String? summary;
  final List<String> playlists;
  final DateTime created;
  final String? coverImage;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'slug': slug,
      'title': title,
      'curator': curator,
      'summary': summary,
      'playlists': playlists,
      'created': created.toIso8601String(),
      'coverImage': coverImage,
    };
  }
}
