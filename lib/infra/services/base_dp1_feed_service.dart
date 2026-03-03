import 'package:app/domain/models/dp1/dp1_api_responses.dart';
import 'package:app/domain/models/dp1/dp1_playlist.dart';
import 'package:app/domain/models/models.dart' show Channel, DP1Channel;
import 'package:app/domain/models/playlist.dart';
import 'package:app/domain/models/playlist_item.dart';

/// Abstract base for DP1 feed services.
///
/// Cache methods return domain models ([Playlist], [Channel], [PlaylistItem]).
/// API methods return DP1 wire models ([DP1Playlist], [DP1Channel], etc.).
abstract class BaseDP1FeedService {
  /// Creates a base DP1 feed service.
  BaseDP1FeedService({required this.baseUrl});

  /// Feed server base URL (origin).
  final String baseUrl;

  /// Whether this is an external (user-added) feed service.
  bool get isExternalFeedService => false;

  /// Get playlist by ID (from API only).
  Future<DP1Playlist?> getPlaylistById(
    String playlistId, {
    bool usingCache = true,
  });

  /// Get cached playlist by ID (domain only).
  Future<(Playlist, List<PlaylistItem>)?> getCachedPlaylistById(String id);

  /// Get all playlists (full fetch, from API).
  Future<List<DP1Playlist>> getAllPlaylists();

  /// Get all cached playlists from local storage (domain only).
  Future<List<(Playlist, List<PlaylistItem>)>> getAllCachedPlaylists();

  /// Delete a playlist.
  Future<bool> deletePlaylist(String id);

  /// Get playlist items with pagination.
  Future<DP1PlaylistItemsResponse> getPlaylistItems({
    String? cursor,
    int? limit,
  });

  /// Clear cache for this feed service (last refresh + stored data).
  Future<void> clearCache();

  /// Reload cache if needed based on policy.
  Future<void> reloadCacheIfNeeded({bool force = false});

  /// Force reload cache (ignores policy).
  Future<void> reloadCache();
}
