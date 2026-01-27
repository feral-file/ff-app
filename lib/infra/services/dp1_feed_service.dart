import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';

import '../../domain/models/channel.dart';
import '../../domain/models/playlist.dart';
import '../database/database_service.dart';
import 'indexer_service.dart';

/// Service for fetching and ingesting DP1 playlists from feed servers.
class DP1FeedService {
  /// Creates a DP1FeedService.
  DP1FeedService({
    required DatabaseService databaseService,
    required IndexerService indexerService,
    required String apiKey,
    Dio? dio,
  }) : _databaseService = databaseService,
       _indexerService = indexerService,
       _apiKey = apiKey,
       _dio = dio ?? Dio() {
    _log = Logger('DP1FeedService');
  }

  final DatabaseService _databaseService;
  final IndexerService _indexerService;
  final String _apiKey;
  final Dio _dio;
  late final Logger _log;

  /// Expose Dio instance for testing.
  @visibleForTesting
  Dio get dio => _dio;

  /// Fetch and ingest all playlists from a DP1 feed server.
  Future<int> fetchPlaylists({
    required String baseUrl,
    int? limit,
    String? cursor,
  }) async {
    try {
      _log.info('Fetching playlists from $baseUrl');

      // Build request URL
      final uri = Uri.parse('$baseUrl/api/v1/playlists');
      final queryParams = <String, String>{};
      if (limit != null) queryParams['limit'] = limit.toString();
      if (cursor != null) queryParams['cursor'] = cursor;

      final finalUri = uri.replace(queryParameters: queryParams);
      _log.info('Requesting: $finalUri');

      // Fetch playlists with authentication
      final response = await _dio.getUri(
        finalUri,
        options: Options(
          headers: {
            'Authorization': 'Bearer $_apiKey',
            'Content-Type': 'application/json',
          },
        ),
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to fetch playlists: ${response.statusCode}');
      }

      final data = response.data as Map<String, dynamic>;
      final items = (data['items'] as List?) ?? [];

      _log.info('Fetched ${items.length} playlists from feed');

      // Ingest each playlist
      var ingestedCount = 0;
      for (final playlistJson in items) {
        await ingestPlaylistFromFeed(
          baseUrl: baseUrl,
          playlistJson: playlistJson as Map<String, dynamic>,
        );
        ingestedCount++;
      }

      _log.info('Successfully ingested $ingestedCount playlists into database');
      return items.length;
    } catch (e, stack) {
      _log.severe('Failed to fetch playlists from $baseUrl', e, stack);
      rethrow;
    }
  }

