import 'package:flutter/foundation.dart';
import 'package:collection/collection.dart';
import 'package:logging/logging.dart';

import 'package:app/app/feed/feed_reference_models.dart';
import 'package:app/domain/models/dp1/dp1_api_responses.dart';
import 'package:app/domain/models/dp1/dp1_playlist_item.dart';
import 'package:app/domain/models/playlist.dart';
import 'package:app/domain/models/pair.dart';
import 'package:app/infra/config/feed_config_store.dart';
import 'package:app/infra/database/converters.dart';
import 'package:app/infra/database/database_service.dart';
import 'package:app/infra/database/drift_kinds.dart';
import 'package:app/infra/services/base_dp1_feed_service_impl.dart';
import 'package:app/infra/services/feral_file_dp1_feed_service.dart';
import 'package:app/infra/services/indexer_service.dart';

/// Base feed manager: holds feed services and provides cache/reload APIs.
/// Matches old repo's [FeedManager].
///
/// Uses domain models ([Channel], [Playlist], [PlaylistItem]) from
/// [DatabaseService] and feed services. [PlaylistReference] / [ChannelReference]
/// wrap domain models only (no Data or DP1 in UI).
class FeedManager {
  FeedManager({
    required DatabaseService databaseService,
    required FeedConfigStore feedConfigStore,
  }) : _databaseService = databaseService,
       _feedConfigStore = feedConfigStore {
    _log = Logger('FeedManager');
  }

  @protected
  DatabaseService get databaseService => _databaseService;
  @protected
  FeedConfigStore get feedConfigStore => _feedConfigStore;

  final DatabaseService _databaseService;
  final FeedConfigStore _feedConfigStore;
  late final Logger _log;

  final List<Pair<String, BaseDP1FeedServiceImpl>> _feedServices = [];

  /// Default DP1 feed URL (for feralFileFeedService getter); set by [FeralFileFeedManager].
  String get defaultDp1FeedUrl => '';

  /// Feral File feed service for the default DP1 feed URL.
  /// Matches old repo's FeedManager.feralFileFeedService.
  FeralFileDP1FeedService get feralFileFeedService {
    final url = defaultDp1FeedUrl;
    final pair = _feedServices.firstWhereOrNull((e) => e.first == url);
    if (pair == null) {
      throw StateError('No FeralFileDP1FeedService for default URL: $url');
    }
    return pair.second as FeralFileDP1FeedService;
  }

  BaseDP1FeedServiceImpl addFeedService(BaseDP1FeedServiceImpl feedService) {
    if (isFeedServiceExists(feedService.baseUrl)) {
      _log.info('Feed service already exists for url: ${feedService.baseUrl}');
      return getFeedServiceByUrl(feedService.baseUrl)!;
    }
    _feedServices.add(Pair(feedService.baseUrl, feedService));
    return feedService;
  }

  BaseDP1FeedServiceImpl? getFeedServiceByUrl(String url) {
    return _feedServices
        .firstWhereOrNull((feedService) => feedService.first == url)
        ?.second;
  }

  void removeFeedServiceByUrl(String url) {
    _feedServices.removeWhere((feedService) => feedService.first == url);
  }

  bool isFeedServiceExists(String url) {
    return _feedServices.any((feedService) => feedService.first == url);
  }

  List<BaseDP1FeedServiceImpl> get feedServices => [
    ..._feedServices.map((e) => e.second),
  ];

  Future<void> reloadAllCache({bool force = false}) async {
    _log.info('[FeedManager] Reload all cache, force: $force');
    for (final feedService in feedServices) {
      try {
        await feedService.reloadCacheIfNeeded(force: force);
      } on Exception catch (e, stack) {
        _log.warning(
          'Failed to reload cache for ${feedService.baseUrl}',
          e,
          stack,
        );
      }
    }
  }

  /// Matches old repo's getAllCachedPlaylists(offset, limit).
  Future<List<PlaylistReference>> getAllCachedPlaylists({
    int? offset,
    int? limit,
  }) async {
    final baseUrls = feedServices.map((s) => s.baseUrl).toList();
    if (baseUrls.isEmpty) return [];

    final rows = await _databaseService.getPlaylistRowsByBaseUrls(
      baseUrls: baseUrls,
      kind: DriftPlaylistKind.dp1.value,
      offset: offset,
      limit: limit,
    );

    return rows
        .map((row) => PlaylistReference(playlist: row.$1, url: row.$3))
        .toList();
  }

