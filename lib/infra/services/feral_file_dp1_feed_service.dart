import 'dart:async';

import 'package:app/domain/models/dp1/dp1_channel.dart';
import 'package:app/domain/models/dp1/dp1_playlist.dart';
import 'package:app/infra/services/dp1_feed_with_channel_extension_service_impl.dart';
import 'package:app/infra/services/indexer_service.dart';
import 'package:logging/logging.dart';

/// DP1 feed service with remote config channel support.
///
/// Matches old repo's [FeralFileDP1FeedService]:
/// - [addRemoteConfigChannelIds] adds channel IDs (does not replace).
/// - When remote config channel IDs are set, [getAllPlaylists] and
///   [getAllChannels] use channel-scoped fetch.
/// - [reloadCache] loads channels/playlists and queues items for enrichment
///   (enrichment runs in parallel without blocking).
class FeralFileDP1FeedService extends DP1FeedWithChannelExtensionServiceImpl {
  /// Creates a FeralFileDP1FeedService.
  FeralFileDP1FeedService({
    required super.baseUrl,
    required super.databaseService,
    required super.feedConfigStore,
    required super.apiKey,
    required this.indexerService,
    super.isExternalFeedService,
    super.dio,
  }) : _log = Logger('FeralFileDP1FeedService[$baseUrl]');

  /// Indexer service for token enrichment.
  final IndexerService indexerService;

  late final Logger _log;

  final List<String> _remoteConfigChannelIds = [];

  /// Add remote config channel IDs (accumulative; matches old repo).
  void addRemoteConfigChannelIds(List<String> channelIds) {
    _remoteConfigChannelIds.addAll(channelIds);
    _log.info(
      'Added ${channelIds.length} remote config channel IDs for $baseUrl',
    );
  }

  /// Set remote config channel IDs (replaces existing; for FeedRegistry compat).
  void setRemoteConfigChannelIds(List<String> channelIds) {
    _remoteConfigChannelIds
      ..clear()
      ..addAll(channelIds);
    _log.info(
      'Set ${channelIds.length} remote config channel IDs for $baseUrl',
    );
  }

  @override
  Future<List<DP1Playlist>> getAllPlaylists() async {
    if (_remoteConfigChannelIds.isNotEmpty) {
      final playlists = <DP1Playlist>[];
      var hasMore = true;
      String? cursor;
      const limit = 20;
      while (hasMore) {
        final response = await getAllPlaylistsByChannelIds(
          channelIds: _remoteConfigChannelIds,
          cursor: cursor,
          limit: limit,
        );
        playlists.addAll(response.items);
        hasMore = response.hasMore;
        cursor = response.cursor;
      }
      return playlists;
    } else {
      return super.getAllPlaylists();
    }
  }

  @override
  Future<List<DP1Channel>> getAllChannels() async {
    if (_remoteConfigChannelIds.isNotEmpty) {
      return getChannelsByIds(
        channelIds: _remoteConfigChannelIds,
        usingCache: false,
      );
    }
    return super.getAllChannels();
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
    if (isPaused) {
      _log.info('Skip remote-config cache reload while paused');
      return;
    }
    await clearCache();

    final results = await Future.wait(
      _remoteConfigChannelIds.map(_fetchChannelAndPlaylists),
    );

    var fetchedChannelCount = 0;
    var fetchedPlaylistCount = 0;
    for (final result in results) {
      if (isPaused) {
        _log.info('Pause requested before persisting fetched channel data');
        return;
      }
      if (result == null) continue;
      await databaseService.ingestDP1ChannelWithPlaylistsBare(
        baseUrl: baseUrl,
        channel: result.channel,
        playlists: result.playlists,
      );
      fetchedChannelCount += 1;
      fetchedPlaylistCount += result.playlists.length;
    }

    _log.info(
      'Reloaded cache with remote config channels: '
      '$fetchedChannelCount channels, '
      '$fetchedPlaylistCount playlists',
    );
  }

  Future<_ChannelLoadResult?> _fetchChannelAndPlaylists(String channelId) async {
    if (isPaused) return null;

    final channel = await getChannelDetail(channelId, fromCache: false);
    if (channel == null) {
      _log.warning('Skipping missing remote config channel: $channelId');
      return null;
    }

    final playlists = <DP1Playlist>[];
    String? cursor;
    var hasMore = true;
    while (hasMore) {
      if (isPaused) return null;
      final response = await getPlaylistsByChannelId(
        channelId: channel.id,
        cursor: cursor,
        limit: 20,
      );
      hasMore = response.hasMore;
      cursor = response.cursor;
      playlists.addAll(response.items);
    }

    return _ChannelLoadResult(
      channel: channel,
      playlists: playlists,
    );
  }
}

class _ChannelLoadResult {
  const _ChannelLoadResult({
    required this.channel,
    required this.playlists,
  });

  final DP1Channel channel;
  final List<DP1Playlist> playlists;
}
