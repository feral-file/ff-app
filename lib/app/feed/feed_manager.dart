import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:collection/collection.dart';
import 'package:logging/logging.dart';

import 'package:app/app/feed/feed_reference_models.dart';
import 'package:app/domain/models/dp1/dp1_api_responses.dart';
import 'package:app/domain/models/dp1/dp1_playlist_item.dart';
import 'package:app/domain/models/playlist.dart';
import 'package:app/domain/models/pair.dart';
import 'package:app/infra/config/feed_config_store.dart';
import 'package:app/infra/config/remote_app_config.dart';
import 'package:app/infra/database/converters.dart';
import 'package:app/infra/database/database_service.dart';
import 'package:app/infra/database/drift_kinds.dart';
import 'package:app/infra/services/base_dp1_feed_service_impl.dart';
import 'package:app/infra/services/feral_file_dp1_feed_service.dart';
import 'package:app/infra/services/indexer_enrichment_scheduler_service.dart';
import 'package:app/infra/services/indexer_service.dart';
import 'package:synchronized/synchronized.dart';

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
  final Lock _reloadLock = Lock();
  bool _isPaused = false;
  bool _isEnrichmentWorkerRunning = false;
  Future<void>? _enrichmentWorkerFuture;

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
    await _reloadLock.synchronized(() async {
      _log.info('[FeedManager] Reload all cache, force: $force');
      if (_isPaused) {
        _log.info('[FeedManager] Skip reload while paused');
        return;
      }

      final services = feedServices;
      if (services.isEmpty) return;

      var shouldReloadFromPolicy = force;
      if (!force) {
        for (final feedService in services) {
          if (_isPaused) return;
          final stale = await feedService.shouldReloadCache();
          if (stale) {
            shouldReloadFromPolicy = true;
            break;
          }
        }
      }

      if (force || shouldReloadFromPolicy) {
        await _feedConfigStore.clearSyncStages();
      }

      var bareLoaded = await _feedConfigStore.isBareItemsLoaded();
      var tokensEnriched = await _feedConfigStore.isTokensEnriched();

      if (!force && !shouldReloadFromPolicy && bareLoaded && tokensEnriched) {
        _log.info('[FeedManager] Skip reload; all stages already complete');
        return;
      }

      if (!bareLoaded) {
        if (!shouldReloadFromPolicy && !force) {
          // Cache is not stale and services report up-to-date; infer stage complete.
          await _feedConfigStore.markBareItemsLoaded();
          bareLoaded = true;
        } else {
          final reloadFutures = services
              .map((feedService) async {
                if (_isPaused) return;
                try {
                  await feedService.reloadCacheIfNeeded(
                    force: force || shouldReloadFromPolicy,
                  );
                } on Exception catch (e, stack) {
                  _log.warning(
                    'Failed to reload cache for ${feedService.baseUrl}',
                    e,
                    stack,
                  );
                }
              })
              .toList(growable: false);

          await Future.wait(reloadFutures);
          if (_isPaused) return;
          await _feedConfigStore.markBareItemsLoaded();
          bareLoaded = true;
        }
      }

      if (bareLoaded && !tokensEnriched) {
        _startEnrichmentWorkerIfIdle();
      }
    });
  }

  /// Pause feed and enrichment work.
  void pauseWork() {
    _isPaused = true;
    for (final feedService in feedServices) {
      feedService.setPaused(true);
    }
    _log.info('[FeedManager] Work paused');
  }

  /// Resume feed and enrichment work.
  void resumeWork() {
    _isPaused = false;
    for (final feedService in feedServices) {
      feedService.setPaused(false);
    }
    _log.info('[FeedManager] Work resumed');
  }

  @protected
  bool get isPaused => _isPaused;

  /// Runs enrichment for all bare playlist items.
  ///
  /// Base manager has no enrichment stage.
  @protected
  Future<bool> runGlobalEnrichment() async => true;

  void onChannelIngested() {
    if (_isPaused) return;
    // Keep it simple: if loop is running, ignore new notifications.
    if (_isEnrichmentWorkerRunning) return;
    _startEnrichmentWorkerIfIdle();
  }

  void _startEnrichmentWorkerIfIdle() {
    if (_isEnrichmentWorkerRunning) return;
    _enrichmentWorkerFuture ??= _runEnrichmentWorker();
  }

  Future<void> _runEnrichmentWorker() async {
    if (_isEnrichmentWorkerRunning || _isPaused) return;
    _isEnrichmentWorkerRunning = true;
    try {
      final completed = await runGlobalEnrichment();
      if (!_isPaused && completed) {
        await _feedConfigStore.markTokensEnriched();
      }
    } finally {
      _isEnrichmentWorkerRunning = false;
      _enrichmentWorkerFuture = null;
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
    required IndexerEnrichmentSchedulerService enrichmentScheduler,
    required String apiKey,
    this.onChannelPersistedInDatabase,
  }) : _indexerService = indexerService,
       _enrichmentScheduler = enrichmentScheduler,
       _apiKey = apiKey;

  @override
  final String defaultDp1FeedUrl;

  final IndexerService _indexerService;
  final IndexerEnrichmentSchedulerService _enrichmentScheduler;
  final String _apiKey;
  final Future<void> Function()? onChannelPersistedInDatabase;

  List<RemoteConfigChannel> remoteConfigChannels = [];

  Future<void> init() async {
    _setupDefault();
  }

  void _setupDefault() {}

  /// Setup remote config channels from curated URLs; then load custom feed servers.
  /// Matches old repo's setupRemoteConfigChannels step-by-step.
  Future<void> setupRemoteConfigChannels(
    List<RemoteConfigPublisher> publishers,
  ) async {
    final remoteConfigChannelsParsed = <RemoteConfigChannel>[];
    for (final publisher in publishers) {
      for (final url in publisher.channelUrls) {
        final uri = Uri.parse(url);
        remoteConfigChannelsParsed.add(
          RemoteConfigChannel(
            endpoint: uri.origin,
            channelId: uri.pathSegments.isNotEmpty
                ? uri.pathSegments.last
                : uri.path,
            publisherId: publisher.id,
          ),
        );
      }
    }
    remoteConfigChannels = remoteConfigChannelsParsed;

    final channelsByUrl = <String, List<RemoteConfigChannel>>{};
    for (final channel in remoteConfigChannelsParsed) {
      channelsByUrl.putIfAbsent(channel.endpoint, () => []).add(channel);
    }

    for (final publisher in publishers) {
      await databaseService.ingestPublisher(
        id: publisher.id,
        name: publisher.name,
      );
    }

    for (final endpoint in channelsByUrl.keys) {
      final endpointChannels = channelsByUrl[endpoint]!;
      final existingService = getFeedServiceByUrl(endpoint);
      if (existingService != null) {
        (existingService as FeralFileDP1FeedService).setRemoteConfigChannels(
          endpointChannels
              .map(
                (channel) => RemoteConfigFeedChannel(
                  channelId: channel.channelId,
                  publisherId: channel.publisherId,
                ),
              )
              .toList(),
        );
        continue;
      }

      final service = FeralFileDP1FeedService(
        baseUrl: endpoint,
        databaseService: databaseService,
        feedConfigStore: feedConfigStore,
        apiKey: _apiKey,
        indexerService: _indexerService,
        onChannelIngested: onChannelIngested,
      );
      service.setPaused(isPaused);
      await service.init();
      service.setRemoteConfigChannels(
        endpointChannels
            .map(
              (channel) => RemoteConfigFeedChannel(
                channelId: channel.channelId,
                publisherId: channel.publisherId,
              ),
            )
            .toList(),
      );
      addFeedService(service);
    }

    _log.info(
      'Finish setup remote config channels: '
      '${remoteConfigChannels.map((e) => e.channelId).toList()}',
    );
  }

  @override
  Future<bool> runGlobalEnrichment() async {
    if (isPaused) return false;
    return _enrichmentScheduler.processFeedEnrichmentUntilIdle();
  }

  @override
  void onChannelIngested() {
    super.onChannelIngested();
    _enrichmentScheduler.notifyFeedWorkAvailable();
    final callback = onChannelPersistedInDatabase;
    if (callback != null) {
      unawaited(callback());
    }
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