  /// Matches old repo's clearAllCache.
  Future<void> clearAllCache() async {
    await _feedConfigStore.setLastTimeRefreshFeeds(DateTime(1970, 1, 1));
    for (final feedService in feedServices) {
      await feedService.clearCache();
    }
  }
}

/// Feral File feed manager: remote config channels + custom feed servers.
/// Matches old repo's [FeralFileFeedManager].
/// Same Data/Reference rule as [FeedManager]; uses existing converters.
class FeralFileFeedManager extends FeedManager {
  FeralFileFeedManager({
    required super.databaseService,
    required super.feedConfigStore,
    required this.defaultDp1FeedUrl,
    required IndexerService indexerService,
    required String apiKey,
  }) : _indexerService = indexerService,
       _apiKey = apiKey;

  @override
  final String defaultDp1FeedUrl;

  final IndexerService _indexerService;
  final String _apiKey;

  List<RemoteConfigChannel> remoteConfigChannels = [];

  Future<void> init() async {
    _setupDefault();
  }

  void _setupDefault() {}

  /// Setup remote config channels from curated URLs; then load custom feed servers.
  /// Matches old repo's setupRemoteConfigChannels step-by-step.
  Future<void> setupRemoteConfigChannels(List<String> channelUrls) async {
    final remoteConfigChannelsParsed = channelUrls.map((url) {
      final uri = Uri.parse(url);
      return RemoteConfigChannel(
        endpoint: uri.origin,
        channelId: uri.pathSegments.isNotEmpty
            ? uri.pathSegments.last
            : uri.path,
      );
    }).toList();
    remoteConfigChannels = remoteConfigChannelsParsed;

    final channelIdsByUrl = <String, List<String>>{};
    for (final channel in remoteConfigChannels) {
      channelIdsByUrl
          .putIfAbsent(channel.endpoint, () => [])
          .add(channel.channelId);
    }

    for (final endpoint in channelIdsByUrl.keys) {
      final existingService = getFeedServiceByUrl(endpoint);
      if (existingService != null) {
        (existingService as FeralFileDP1FeedService).addRemoteConfigChannelIds(
          channelIdsByUrl[endpoint]!,
        );
        continue;
      }

      final service = FeralFileDP1FeedService(
        baseUrl: endpoint,
        databaseService: databaseService,
        feedConfigStore: feedConfigStore,
        apiKey: _apiKey,
        indexerService: _indexerService,
      );
      Object? error;
      await service.init(
        onPlaylistError: (e) {
          error = e;
        },
        onChannelError: (e) {
          error = e;
        },
      );
      service.addRemoteConfigChannelIds(channelIdsByUrl[endpoint]!);
      addFeedService(service);

      if (error != null) {
        _log.info('Error initializing feed service: $error');
        service.reloadCacheIfNeeded(force: true);
      }
    }

    _log.info(
      'Finish setup remote config channels: '
      '${remoteConfigChannels.map((e) => e.channelId).toList()}',
    );
  }

  /// Matches old repo's getAllCachedChannels.
  Future<List<ChannelReference>> getAllCachedChannels() async {
    final allChannelReferences = <ChannelReference>[];
    for (final feedService in feedServices) {
      if (feedService is FeralFileDP1FeedService) {
        final channels = await feedService.getAllCachedChannels();
        for (final channel in channels) {
          allChannelReferences.add(
            ChannelReference(channel: channel, url: feedService.baseUrl),
          );
        }
      }
    }
    return allChannelReferences;
  }

  /// Matches old repo's getAllCachedPlaylistsOfChannels.
  Future<List<PlaylistReference>> getAllCachedPlaylistsOfChannels(
    List<ChannelReference> channels,
  ) async {
    final allPlaylistReferences = <PlaylistReference>[];
    for (final channelRef in channels) {
      final service = getFeedServiceByUrl(channelRef.url);
      if (service is FeralFileDP1FeedService) {
        final rows = await service.getCachedPlaylistsByChannelId(
          channelRef.channel.id,
        );
        for (final row in rows) {
          allPlaylistReferences.add(
            PlaylistReference(playlist: row.$1, url: channelRef.url),
          );
        }
      }
    }
    return allPlaylistReferences;
  }

