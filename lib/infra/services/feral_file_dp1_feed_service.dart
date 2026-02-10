import 'dart:async';

import 'package:app/domain/models/dp1/dp1_channel.dart';
import 'package:app/domain/models/dp1/dp1_playlist.dart';
import 'package:app/infra/services/dp1_feed_with_channel_extension_service_impl.dart';
import 'package:app/infra/services/dp1_playlist_items_enrichment_service.dart';
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
    required DP1PlaylistItemsEnrichmentService enrichmentService,
    super.isExternalFeedService,
    super.dio,
  }) : _enrichmentService = enrichmentService,
       _log = Logger('FeralFileDP1FeedService[$baseUrl]');

  /// Indexer service for token enrichment.
  final IndexerService indexerService;

  final DP1PlaylistItemsEnrichmentService _enrichmentService;

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
    await clearCache();
    await _enrichmentService.clear();

    var fetchedChannelCount = 0;
    var fetchedPlaylistCount = 0;

    for (final channelId in _remoteConfigChannelIds) {
      final channel = await getChannelDetail(channelId, fromCache: false);
      if (channel == null) {
        _log.warning('Skipping missing remote config channel: $channelId');
        continue;
      }
      fetchedChannelCount += 1;

      await databaseService.ingestDP1ChannelsWire(
        baseUrl: baseUrl,
        channels: <DP1Channel>[channel],
      );

      String? cursor;
      var hasMore = true;
      while (hasMore) {
        final response = await getPlaylistsByChannelId(
          channelId: channel.id,
          cursor: cursor,
          limit: 20,
        );
        hasMore = response.hasMore;
        cursor = response.cursor;

        for (final playlist in response.items) {
          fetchedPlaylistCount += 1;
          await databaseService.ingestDP1PlaylistBare(
            baseUrl: baseUrl,
            playlist: playlist,
            channelId: channel.id,
          );
          // Enqueue but don't wait for processing
          await _enrichmentService.enqueuePlaylist(
            playlistId: playlist.id,
            items: playlist.items,
          );
        }
      }
    }

    // Fire off enrichment in the background (don't wait)
    _log.info(
      'Queued enrichment for $fetchedPlaylistCount playlists; '
      'starting background processing...',
    );
    unawaited(_enrichmentService.processAll());

    _log.info(
      'Reloaded cache with remote config channels: '
      '$fetchedChannelCount channels, '
      '$fetchedPlaylistCount playlists (enrichment in progress)',
    );
  }
}
