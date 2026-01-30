import 'package:dio/dio.dart';
import 'package:logging/logging.dart';

import '../../domain/models/channel.dart';
import 'dp1_feed_service.dart';

/// DP1 feed service with remote config channel support.
///
/// When remote config channel IDs are set via [setRemoteConfigChannelIds],
/// this service automatically uses composite cursor pagination for playlist
/// fetching during cache reload.
///
/// This matches the old repo's `FeralFileDP1FeedService` behavior.
class FeralFileDP1FeedService extends DP1FeedServiceImpl {
  /// Creates a FeralFileDP1FeedService.
  FeralFileDP1FeedService({
    required super.baseUrl,
    required super.databaseService,
    required super.indexerService,
    required super.feedConfigStore,
    required super.apiKey,
    super.dio,
  }) {
    _log = Logger('FeralFileDP1FeedService[$baseUrl]');
  }

  final List<String> _remoteConfigChannelIds = [];
  late final Logger _log;

  /// Set remote config channel IDs for this feed server.
  ///
  /// When set, [reloadCache] will use composite cursor pagination to fetch
  /// playlists from these specific channels instead of fetching all playlists.
  void setRemoteConfigChannelIds(List<String> channelIds) {
    _remoteConfigChannelIds
      ..clear()
      ..addAll(channelIds);
    _log.info(
      'Set ${channelIds.length} remote config channel IDs for $baseUrl',
    );
  }

  @override
  Future<void> reloadCache() async {
    if (_remoteConfigChannelIds.isNotEmpty) {
      _log.info(
        'Reloading cache with remote config channels: '
        '${_remoteConfigChannelIds.length} channels',
      );
      await _reloadCacheWithRemoteConfigChannels();
    } else {
      _log.info('Reloading cache (no remote config channels)');
      await super.reloadCache();
    }
  }

  Future<void> _reloadCacheWithRemoteConfigChannels() async {
    // 1. Fetch channels by IDs
    final channels = await _fetchChannelsByIds(_remoteConfigChannelIds);
    _log.info('Fetched ${channels.length} channels');

    // 2. Fetch playlists using composite cursor
    final playlists = await _fetchPlaylistsFromChannels(
      channelIds: _remoteConfigChannelIds,
    );
    _log.info('Fetched ${playlists.length} playlists');

    // 3. Ingest to DB
    await databaseService.ingestChannels(channels);
    for (final playlistJson in playlists) {
      await ingestPlaylistFromFeed(
        baseUrl: baseUrl,
        playlistJson: playlistJson,
      );
    }

    _log.info(
      'Reloaded cache with remote config channels: '
      '${channels.length} channels, ${playlists.length} playlists',
    );
  }

  /// Fetch channels by IDs.
  Future<List<Channel>> _fetchChannelsByIds(List<String> channelIds) async {
    final channels = <Channel>[];

    for (final channelId in channelIds) {
      try {
        final uri = Uri.parse('$baseUrl/api/v1/channels/$channelId');
        final response = await dio.getUri<Map<String, dynamic>>(
          uri,
          options: Options(headers: buildHeaders('GET')),
        );

        if (response.statusCode != 200) {
          _log.warning(
            'Failed to fetch channel $channelId: ${response.statusCode}',
          );
          continue;
        }

        final json = response.data as Map<String, dynamic>;
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
      } on Exception catch (e) {
        _log.warning('Error fetching channel $channelId: $e');
      }
    }

    return channels;
  }

  /// Fetch playlists from multiple channels with composite cursor.
  ///
  /// Fetches all playlists across all channels using pagination.
  Future<List<Map<String, dynamic>>> _fetchPlaylistsFromChannels({
    required List<String> channelIds,
  }) async {
    final allPlaylists = <Map<String, dynamic>>[];
    var hasMore = true;
    String? cursor;
    const limit = 20;

    while (hasMore) {
      final result = await _fetchPlaylistsFromChannelsWithCursor(
        channelIds: channelIds,
        cursor: cursor,
        limit: limit,
      );
      allPlaylists.addAll(result.items);
      hasMore = result.hasMore;
      cursor = result.cursor;
    }

    return allPlaylists;
  }

