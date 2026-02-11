import 'package:app/domain/models/channel.dart';
import 'package:app/domain/models/playlist.dart';
import 'package:app/domain/models/dp1/dp1_channel.dart';
import 'package:app/domain/models/dp1/dp1_playlist.dart';
import 'package:app/infra/database/converters.dart';

/// Feed server info (url + createdAt).
/// Matches old repo's [FeedServerInfo].
class FeedServerInfo {
  FeedServerInfo({required this.url, required this.createdAt});

  FeedServerInfo.fromUrl(String url) : url = url, createdAt = DateTime.now();

  final String url;
  final DateTime createdAt;
}

/// Remote config channel (endpoint + channelId).
/// Matches old repo's [RemoteConfigChannel].
class RemoteConfigChannel {
  RemoteConfigChannel({
    required this.endpoint,
    required this.channelId,
    this.publisherId,
  });

  final String endpoint;
  final String channelId;
  final int? publisherId;

  String get url => '$endpoint/api/v1/channels/$channelId';
}

/// Kind of playlist reference (channel vs address).
/// Matches old repo's [PlaylistReferenceType].
enum PlaylistReferenceType {
  channel,
  address,
}

/// Reference to a playlist with its feed URL.
/// Matches old repo's [PlaylistReference].
/// [isExternalFeedService] is provided via extension in feed_manager when
/// FeralFileFeedManager is available.
class PlaylistReference {
  PlaylistReference({
    required this.playlist,
    required this.url,
    this.type = PlaylistReferenceType.channel,
  });

  /// Factory from a DP1 playlist and default feed URL (e.g. API response).
  factory PlaylistReference.fromFeralFileDP1Playlist(
    DP1Playlist dp1Playlist,
    String defaultFeedUrl,
  ) => PlaylistReference(
    playlist: DatabaseConverters.dp1PlaylistToDomain(
      dp1Playlist,
      baseUrl: defaultFeedUrl,
    ),
    url: defaultFeedUrl,
    type: PlaylistReferenceType.channel,
  );

  final Playlist playlist;
  final String url;
  final PlaylistReferenceType type;

  String? get fullUrl {
    try {
      final uri = Uri.parse(url);
      final origin = uri.origin;
      if (origin.isEmpty) return null;
      return '$origin/api/v1/playlists/${playlist.id}';
    } catch (_) {
      return null;
    }
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PlaylistReference &&
        playlist.id == other.playlist.id &&
        url == other.url &&
        type == other.type;
  }

  @override
  int get hashCode => Object.hash(playlist.id, url, type);
}

/// Response of playlist references with pagination.
/// Matches old repo's [DP1PlaylistPlaylistReferenceResponse].
class DP1PlaylistPlaylistReferenceResponse {
  DP1PlaylistPlaylistReferenceResponse(
    this.items,
    this.hasMore,
    this.cursor,
  );

  final List<PlaylistReference> items;
  final bool hasMore;
  final String? cursor;
}

/// Reference to a channel with its feed URL.
/// Uses domain [Channel] (no Data or DP1 wire types in UI).
class ChannelReference {
  ChannelReference({required this.channel, required this.url});

  factory ChannelReference.fromJson(Map<String, dynamic> json) {
    final channelJson = json['channel'] as Map<String, dynamic>?;
    final url = json['url'] as String? ?? '';
    if (channelJson == null) {
      return ChannelReference(
        channel: Channel(
          id: '',
          name: '',
          type: ChannelType.dp1,
        ),
        url: url,
      );
    }
    final dp1 = DP1Channel.fromJson(channelJson);
    return ChannelReference(
      channel: dp1.toDomainChannel(baseUrl: url),
      url: url,
    );
  }

  factory ChannelReference.fromFeralFileDP1Channel(
    DP1Channel dp1Channel,
    String defaultFeedUrl,
  ) => ChannelReference(
    channel: dp1Channel.toDomainChannel(baseUrl: defaultFeedUrl),
    url: defaultFeedUrl,
  );

  final Channel channel;
  final String url;

  Map<String, dynamic> toJson() => {
    'channel': _channelToJson(channel),
    'url': url,
  };

  static Map<String, dynamic> _channelToJson(Channel c) => {
    'id': c.id,
    'slug': c.slug ?? '',
    'title': c.name,
    'curator': c.curator,
    'summary': c.description,
    'playlists': <String>[],
    'created': c.createdAt?.toIso8601String() ?? '',
    'coverImage': c.coverImageUrl,
  };

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ChannelReference &&
        channel.id == other.channel.id &&
        url == other.url;
  }

  @override
  int get hashCode => Object.hash(channel.id, url);
}
