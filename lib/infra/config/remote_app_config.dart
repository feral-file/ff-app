/// Typed remote app config consumed by the app.
///
/// Expected keys in remote JSON:
/// - `dp1_playlist.channel_urls`
/// - `dp1_playlist.feed_cache_duration`
/// - `dp1_playlist.feed_last_updated`
class RemoteAppConfig {
  const RemoteAppConfig({
    required this.curatedChannelUrls,
    required this.feedCacheDuration,
    required this.feedLastUpdatedAt,
  });

  final List<String> curatedChannelUrls;
  final Duration feedCacheDuration;
  final DateTime feedLastUpdatedAt;

  static const String dp1PlaylistKey = 'dp1_playlist';
  static const String dp1PlaylistChannelUrlsKey = 'channel_urls';
  static const String dp1PlaylistFeedCacheDurationKey = 'feed_cache_duration';
  static const String dp1PlaylistFeedLastUpdatedKey = 'feed_last_updated';

  factory RemoteAppConfig.fromJson(Map<String, dynamic> json) {
    final curated = _readCuratedChannelUrls(json);
    if (curated.isEmpty) {
      throw const FormatException('Missing curated channel URLs.');
    }

    final feedCacheDuration = _readFeedCacheDuration(json);
    if (feedCacheDuration == null) {
      throw const FormatException('Missing dp1 feed cache duration.');
    }

    final feedLastUpdatedAt = _readFeedLastUpdatedAt(json);
    if (feedLastUpdatedAt == null) {
      throw const FormatException('Missing dp1 feed last updated timestamp.');
    }

    return RemoteAppConfig(
      curatedChannelUrls: curated,
      feedCacheDuration: feedCacheDuration,
      feedLastUpdatedAt: feedLastUpdatedAt,
    );
  }

  static List<String> _readCuratedChannelUrls(Map<String, dynamic> json) {
    final dp1Playlist = json[dp1PlaylistKey];
    if (dp1Playlist is Map<String, dynamic>) {
      final nested = dp1Playlist[dp1PlaylistChannelUrlsKey];
      if (nested is List) {
        return nested
            .map((e) => e.toString())
            .where((e) => e.isNotEmpty)
            .toList();
      }
    }
    return const <String>[];
  }

  static Duration? _readFeedCacheDuration(Map<String, dynamic> json) {
    final dp1Playlist = json[dp1PlaylistKey];
    if (dp1Playlist is! Map<String, dynamic>) return null;

    final raw = dp1Playlist[dp1PlaylistFeedCacheDurationKey];
    if (raw == null) return null;
    final seconds = int.tryParse(raw.toString());
    if (seconds == null || seconds <= 0) return null;
    return Duration(seconds: seconds);
  }

  static DateTime? _readFeedLastUpdatedAt(Map<String, dynamic> json) {
    final dp1Playlist = json[dp1PlaylistKey];
    if (dp1Playlist is! Map<String, dynamic>) return null;

    final raw = dp1Playlist[dp1PlaylistFeedLastUpdatedKey];
    if (raw == null) return null;
    final parsed = DateTime.tryParse(raw.toString());
    if (parsed != null) {
      return parsed.toUtc();
    }
    return null;
  }
}
