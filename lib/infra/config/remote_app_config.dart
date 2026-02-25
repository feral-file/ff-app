/// Publisher-level config from remote `dp1_playlist.publishers`.
class RemoteConfigPublisher {
  const RemoteConfigPublisher({
    required this.id,
    required this.name,
    required this.channelUrls,
    required this.feedCacheDuration,
    required this.feedLastUpdatedAt,
  });

  factory RemoteConfigPublisher.fromJson(
    Map<String, dynamic> json, {
    required int id,
  }) {
    final name = json[RemoteAppConfig.dp1PlaylistPublisherNameKey]
        ?.toString()
        .trim();
    if (name == null || name.isEmpty) {
      throw const FormatException('Missing publisher name.');
    }

    final channelUrls = _readChannelUrls(json);
    if (channelUrls.isEmpty) {
      throw const FormatException('Missing publisher channel URLs.');
    }

    final feedCacheDuration = _readFeedCacheDurationFromPublisher(json);
    if (feedCacheDuration == null) {
      throw const FormatException('Missing publisher feed cache duration.');
    }

    final feedLastUpdatedAt = _readFeedLastUpdatedAtFromPublisher(json);
    if (feedLastUpdatedAt == null) {
      throw const FormatException('Missing publisher feed last updated time.');
    }

    return RemoteConfigPublisher(
      id: id,
      name: name,
      channelUrls: channelUrls,
      feedCacheDuration: feedCacheDuration,
      feedLastUpdatedAt: feedLastUpdatedAt,
    );
  }

  /// Publisher id persisted as publisher array index (`0`, `1`, ...).
  final int id;
  final String name;
  final List<String> channelUrls;
  final Duration feedCacheDuration;
  final DateTime feedLastUpdatedAt;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    RemoteAppConfig.dp1PlaylistPublisherNameKey: name,
    RemoteAppConfig.dp1PlaylistChannelUrlsKey: channelUrls,
    RemoteAppConfig.dp1PlaylistFeedCacheDurationKey: feedCacheDuration.inSeconds
        .toString(),
    RemoteAppConfig.dp1PlaylistFeedLastUpdatedKey: feedLastUpdatedAt
        .toUtc()
        .toIso8601String(),
  };

  static List<String> _readChannelUrls(Map<String, dynamic> json) {
    final raw = json[RemoteAppConfig.dp1PlaylistChannelUrlsKey];
    if (raw is! List) return const <String>[];
    return raw
        .map((e) => e.toString().trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }

  static Duration? _readFeedCacheDurationFromPublisher(
    Map<String, dynamic> json,
  ) {
    final raw = json[RemoteAppConfig.dp1PlaylistFeedCacheDurationKey];
    if (raw == null) return null;
    final seconds = int.tryParse(raw.toString());
    if (seconds == null || seconds <= 0) return null;
    return Duration(seconds: seconds);
  }

  static DateTime? _readFeedLastUpdatedAtFromPublisher(
    Map<String, dynamic> json,
  ) {
    final raw = json[RemoteAppConfig.dp1PlaylistFeedLastUpdatedKey];
    if (raw == null) return null;
    return DateTime.tryParse(raw.toString())?.toUtc();
  }
}

/// Typed remote app config consumed by the app.
///
/// Expected keys in remote JSON:
/// - `dp1_playlist.publishers[*].name`
/// - `dp1_playlist.publishers[*].channel_urls`
/// - `dp1_playlist.publishers[*].feed_cache_duration`
/// - `dp1_playlist.publishers[*].feed_last_updated`
class RemoteAppConfig {
  const RemoteAppConfig({
    required this.publishers,
  });

  factory RemoteAppConfig.fromJson(Map<String, dynamic> json) {
    final publishers = _readPublishers(json);
    if (publishers.isEmpty) {
      throw const FormatException('Missing publishers in remote config.');
    }
    return RemoteAppConfig(
      publishers: publishers,
    );
  }

  final List<RemoteConfigPublisher> publishers;

  /// Flattened channel URLs in publisher order.
  List<String> get curatedChannelUrls => publishers
      .expand((publisher) => publisher.channelUrls)
      .toList(growable: false);

  /// Conservatively use shortest cache duration across publishers.
  Duration get feedCacheDuration {
    if (publishers.isEmpty) {
      return const Duration(days: 1);
    }
    return publishers
        .map((publisher) => publisher.feedCacheDuration)
        .reduce(
          (a, b) => a.inSeconds <= b.inSeconds ? a : b,
        );
  }

  /// Most recent feed update across publishers.
  DateTime get feedLastUpdatedAt {
    if (publishers.isEmpty) {
      return DateTime(2023);
    }
    return publishers
        .map((publisher) => publisher.feedLastUpdatedAt)
        .reduce((a, b) => a.isAfter(b) ? a : b);
  }

  static const String dp1PlaylistKey = 'dp1_playlist';
  static const String dp1PlaylistPublishersKey = 'publishers';
  static const String dp1PlaylistPublisherNameKey = 'name';
  static const String dp1PlaylistChannelUrlsKey = 'channel_urls';
  static const String dp1PlaylistFeedCacheDurationKey = 'feed_cache_duration';
  static const String dp1PlaylistFeedLastUpdatedKey = 'feed_last_updated';

  static List<RemoteConfigPublisher> _readPublishers(
    Map<String, dynamic> json,
  ) {
    final dp1Playlist = json[dp1PlaylistKey];
    if (dp1Playlist is! Map<String, dynamic>) {
      return const <RemoteConfigPublisher>[];
    }

    final rawPublishers = dp1Playlist[dp1PlaylistPublishersKey];
    if (rawPublishers is List && rawPublishers.isNotEmpty) {
      return rawPublishers
          .asMap()
          .entries
          .map((entry) {
            final map = entry.value;
            if (map is! Map<String, dynamic>) {
              throw const FormatException('Invalid publisher payload.');
            }
            return RemoteConfigPublisher.fromJson(map, id: entry.key);
          })
          .toList(growable: false);
    }

    return const <RemoteConfigPublisher>[];
  }
}
