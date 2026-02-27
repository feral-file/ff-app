/// Feed server info (url + createdAt).
/// Matches old repo's [FeedServerInfo].
class FeedServerInfo {
  FeedServerInfo({required this.url, required this.createdAt});

  FeedServerInfo.fromUrl(String url) : url = url, createdAt = DateTime.now();

  final String url;
  final DateTime createdAt;
}
