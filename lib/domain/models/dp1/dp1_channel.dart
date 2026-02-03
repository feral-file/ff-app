import 'package:app/domain/models/channel.dart';

// ignore_for_file: public_member_api_docs, always_put_required_named_parameters_first, eol_at_end_of_file // Reason: copied from the legacy mobile app; keep DP-1 channel wire model stable.

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
      playlists:
          (json['playlists'] as List<dynamic>).map((e) => e as String).toList(),
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

/// Extension for removing duplicate channels based on unique identifiers
extension DP1ChannelListExtension on List<DP1Channel> {
  /// Remove duplicate channels based on unique identifiers
  List<DP1Channel> removeDuplicates() {
    final seenIds = <String>{};
    final uniqueChannels = <DP1Channel>[];

    for (final channel in this) {
      // DP1Channel has id field as String (required)
      final uniqueId = channel.id;

      if (!seenIds.contains(uniqueId)) {
        seenIds.add(uniqueId);
        uniqueChannels.add(channel);
      }
    }

    return uniqueChannels;
  }
}

extension DP1ChannelExt on DP1Channel {
  Channel toDomainChannel({String? baseUrl}) {
    return Channel(
      id: id,
      name: title,
      type: ChannelType.dp1,
      description: summary,
      baseUrl: baseUrl,
      slug: slug,
      curator: curator,
      coverImageUrl: coverImage,
      createdAt: created,
    );
  }
}


