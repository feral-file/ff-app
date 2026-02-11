
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
