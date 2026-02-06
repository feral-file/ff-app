import 'dart:async';

import 'package:app/domain/models/channel.dart';
import 'package:app/domain/models/dp1/dp1_api_responses.dart';
import 'package:app/domain/models/dp1/dp1_channel.dart';
import 'package:app/domain/models/dp1/dp1_playlist.dart';
import 'package:app/domain/models/playlist.dart';
import 'package:app/domain/models/playlist_item.dart';
import 'package:app/infra/database/converters.dart';
import 'package:app/infra/database/drift_kinds.dart';
import 'package:app/infra/services/base_dp1_feed_service_impl.dart';
import 'package:dio/dio.dart';
import 'package:logging/logging.dart';

/// Extension of base DP1 feed service with channel-aware APIs.
/// Cache methods return domain models; API methods return DP1.
class DP1FeedWithChannelExtensionServiceImpl extends BaseDP1FeedServiceImpl {
  DP1FeedWithChannelExtensionServiceImpl({
    required super.baseUrl,
    required super.databaseService,
    required super.feedConfigStore,
    required super.apiKey,
    super.isExternalFeedService,
    super.dio,
  }) {
    _log = Logger('DP1FeedWithChannelExtensionServiceImpl[$baseUrl]');
  }

  late final Logger _log;

  @override
  Future<void> init({
    FutureOr<void> Function(Object)? onPlaylistError,
    FutureOr<void> Function(Object)? onChannelError,
    Dio? dio,
  }) async {
    await super.init(
      onPlaylistError: onPlaylistError,
      onChannelError: onChannelError,
      dio: dio,
    );
  }

  /// GET /api/v1/playlists?channel=channelId
  Future<DP1PlaylistResponse> getPlaylistsByChannelId({
    required String channelId,
    String? cursor,
    int? limit,
  }) async {
    return api.getPlaylists(
      channelId: channelId,
      cursor: cursor,
      limit: limit,
    );
  }

  Future<List<(Playlist, List<PlaylistItem>)>> getCachedPlaylistsByChannelId(
    String channelId,
  ) async {
    return databaseService.getPlaylistRowsWithItems(
      channelId: channelId,
      kind: DriftPlaylistKind.dp1.value,
      baseUrl: baseUrl,
    );
  }

  Future<DP1PlaylistResponse> getAllPlaylistsByChannelIds({
    required List<String> channelIds,
    String? cursor,
    int? limit,
  }) async {
    if (channelIds.isEmpty) {
      return DP1PlaylistResponse(<DP1Playlist>[], false, null);
    }

    int currentChannelIndex = 0;
    String? currentChannelCursor = cursor;
    if (cursor != null && cursor.contains(':')) {
      final parts = cursor.split(':');
      if (parts.length == 2) {
        currentChannelIndex = int.tryParse(parts[0]) ?? 0;
        currentChannelCursor = parts[1].isEmpty ? null : parts[1];
      }
    }

    currentChannelIndex = currentChannelIndex.clamp(0, channelIds.length - 1);

    final allItems = <DP1Playlist>[];
    var hasMore = false;
    String? nextCursor;

    for (var i = currentChannelIndex; i < channelIds.length; i++) {
      final cid = channelIds[i];
      try {
        final remainingLimit = limit != null ? limit - allItems.length : limit;
        final response = await getPlaylistsByChannelId(
          channelId: cid,
          cursor: (i == currentChannelIndex) ? currentChannelCursor : null,
          limit: remainingLimit,
        );

        allItems.addAll(response.items);

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
      } catch (e) {
        _log.info('Error getting playlists for channel $cid: $e');
        if (i < channelIds.length - 1) {
          hasMore = true;
          nextCursor = '${i + 1}:';
        }
      }
    }

    return DP1PlaylistResponse(allItems, hasMore, nextCursor);
  }

  Future<DP1Channel?> getChannelByPlaylistId(String playlistId) async {
    final data = await databaseService.getChannelByPlaylistId(playlistId);
    if (data == null) return null;
    final playlistUrls = data.$2
        .map((p) {
          try {
            final uri = Uri.parse(p.baseUrl ?? data.$3);
            final origin = uri.origin;
            if (origin.isEmpty) return null;
            return '$origin/api/v1/playlists/${p.id}';
          } catch (_) {
            return null;
          }
        })
        .whereType<String>()
        .toList();
    return DatabaseConverters.channelToDP1Channel(data.$1, playlistUrls);
  }

