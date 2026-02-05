import 'package:app/domain/models/dp1/dp1_api_responses.dart';
import 'package:app/domain/models/dp1/dp1_playlist.dart';
import 'package:app/domain/models/playlist.dart';
import 'package:app/domain/models/playlist_item.dart';
import 'package:app/infra/api/dp1_feed_api.dart';
import 'package:app/infra/config/feed_config_store.dart';
import 'package:app/infra/database/converters.dart';
import 'package:app/infra/database/database_service.dart';
import 'package:app/infra/database/drift_kinds.dart';
import 'package:app/infra/services/base_dp1_feed_service.dart';
import 'package:app/infra/services/indexer_service.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';

/// Service for fetching and ingesting DP1 playlists from feed servers.
///
/// This implementation includes cache policy support (TTL + remote last-updated)
/// and conditional authentication headers (Bearer only for POST/PUT).
/// Cache methods return domain models; API methods return DP1.
class DP1FeedServiceImpl extends BaseDP1FeedService {
  /// Creates a DP1FeedServiceImpl.
  DP1FeedServiceImpl({
    required super.baseUrl,
    required DatabaseService databaseService,
    required IndexerService indexerService,
    required FeedConfigStore feedConfigStore,
    required String apiKey,
    Dio? dio,
  }) : databaseService = databaseService,
       indexerService = indexerService,
       feedConfigStore = feedConfigStore,
       apiKey = apiKey,
       api = Dp1FeedApiImpl(
         dio: dio ?? Dio(),
         baseUrl: baseUrl,
         apiKey: apiKey,
       ) {
    log = Logger('DP1FeedServiceImpl[$baseUrl]');
  }

  /// Database service for persisting playlists and channels.
  @protected
  final DatabaseService databaseService;

  /// Indexer service for token enrichment.
  @protected
  final IndexerService indexerService;

  /// Feed config store for cache policy.
  @protected
  final FeedConfigStore feedConfigStore;

  /// API key for authentication.
  @protected
  final String apiKey;

  /// DP1 feed API client.
  @protected
  final DP1FeedApi api;

  /// Logger instance.
  @protected
  late final Logger log;

  bool _isReloadingCache = false;

  /// Check if cache should reload (TTL or remote updated).
  @visibleForTesting
  Future<bool> shouldReloadCache() async {
    final lastRefresh = await feedConfigStore.getLastRefreshTime(baseUrl);
    final cacheDuration = await feedConfigStore.getCacheDuration();
    final lastUpdated = await feedConfigStore.getLastFeedUpdatedAt();

    final now = DateTime.now();
    final isStaleByAge = lastRefresh.isBefore(now.subtract(cacheDuration));
    final isOutdatedByRemote = lastUpdated.isAfter(lastRefresh);

    final shouldReload = isStaleByAge || isOutdatedByRemote;

    log.info(
      'shouldReloadCache: $shouldReload, '
      'lastRefresh=$lastRefresh, '
      'cacheDuration=$cacheDuration, '
      'lastUpdated=$lastUpdated',
    );

    return shouldReload;
  }

  @override
  Future<void> reloadCacheIfNeeded({bool force = false}) async {
    if (force) {
      log.info('Forced cache reload for baseUrl=$baseUrl');
      await reloadCache();
      await feedConfigStore.setLastRefreshTime(baseUrl, DateTime.now());
      return;
    }

    final shouldReload = await shouldReloadCache();
    if (!shouldReload) {
      log.info('Skip cache reload for baseUrl=$baseUrl (up to date)');
      return;
    }

    log.info('Reloading cache (policy) for baseUrl=$baseUrl');
    await reloadCache();
    await feedConfigStore.setLastRefreshTime(baseUrl, DateTime.now());
  }

  @override
  Future<void> reloadCache() async {
    if (_isReloadingCache) {
      log.info('Cache reload already in progress for baseUrl=$baseUrl');
      return;
    }
    _isReloadingCache = true;
    try {
      log.info('Reloading cache for baseUrl=$baseUrl');

      await databaseService.clearAll();

      var hasMore = true;
      String? cursor;
      const limit = 50;
      var totalPlaylists = 0;

      while (hasMore) {
        final resp = await api.getPlaylists(cursor: cursor, limit: limit);

        for (final playlist in resp.items) {
          await databaseService.ingestDP1PlaylistWire(
            baseUrl: baseUrl,
            playlist: playlist,
            fetchTokens: (cids) =>
                indexerService.fetchTokensByCIDs(tokenCids: cids),
          );
        }

        totalPlaylists += resp.items.length;
        hasMore = resp.hasMore;
        cursor = resp.cursor;
      }

      log.info(
        'Reloaded cache for baseUrl=$baseUrl: $totalPlaylists playlists',
      );
    } finally {
      _isReloadingCache = false;
    }
  }

