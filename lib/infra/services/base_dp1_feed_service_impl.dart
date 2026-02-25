import 'dart:async';

import 'package:app/domain/models/dp1/dp1_api_responses.dart';
import 'package:app/domain/models/dp1/dp1_playlist.dart';
import 'package:app/domain/models/playlist.dart';
import 'package:app/domain/models/playlist_item.dart';
import 'package:app/infra/api/dp1_feed_api.dart';
import 'package:app/infra/config/app_state_service.dart';
import 'package:app/infra/database/converters.dart';
import 'package:app/infra/database/database_service.dart';
import 'package:app/infra/services/base_dp1_feed_service.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';

/// Base implementation of DP1 feed service (playlist + cache).
/// Matches old repo's [BaseDP1FeedServiceImpl].
/// Cache methods return Data; API methods return DP1. Uses existing converters when needed.
class BaseDP1FeedServiceImpl extends BaseDP1FeedService {
  BaseDP1FeedServiceImpl({
    required super.baseUrl,
    required DatabaseService databaseService,
    required AppStateService appStateService,
    required String apiKey,
    this.isExternalFeedService = false,
    Dio? dio,
  }) : databaseService = databaseService,
       appStateService = appStateService,
       apiKey = apiKey,
       api = Dp1FeedApiImpl(
         dio: dio ?? Dio(),
         baseUrl: baseUrl,
         apiKey: apiKey,
       ) {
    _log = Logger('BaseDP1FeedServiceImpl[$baseUrl]');
  }

  @override
  final bool isExternalFeedService;

  @protected
  final DatabaseService databaseService;

  @protected
  final AppStateService appStateService;

  @protected
  final String apiKey;

  @protected
  final DP1FeedApi api;

  late final Logger _log;

  /// Initialize; can be overridden by subclasses.
  Future<void> init({
    FutureOr<void> Function(Object)? onPlaylistError,
    FutureOr<void> Function(Object)? onChannelError,
    Dio? dio,
  }) async {
    // Dependencies are set in constructor; override dio if provided.
    if (dio != null) {
      // Subclass may replace api/dio
    }
  }

  @override
  Future<DP1Playlist?> getPlaylistById(
    String playlistId, {
    bool usingCache = true,
  }) async {
    if (usingCache) {
      final cached = await getCachedPlaylistById(playlistId);
      if (cached == null) return null;
      return DatabaseConverters.playlistAndItemsToDP1Playlist(
        cached.$1,
        cached.$2,
      );
    }
    try {
      return await api.getPlaylistById(playlistId);
    } catch (e) {
      _log.info('Error fetching playlist by ID $playlistId: $e');
      return null;
    }
  }

  @override
  Future<List<DP1Playlist>> getAllPlaylists() async {
    final playlists = <DP1Playlist>[];
    var hasMore = true;
    String? cursor;
    const limit = 50;
    while (hasMore) {
      final resp = await api.getPlaylists(cursor: cursor, limit: limit);
      playlists.addAll(resp.items);
      hasMore = resp.hasMore;
      cursor = resp.cursor;
    }
    return playlists;
  }

  @override
  Future<(Playlist, List<PlaylistItem>)?> getCachedPlaylistById(
    String id,
  ) async {
    final playlistData = await databaseService.getPlaylistById(id);
    if (playlistData == null || playlistData.baseUrl != baseUrl) return null;
    final items = await databaseService.getPlaylistItems(id);
    return (playlistData, items);
  }

  @override
  Future<List<(Playlist, List<PlaylistItem>)>> getAllCachedPlaylists() async {
    return databaseService.getPlaylistRowsWithItems(
      type: PlaylistType.dp1,
      baseUrl: baseUrl,
    );
  }

  @override
  Future<bool> deletePlaylist(String id) async {
    await api.deletePlaylist(id);
    await databaseService.deletePlaylistById(id);
    return true;
  }

  @override
  Future<DP1PlaylistItemsResponse> getPlaylistItems({
    String? cursor,
    int? limit,
  }) async {
    return api.getPlaylistItems(cursor: cursor, limit: limit);
  }

  bool _isReloadingCache = false;
  bool _isPaused = false;

  /// Pause or resume long-running feed sync work.
  void setPaused(bool paused) {
    _isPaused = paused;
  }

  @protected
  bool get isPaused => _isPaused;

  @override
  Future<void> reloadCache() async {
    if (_isReloadingCache) return;
    _isReloadingCache = true;
    try {
      var hasMore = true;
      String? cursor;
      const limit = 50;
      while (hasMore) {
        if (_isPaused) {
          _log.info('Reload cache paused for $baseUrl');
          return;
        }
        final resp = await api.getPlaylists(cursor: cursor, limit: limit);

        hasMore = resp.hasMore;
        cursor = resp.cursor;
      }
    } finally {
      _isReloadingCache = false;
    }
  }

  @override
  Future<void> clearCache() async {
    await appStateService.deleteLastRefreshTime(baseUrl);
    await databaseService.deleteAllPlaylistsByKindAndBaseUrl(
      type: PlaylistType.dp1,
      baseUrl: baseUrl,
    );
  }

  Future<bool> shouldReloadCache() async {
    final lastRefresh = await appStateService.getLastRefreshTime(baseUrl);
    final cacheDuration = await appStateService.getCacheDuration();
    final lastUpdated = await appStateService.getLastFeedUpdatedAt();

    final now = DateTime.now();
    final isStaleByAge = lastRefresh.isBefore(now.subtract(cacheDuration));
    final isOutdatedByRemote = lastUpdated.isAfter(lastRefresh);

    final shouldUpdate = isStaleByAge || isOutdatedByRemote;

    _log.info(
      '[BaseDP1FeedServiceImpl] shouldReloadCache '
      'baseUrl=$baseUrl, shouldUpdate=$shouldUpdate, '
      'lastServiceRefresh=$lastRefresh, '
      'updateFeedDuration=$cacheDuration, '
      'lastFeedUpdateAt=$lastUpdated',
    );

    return shouldUpdate;
  }

  @override
  Future<void> reloadCacheIfNeeded({bool force = false}) async {
    if (_isPaused) {
      _log.info(
        '[BaseDP1FeedServiceImpl] Skip reload while paused for baseUrl=$baseUrl',
      );
      return;
    }
    if (force) {
      _log.info(
        '[BaseDP1FeedServiceImpl] Forced cache reload for baseUrl=$baseUrl',
      );
      await reloadCache();
      await appStateService.setLastRefreshTime(baseUrl, DateTime.now());
      return;
    }

    final shouldUpdate = await shouldReloadCache();
    if (!shouldUpdate) {
      _log.info(
        '[BaseDP1FeedServiceImpl] Skip cache reload for baseUrl=$baseUrl '
        '(up to date)',
      );
      return;
    }

    _log.info(
      '[BaseDP1FeedServiceImpl] Reloading cache (policy) for baseUrl=$baseUrl',
    );
    await reloadCache();
    await appStateService.setLastRefreshTime(baseUrl, DateTime.now());
  }

  /// Get service name map (url -> name). Default empty.
  Map<String, String> getServiceUrlToNameMap() => const {};

  String? get name => getServiceUrlToNameMap()[baseUrl];
}