  /// Matches old repo's getChannelReferenceByChannelId.
  Future<ChannelReference?> getChannelReferenceByChannelId(
    String channelId,
  ) async {
    for (final feedService in feedServices) {
      if (feedService is FeralFileDP1FeedService) {
        try {
          final channel = await feedService.getCachedChannelById(channelId);
          if (channel != null) {
            return ChannelReference(
              channel: channel,
              url: feedService.baseUrl,
            );
          }
        } on Exception catch (e) {
          _log.info(
            'Error getting channel by ID $channelId: $e, '
            'service: ${feedService.baseUrl}',
          );
        }
      }
    }
    return null;
  }

  /// Matches old repo's getPlaylistReferenceByPlaylistId.
  Future<PlaylistReference?> getPlaylistReferenceByPlaylistId(
    String playlistId,
  ) async {
    for (final feedService in feedServices) {
      final dp1 = await feedService.getPlaylistById(playlistId);
      if (dp1 != null) {
        return PlaylistReference(
          playlist: DatabaseConverters.dp1PlaylistToDomain(
            dp1,
            baseUrl: feedService.baseUrl,
          ),
          url: feedService.baseUrl,
        );
      }
    }
    return null;
  }

  /// Matches old repo's getPlaylistItemsByListOfChannels.
  Future<DP1PlaylistItemsResponse> getPlaylistItemsByListOfChannels({
    required List<RemoteConfigChannel> channels,
    String? cursor,
    int? limit,
    bool usingCache = true,
  }) async {
    if (channels.isEmpty) {
      return DP1PlaylistItemsResponse([], false, null);
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

    currentChannelIndex = currentChannelIndex.clamp(0, channels.length - 1);

    final allItems = <DP1PlaylistItem>[];
    var hasMore = false;
    String? nextCursor;

    for (var i = currentChannelIndex; i < channels.length; i++) {
      final channel = channels[i];
      try {
        final remainingLimit = limit != null ? limit - allItems.length : limit;

        final feedService =
            getFeedServiceByUrl(channel.endpoint) as FeralFileDP1FeedService;

        final response = await feedService.getPlaylistItemsOfChannel(
          channelId: channel.channelId,
          cursor: (i == currentChannelIndex) ? currentChannelCursor : null,
          limit: remainingLimit,
          usingCache: usingCache,
        );

        allItems.addAll(response.items);

        if (limit != null && allItems.length >= limit) {
          if (response.hasMore) {
            hasMore = true;
            nextCursor = '${i}:${response.cursor ?? ''}';
          } else if (i < channels.length - 1) {
            hasMore = true;
            nextCursor = '${i + 1}:';
          }
          break;
        }

        if (response.hasMore) {
          hasMore = true;
          nextCursor = '${i}:${response.cursor ?? ''}';
          break;
        } else if (i < channels.length - 1) {
          hasMore = true;
          nextCursor = '${i + 1}:';
        }
      } on Exception catch (e) {
        _log.info(
          'Error getting playlist items for channel ${channel.channelId}: $e',
        );
        if (i < channels.length - 1) {
          hasMore = true;
          nextCursor = '${i + 1}:';
        }
      }
    }

    return DP1PlaylistItemsResponse(allItems, hasMore, nextCursor);
  }

  /// Matches old repo's getCachedChannelReferenceByPlaylist.
  Future<ChannelReference?> getCachedChannelReferenceByPlaylist(
    Playlist playlist,
  ) async {
    final data = await databaseService.getChannelByPlaylistId(playlist.id);
    if (data == null) return null;
    return ChannelReference(channel: data.$1, url: data.$3);
  }
}

/// Extension for [PlaylistReference] to get creator title from cached channel.
/// Matches old repo's PlaylistReferenceExtension.getCreator.
extension PlaylistReferenceExtension on PlaylistReference {
  /// Get creator title of the playlist from cached channel reference.
  Future<String> getCreator(FeralFileFeedManager manager) async {
    final channelReference = await manager.getCachedChannelReferenceByPlaylist(
      playlist,
    );
    return channelReference?.channel.name ?? '';
  }
}