  /// Ingest a single playlist from feed data.
  @visibleForTesting
  Future<void> ingestPlaylistFromFeed({
    required String baseUrl,
    required Map<String, dynamic> playlistJson,
  }) async {
    try {
      final playlistId = playlistJson['id'] as String;
      final title = playlistJson['title'] as String;
      final slug = playlistJson['slug'] as String?;
      final dpVersion = playlistJson['dpVersion'] as String?;
      final channelId = playlistJson['channelId'] as String?;

      _log.info('Ingesting playlist: $playlistId');

      // Parse signatures
      final signaturesJson = playlistJson['signatures'] as List?;
      final signatures = signaturesJson?.map((s) => s.toString()).toList();

      // Parse defaults
      final defaults = playlistJson['defaults'] as Map<String, dynamic>?;

      // Parse dynamic queries
      final dynamicQueriesJson = playlistJson['dynamicQueries'] as List?;
      Map<String, dynamic>? dynamicQueries;
      if (dynamicQueriesJson != null && dynamicQueriesJson.isNotEmpty) {
        // Store dynamic queries for later resolution
        dynamicQueries = {
          'queries': dynamicQueriesJson,
        };
      }

      // Determine sort mode based on playlist type
      // Dynamic playlists use provenance sorting, static use position
      final sortMode = dynamicQueries != null
          ? PlaylistSortMode.provenance
          : PlaylistSortMode.position;

      // Create playlist domain model
      final playlist = Playlist(
        id: playlistId,
        name: title,
        type: PlaylistType.dp1,
        playlistSource: PlaylistSource.curated,
        channelId: channelId,
        baseUrl: baseUrl,
        dpVersion: dpVersion,
        slug: slug,
        signatures: signatures,
        defaults: defaults,
        dynamicQueries: dynamicQueries,
        sortMode: sortMode,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Extract items (may be empty for dynamic playlists)
      final itemsJson = playlistJson['items'] as List?;
      final items =
          itemsJson?.map((item) => item as Map<String, dynamic>).toList() ?? [];

      // Extract CIDs for token enrichment (use 'cid' field, not 'id')
      // DP1 items have both 'id' (UUID) and 'cid' (IPFS CID)
      final cids = items
          .map((item) => item['cid'] as String?)
          .where((cid) => cid != null)
          .cast<String>()
          .toList();

      // Fetch enrichment tokens if CIDs available
      List<Map<String, dynamic>>? enrichmentTokens;
      if (cids.isNotEmpty) {
        try {
          enrichmentTokens = await _indexerService.fetchTokensByCIDs(
            cids: cids,
          );
        } catch (e) {
          _log.warning('Failed to fetch enrichment tokens: $e');
          // Continue without enrichment
        }
      }

      // Ingest playlist with items
      await _databaseService.ingestDP1Playlist(
        playlist: playlist,
        items: items,
        enrichmentTokens: enrichmentTokens,
      );

      if (dynamicQueries != null) {
        _log.info(
          'Ingested dynamic playlist $playlistId '
          '(items will be resolved from indexer)',
        );
      } else {
        _log.info('Ingested playlist $playlistId with ${items.length} items');
      }
    } catch (e, stack) {
      _log.severe('Failed to ingest playlist from feed', e, stack);
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
      _log.info('Fetching channels from $baseUrl');

      // Build request URL
      final uri = Uri.parse('$baseUrl/api/v1/channels');
      final queryParams = <String, String>{};
      if (limit != null) queryParams['limit'] = limit.toString();
      if (cursor != null) queryParams['cursor'] = cursor;

      final finalUri = uri.replace(queryParameters: queryParams);
      _log.info('Requesting: $finalUri');

      // Fetch channels with authentication
      final response = await _dio.getUri(
        finalUri,
        options: Options(
          headers: {
            'Authorization': 'Bearer $_apiKey',
            'Content-Type': 'application/json',
          },
        ),
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to fetch channels: ${response.statusCode}');
      }

      final data = response.data as Map<String, dynamic>;
      final items = (data['items'] as List?) ?? [];

      _log.info('Fetched ${items.length} channels from feed');

      // Ingest each channel
      final channels = <Channel>[];
      for (final channelJson in items) {
        final json = channelJson as Map<String, dynamic>;
        final channelId = json['id'] as String;

        final channel = Channel(
          id: channelId,
          name: json['title'] as String,
          type: ChannelType.dp1,
          description: json['summary'] as String?,
          baseUrl: baseUrl,
          slug: json['slug'] as String?,
          curator: json['curator'] as String?,
          coverImageUrl: json['coverImageUri'] as String?,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        channels.add(channel);
      }

      // Batch ingest
      await _databaseService.ingestChannels(channels);
      _log.info(
        'Successfully ingested ${channels.length} channels into database',
      );

      return channels.length;
    } catch (e, stack) {
      _log.severe('Failed to fetch channels from $baseUrl', e, stack);
      rethrow;
    }
  }

  /// Fetch and ingest a channel from a feed server.
  Future<void> fetchChannel({
    required String baseUrl,
    required String channelId,
  }) async {
    try {
      _log.info('Fetching channel $channelId from $baseUrl');

      final uri = Uri.parse('$baseUrl/api/v1/channels/$channelId');
      final response = await _dio.getUri(
        uri,
        options: Options(
          headers: {
            'Authorization': 'Bearer $_apiKey',
            'Content-Type': 'application/json',
          },
        ),
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to fetch channel: ${response.statusCode}');
      }

      final channelJson = response.data as Map<String, dynamic>;

      final channel = Channel(
        id: channelId,
        name: channelJson['title'] as String,
        type: ChannelType.dp1,
        description: channelJson['summary'] as String?,
        baseUrl: baseUrl,
        slug: channelJson['slug'] as String?,
        curator: channelJson['curator'] as String?,
        coverImageUrl: channelJson['coverImageUri'] as String?,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await _databaseService.ingestChannel(channel);
      _log.info('Ingested channel: $channelId');
    } catch (e, stack) {
      _log.severe('Failed to fetch channel $channelId', e, stack);
      rethrow;
    }
  }
}
