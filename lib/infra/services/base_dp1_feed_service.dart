/// Abstract base for DP1 feed services.
///
/// Defines the contract for feed services that fetch and cache DP1 playlists
/// and channels from feed servers.
abstract class BaseDP1FeedService {
  /// Creates a base DP1 feed service.
  BaseDP1FeedService({required this.baseUrl});

  /// Feed server base URL (origin).
  final String baseUrl;

  /// Whether this is an external (user-added) feed service.
  bool get isExternalFeedService => false;

  /// Reload cache if needed based on policy.
  ///
  /// When [force] is true, the cache is always reloaded regardless of policy.
  /// Otherwise, cache policy (TTL + remote last-updated) is evaluated.
  Future<void> reloadCacheIfNeeded({bool force = false});

  /// Force reload cache (ignores policy).
  ///
  /// Fetches all playlists and channels from the feed server and ingests
  /// them into the database.
  Future<void> reloadCache();
}