  Future<DP1Channel?> getChannelDetail(
    String channelId, {
    bool fromCache = true,
  }) async {
    if (fromCache) {
      final channel = await getCachedChannelById(channelId);
      if (channel == null) return null;
      final playlists = await databaseService.getPlaylistsByChannel(channelId);
      final urls = playlists.map((p) {
        final o = p.baseUrl != null && p.baseUrl!.isNotEmpty
            ? p.baseUrl
            : baseUrl;
        return '$o/api/v1/playlists/${p.id}';
      }).toList();
      return DatabaseConverters.channelToDP1Channel(channel, urls);
    }
    try {
      return await api.getChannelById(channelId);
    } catch (_) {
      return null;
    }
  }

  Future<Channel?> getCachedChannelById(String channelId) async {
    final channel = await databaseService.getChannelById(channelId);
    if (channel == null || channel.baseUrl != baseUrl) return null;
    return channel;
  }

  static Iterable<List<T>> _batch<T>(List<T> list, int size) sync* {
    for (var i = 0; i < list.length; i += size) {
      yield list.sublist(i, (i + size).clamp(0, list.length));
    }
  }

  Future<List<DP1Channel>> getChannelsByIds({
    required List<String> channelIds,
    bool usingCache = true,
  }) async {
    const batchSize = 10;
    final channels = <DP1Channel>[];
    for (final batch in _batch(channelIds, batchSize)) {
      final futures = batch.map(
        (id) => getChannelDetail(id, fromCache: usingCache),
      );
      final results = await Future.wait(futures);
      for (final c in results) {
        if (c != null) channels.add(c);
      }
    }
    return channels;
  }

  Future<List<DP1Channel>> getAllChannels() async {
    final channels = <DP1Channel>[];
    var hasMore = true;
    String? cursor;
    const limit = 10;
    while (hasMore) {
      final resp = await api.getAllChannels(cursor: cursor, limit: limit);
      channels.addAll(resp.items);
      hasMore = resp.hasMore;
      cursor = resp.cursor;
    }
    return channels;
  }

  Future<List<Channel>> getAllCachedChannels() async {
    final channels = await databaseService.getChannels();
    return channels.where((c) => c.baseUrl == baseUrl).toList();
  }

  Future<DP1PlaylistItemsResponse> getPlaylistItemsOfChannel({
    required String channelId,
    String? cursor,
    int? limit,
    bool usingCache = true,
  }) async {
    return api.getPlaylistItems(
      channelId: channelId,
      cursor: cursor,
      limit: limit,
    );
  }

  bool _isReloadingCache = false;

  @override
  Future<void> reloadCache() async {
    if (_isReloadingCache) return;
    _isReloadingCache = true;
    try {
      _log.info('Reloading cache for FeralFileDP1FeedService: $baseUrl');
      final channels = await getAllChannels();
      final playlists = await getAllPlaylists();
      await clearCache();

      await databaseService.ingestDP1ChannelsWire(
        baseUrl: baseUrl,
        channels: channels,
      );

      for (final channel in channels) {
        final playlistsInChannel = playlists
            .where(
              (p) => channel.playlists.contains(
                '${Uri.parse(baseUrl).origin}/api/v1/playlists/${p.id}',
              ),
            )
            .toList();
        for (final playlist in playlistsInChannel) {
          await databaseService.ingestDP1PlaylistWire(
            baseUrl: baseUrl,
            playlist: playlist,
            channelId: channel.id,
          );
        }
      }

      _log.info('Reloaded cache for FeedService: $baseUrl');
    } catch (e) {
      _log.info('Failed to reload cache for FeralFileDP1FeedService: $e');
      rethrow;
    } finally {
      _isReloadingCache = false;
    }
  }

  @override
  Future<void> clearCache() async {
    await super.clearCache();
    await databaseService.deleteAllChannelsByKindAndBaseUrl(
      type: DriftChannelKind.dp1.value,
      baseUrl: baseUrl,
    );
  }
}