  /// Composite cursor pagination logic (from old repo lines 155-224).
  ///
  /// Cursor format: "channelIndex:innerCursor" (e.g., "2:abc123")
  /// - Parse cursor to extract current channel index and inner cursor
  /// - Fetch playlists from channels sequentially until limit reached
  /// - When a channel is exhausted, move to next channel
  /// - Return composite cursor for resuming pagination
  Future<({List<Map<String, dynamic>> items, bool hasMore, String? cursor})>
      _fetchPlaylistsFromChannelsWithCursor({
    required List<String> channelIds,
    String? cursor,
    int? limit,
  }) async {
    if (channelIds.isEmpty) {
      return (items: <Map<String, dynamic>>[], hasMore: false, cursor: null);
    }

    // Parse composite cursor: "channelIndex:innerCursor"
    var currentChannelIndex = 0;
    String? currentChannelCursor;
    if (cursor != null && cursor.contains(':')) {
      final parts = cursor.split(':');
      if (parts.length == 2) {
        currentChannelIndex = int.tryParse(parts[0]) ?? 0;
        currentChannelCursor = parts[1].isEmpty ? null : parts[1];
      }
    }

    currentChannelIndex = currentChannelIndex.clamp(0, channelIds.length - 1);

    final allItems = <Map<String, dynamic>>[];
    var hasMore = false;
    String? nextCursor;

    for (var i = currentChannelIndex; i < channelIds.length; i++) {
      final channelId = channelIds[i];
      try {
        final remainingLimit = limit != null ? limit - allItems.length : limit;
        final response = await _fetchPlaylistsByChannelId(
          channelId: channelId,
          cursor: (i == currentChannelIndex) ? currentChannelCursor : null,
          limit: remainingLimit,
        );

        allItems.addAll(response.items);

        // If we've reached the requested limit, prepare next cursor
        if (limit != null && allItems.length >= limit) {
          if (response.hasMore) {
            hasMore = true;
            nextCursor = '$i:${response.cursor ?? ''}';
          } else if (i < channelIds.length - 1) {
            hasMore = true;
            nextCursor = '${i + 1}:';
          }
          break;
        }

        if (response.hasMore) {
          hasMore = true;
          nextCursor = '$i:${response.cursor ?? ''}';
          break;
        } else if (i < channelIds.length - 1) {
          hasMore = true;
          nextCursor = '${i + 1}:';
        }
      } on Exception catch (e) {
        _log.warning('Failed to fetch playlists for channel $channelId: $e');
        // Skip failed channel, move to next
        if (i < channelIds.length - 1) {
          hasMore = true;
          nextCursor = '${i + 1}:';
        }
      }
    }

    return (items: allItems, hasMore: hasMore, cursor: nextCursor);
  }

  /// Fetch playlists for a single channel.
  Future<
      ({
        List<Map<String, dynamic>> items,
        bool hasMore,
        String? cursor,
      })> _fetchPlaylistsByChannelId({
    required String channelId,
    String? cursor,
    int? limit,
  }) async {
    final uri = Uri.parse('$baseUrl/api/v1/playlists');
    final queryParams = <String, String>{
      'channel': channelId,
      if (limit != null) 'limit': limit.toString(),
      if (cursor != null) 'cursor': cursor,
    };
    final finalUri = uri.replace(queryParameters: queryParams);

    final response = await dio.getUri<Map<String, dynamic>>(
      finalUri,
      options: Options(headers: buildHeaders('GET')),
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Failed to fetch playlists for channel $channelId: '
        '${response.statusCode}',
      );
    }

    final data = response.data as Map<String, dynamic>;
    final items = (data['items'] as List?)
            ?.map((e) => e as Map<String, dynamic>)
            .toList() ??
        [];
    final hasMore = (data['hasMore'] as bool?) ?? false;
    final nextCursor = data['cursor'] as String?;

    return (items: items, hasMore: hasMore, cursor: nextCursor);
  }

}