  @override
  Future<(Playlist, List<PlaylistItem>)?> getCachedPlaylistById(
    String id,
  ) async {
    final playlist = await databaseService.getPlaylistById(id);
    if (playlist == null || playlist.baseUrl != baseUrl) return null;
    final items = await databaseService.getPlaylistItems(id);
    return (playlist, items);
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
      log.info('Error fetching playlist by ID $playlistId: $e');
      return null;
    }
  }

  @override
  Future<DP1PlaylistResponse> getPlaylists({
    String? cursor,
    int? limit,
  }) async {
    final resp = await api.getPlaylists(cursor: cursor, limit: limit);
    for (final playlist in resp.items) {
      await databaseService.ingestDP1PlaylistWire(
        baseUrl: baseUrl,
        playlist: playlist,
        fetchTokens: (cids) =>
            indexerService.fetchTokensByCIDs(tokenCids: cids),
      );
    }
    return resp;
  }

  @override
  Future<List<DP1Playlist>> getAllPlaylists() async {
    final playlists = <DP1Playlist>[];
    var hasMore = true;
    String? cursor;
    const limit = 50;
    while (hasMore) {
      final resp = await getPlaylists(cursor: cursor, limit: limit);
      playlists.addAll(resp.items);
      hasMore = resp.hasMore;
      cursor = resp.cursor;
    }
    return playlists;
  }

  @override
  Future<List<(Playlist, List<PlaylistItem>)>> getAllCachedPlaylists() async {
    return databaseService.getPlaylistRowsWithItems(
      kind: DriftPlaylistKind.dp1.value,
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

  @override
  Future<void> clearCache() async {
    await feedConfigStore.deleteLastRefreshTime(baseUrl);
    await databaseService.deleteAllPlaylistsByKindAndBaseUrl(
      kind: DriftPlaylistKind.dp1.value,
      baseUrl: baseUrl,
    );
    await databaseService.deleteAllChannelsByKindAndBaseUrl(
      type: DriftChannelKind.dp1.value,
      baseUrl: baseUrl,
    );
  }

  /// Fetch and ingest all playlists from a DP1 feed server.
  Future<int> fetchPlaylists({
    required String baseUrl,
    int? limit,
    String? cursor,
  }) async {
    try {
      log.info('Fetching playlists from $baseUrl');

      final resp = await api.getPlaylists(cursor: cursor, limit: limit);

      log.info('Fetched ${resp.items.length} playlists from feed');

      var ingestedCount = 0;
      for (final playlist in resp.items) {
        await databaseService.ingestDP1PlaylistWire(
          baseUrl: baseUrl,
          playlist: playlist,
          fetchTokens: (cids) =>
              indexerService.fetchTokensByCIDs(tokenCids: cids),
        );
        ingestedCount++;
      }

      log.info('Successfully ingested $ingestedCount playlists into database');
      return resp.items.length;
    } catch (e, stack) {
      log.severe('Failed to fetch playlists from $baseUrl', e, stack);
      rethrow;
    }
  }

  /// Ingest a single playlist from feed data.
  @protected
  Future<void> ingestPlaylistFromFeed({
    required String baseUrl,
    required Map<String, dynamic> playlistJson,
  }) async {
    try {
      final typed = DP1PlaylistResponse.fromJson(
        <String, dynamic>{
          'items': [playlistJson],
          'hasMore': false,
          'cursor': null,
        },
      ).items.single;

      await databaseService.ingestDP1PlaylistWire(
        baseUrl: baseUrl,
        playlist: typed,
        fetchTokens: (cids) =>
            indexerService.fetchTokensByCIDs(tokenCids: cids),
      );
    } catch (e, stack) {
      log.severe('Failed to ingest playlist from feed', e, stack);
      rethrow;
    }
  }

  /// Fetch and ingest all channels from a feed server.
  Future<int> fetchChannels({
    required String baseUrl,
    int? limit,
    String? cursor,
  }) async {
    try {
      log.info('Fetching channels from $baseUrl');

      final resp = await api.getAllChannels(cursor: cursor, limit: limit);

      log.info('Fetched ${resp.items.length} channels from feed');

      await databaseService.ingestDP1ChannelsWire(
        baseUrl: baseUrl,
        channels: resp.items,
      );
      log.info(
        'Successfully ingested ${resp.items.length} channels into database',
      );

      return resp.items.length;
    } catch (e, stack) {
      log.severe('Failed to fetch channels from $baseUrl', e, stack);
      rethrow;
    }
  }

  /// Fetch and ingest a channel from a feed server.
  Future<void> fetchChannel({
    required String baseUrl,
    required String channelId,
  }) async {
    try {
      log.info('Fetching channel $channelId from $baseUrl');

      final dp1 = await api.getChannelById(channelId);

      await databaseService.ingestDP1ChannelsWire(
        baseUrl: baseUrl,
        channels: [dp1],
      );
      log.info('Ingested channel: $channelId');
    } catch (e, stack) {
      log.severe('Failed to fetch channel $channelId', e, stack);
      rethrow;
    }
  }
}
