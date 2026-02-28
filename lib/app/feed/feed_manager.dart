import 'dart:async';

import 'package:app/domain/models/channel.dart';
import 'package:app/domain/models/pair.dart';
import 'package:app/domain/models/playlist.dart';
import 'package:app/infra/config/app_state_service.dart';
import 'package:app/infra/database/database_service.dart';
import 'package:app/infra/services/base_dp1_feed_service_impl.dart';
import 'package:app/infra/services/feral_file_dp1_feed_service.dart';
import 'package:collection/collection.dart';
import 'package:logging/logging.dart';
import 'package:meta/meta.dart';
import 'package:synchronized/synchronized.dart';

/// Base feed manager: holds feed services and provides cache/reload APIs.
/// Matches old repo's [FeedManager].
///
/// Uses domain models ([Channel], [Playlist]) from
/// [DatabaseService] and feed services. Domain references wrap models only
/// (no Data or DP1 in UI).
class FeedManager {
  FeedManager({
    required DatabaseService databaseService,
    required AppStateService appStateService,
  }) : _databaseService = databaseService,
       _appStateService = appStateService {
    _log = Logger('FeedManager');
  }

  @protected
  DatabaseService get databaseService => _databaseService;
  @protected
  AppStateService get appStateService => _appStateService;

  final DatabaseService _databaseService;
  final AppStateService _appStateService;
  late final Logger _log;

  final List<Pair<String, BaseDP1FeedServiceImpl>> _feedServices = [];
  final Lock _reloadLock = Lock();
  bool _isPaused = false;

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
      if (services.isEmpty) {
        _log.info('[FeedManager] Skip reload: no feed services configured');
        return;
      }

      _log.info('[FeedManager] Reloading ${services.length} feed service(s)');

      final reloadFutures = services
          .map((feedService) async {
            if (_isPaused) return;
            try {
              if (force) {
                await feedService.reloadCacheIfNeeded(force: true);
                return;
              }

              final stale = await feedService.shouldReloadCache();
              final hasBareIngestCompleted = await _appStateService
                  .hasFeedBareIngestCompleted(feedService.baseUrl);

              _log.info(
                '[FeedManager] Service ${feedService.baseUrl} stale=$stale '
                'bareIngestCompleted=$hasBareIngestCompleted force=$force',
              );

              // Startup policy: skip expensive bare ingest when a feed already
              // completed bootstrap and the feed is not stale.
              if (!stale && hasBareIngestCompleted) {
                _log.info(
                  '[FeedManager] Skip reload for ${feedService.baseUrl}; '
                  'feed is fresh and bare ingest already completed',
                );
                return;
              }

              await feedService.reloadCacheIfNeeded(force: stale);
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

  /// Pause feed work and wait for any in-flight reload to settle.
  ///
  /// Forget-local-data flow uses this to avoid DP1 ingest writes racing
  /// SQLite truncation.
  Future<void> pauseAndDrainWork() async {
    pauseWork();
    await _reloadLock.synchronized(() async {});
    _log.info('[FeedManager] In-flight reload drained');
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

  /// Matches old repo's getAllCachedPlaylists(offset, limit).
  Future<List<Playlist>> getAllCachedPlaylists({
    int? offset,
    int? limit,
  }) async {
    final baseUrls = feedServices.map((s) => s.baseUrl).toList();
    if (baseUrls.isEmpty) return [];

    final rows = await _databaseService.getPlaylistRowsByBaseUrls(
      baseUrls: baseUrls,
      type: PlaylistType.dp1,
      offset: offset,
      limit: limit,
    );

    return rows
        .map(
          (row) => row.$1,
        )
        .toList();
  }

  /// Matches old repo's clearAllCache.
  Future<void> clearAllCache() async {
    for (final feedService in feedServices) {
      await feedService.clearCache();
    }
  }
}

/// Feral File feed manager.
/// Matches old repo's [FeralFileFeedManager].
/// Same Data/Reference rule as [FeedManager]; uses existing converters.
class FeralFileFeedManager extends FeedManager {
  FeralFileFeedManager({
    required super.databaseService,
    required super.appStateService,
    required this.defaultDp1FeedUrl,
    required this.defaultDp1FeedApiKey,
  });

  @override
  final String defaultDp1FeedUrl;

  /// API key used for the default DP1 feed service.
  final String defaultDp1FeedApiKey;

  Future<void> init() async {
    _setupDefault();
  }

  void _setupDefault() {
    if (defaultDp1FeedUrl.isEmpty) return;

    if (isFeedServiceExists(defaultDp1FeedUrl)) {
      _log.info(
        'Default feed service already configured for $defaultDp1FeedUrl',
      );
      return;
    }

    addFeedService(
      FeralFileDP1FeedService(
        baseUrl: defaultDp1FeedUrl,
        databaseService: databaseService,
        appStateService: appStateService,
        apiKey: defaultDp1FeedApiKey,
      ),
    );
  }

  /// Matches old repo's getAllCachedChannels.
  Future<List<Channel>> getAllCachedChannels() async {
    final allChannels = <Channel>[];
    for (final feedService in feedServices) {
      if (feedService is FeralFileDP1FeedService) {
        final channels = await feedService.getAllCachedChannels();
        for (final channel in channels) {
          allChannels.add(channel);
        }
      }
    }
    return allChannels;
  }

  /// Matches old repo's getAllCachedPlaylistsOfChannels.
  Future<List<Playlist>> getAllCachedPlaylistsOfChannels(
    List<String> channelIds,
  ) async {
    final allPlaylists = <Playlist>[];
    for (final channelId in channelIds) {
      final playlists = await databaseService.getPlaylistsByChannel(
        channelId,
      );
      allPlaylists.addAll(playlists);
    }
    return allPlaylists;
  }

  /// Matches old repo's getCachedChannelReferenceByPlaylist.
  Future<Channel?> getCachedChannelReferenceByPlaylist(
    Playlist playlist,
  ) async {
    final data = await databaseService.getChannelByPlaylistId(playlist.id);
    if (data == null) return null;
    return data.$1;
  }
}
