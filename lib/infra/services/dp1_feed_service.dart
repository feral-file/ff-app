import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';

import 'package:app/domain/models/dp1/dp1_api_responses.dart';
import 'package:app/domain/models/dp1/dp1_playlist.dart';
import 'package:app/domain/models/indexer/asset_token.dart';
import 'package:app/infra/config/feed_config_store.dart';
import 'package:app/infra/database/database_service.dart';
import 'package:app/infra/services/base_dp1_feed_service.dart';
import 'package:app/infra/services/indexer_service.dart';

/// Service for fetching and ingesting DP1 playlists from feed servers.
///
/// This implementation includes cache policy support (TTL + remote last-updated)
/// and conditional authentication headers (Bearer only for POST/PUT).
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
       dio = dio ?? Dio() {
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

  /// Dio HTTP client.
  @protected
  final Dio dio;

  /// Logger instance.
  @protected
  late final Logger log;

  bool _isReloadingCache = false;

  /// Build HTTP headers with conditional authentication.
  ///
  /// Matches old repo behavior: Bearer token only for POST/PUT requests.
  @protected
  Map<String, String> buildHeaders(String method) {
    final headers = <String, String>{'Content-Type': 'application/json'};
    final upperMethod = method.toUpperCase();
    if (upperMethod == 'POST' || upperMethod == 'PUT') {
      headers['Authorization'] = 'Bearer $apiKey';
    }
    return headers;
  }

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

      // clear the cache
      await databaseService.clearAll();

      // Fetch all playlists with pagination
      var hasMore = true;
      String? cursor;
      const limit = 50;
      var totalPlaylists = 0;

      while (hasMore) {
        final uri = Uri.parse('$baseUrl/api/v1/playlists');
        final queryParams = <String, String>{
          'limit': limit.toString(),
          if (cursor != null) 'cursor': cursor,
        };
        final finalUri = uri.replace(queryParameters: queryParams);

        final response = await dio.getUri<Map<String, dynamic>>(
          finalUri,
          options: Options(headers: buildHeaders('GET')),
        );

        if (response.statusCode != 200) {
          throw Exception(
            'Failed to fetch playlists: ${response.statusCode}',
          );
        }

        final data = response.data as Map<String, dynamic>;
        final resp = DP1PlaylistResponse.fromJson(data);

        for (final playlist in resp.items) {
          await ingestPlaylistFromFeedModel(
            baseUrl: baseUrl,
            playlist: playlist,
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

  /// Fetch and ingest all playlists from a DP1 feed server.
  Future<int> fetchPlaylists({
    required String baseUrl,
    int? limit,
    String? cursor,
  }) async {
    try {
      log.info('Fetching playlists from $baseUrl');

      // Build request URL
      final uri = Uri.parse('$baseUrl/api/v1/playlists');
      final queryParams = <String, String>{};
      if (limit != null) queryParams['limit'] = limit.toString();
      if (cursor != null) queryParams['cursor'] = cursor;

      final finalUri = uri.replace(queryParameters: queryParams);
      log.info('Requesting: $finalUri');

      // Fetch playlists (no Bearer for GET in old repo)
      final response = await dio.getUri<Map<String, dynamic>>(
        finalUri,
        options: Options(headers: buildHeaders('GET')),
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to fetch playlists: ${response.statusCode}');
      }

      final data = response.data as Map<String, dynamic>;
      final resp = DP1PlaylistResponse.fromJson(data);

      log.info('Fetched ${resp.items.length} playlists from feed');

      // Ingest each playlist
      var ingestedCount = 0;
      for (final playlist in resp.items) {
        await ingestPlaylistFromFeedModel(baseUrl: baseUrl, playlist: playlist);
        ingestedCount++;
      }

      log.info('Successfully ingested $ingestedCount playlists into database');
      return resp.items.length;
    } catch (e, stack) {
      log.severe('Failed to fetch playlists from $baseUrl', e, stack);
      rethrow;
    }
  }

  /// Ingest a single DP1 playlist (wire model) into the local database.
  ///
  /// This mirrors the legacy mobile app behavior:
  /// - Parse DP1 playlist/items from the feed response
  /// - Enrich items with indexer token data (via CID) when available
  /// - Persist playlist + items + entries
  @protected
  Future<void> ingestPlaylistFromFeedModel({
    required String baseUrl,
    required DP1Playlist playlist,
  }) async {
    try {
      final cids = databaseService.extractDP1ItemCids(playlist.items);
      List<AssetToken>? tokens;
      if (cids.isNotEmpty) {
        try {
          tokens = await indexerService.fetchTokensByCIDs(tokenCids: cids);
        } on Exception catch (e) {
          log.warning('Failed to fetch enrichment tokens: $e');
        }
      }

      await databaseService.ingestDP1PlaylistWire(
        baseUrl: baseUrl,
        playlist: playlist,
        tokens: tokens,
      );
    } catch (e, stack) {
      log.severe('Failed to ingest playlist from feed', e, stack);
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
      // Keep the legacy Map-based ingestion API for call sites that still use
      // raw JSON. Internally, normalize to the typed DP1 wire model.
      final typed = DP1PlaylistResponse.fromJson(
        <String, dynamic>{
          'items': [playlistJson],
          'hasMore': false,
          'cursor': null,
        },
      ).items.single;

      await ingestPlaylistFromFeedModel(baseUrl: baseUrl, playlist: typed);
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

      // Build request URL
      final uri = Uri.parse('$baseUrl/api/v1/channels');
      final queryParams = <String, String>{};
      if (limit != null) queryParams['limit'] = limit.toString();
      if (cursor != null) queryParams['cursor'] = cursor;

      final finalUri = uri.replace(queryParameters: queryParams);
      log.info('Requesting: $finalUri');

      // Fetch channels (no Bearer for GET in old repo)
      final response = await dio.getUri<Map<String, dynamic>>(
        finalUri,
        options: Options(headers: buildHeaders('GET')),
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to fetch channels: ${response.statusCode}');
      }

      final data = response.data as Map<String, dynamic>;
      final resp = DP1ChannelsResponse.fromJson(data);

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

      final uri = Uri.parse('$baseUrl/api/v1/channels/$channelId');
      final response = await dio.getUri<Map<String, dynamic>>(
        uri,
        options: Options(headers: buildHeaders('GET')),
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to fetch channel: ${response.statusCode}');
      }

      final json = response.data as Map<String, dynamic>;
      final dp1 = DP1ChannelsResponse.fromJson(<String, dynamic>{
        'items': [json],
        'hasMore': false,
        'cursor': null,
      }).items.single;

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
