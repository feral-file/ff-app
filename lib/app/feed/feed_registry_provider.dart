import 'package:app/app/feed/feed_manager.dart';
import 'package:app/app/providers/indexer_provider.dart';
import 'package:app/app/providers/indexer_tokens_provider.dart';
import 'package:app/app/providers/remote_config_provider.dart';
import 'package:app/infra/config/app_config.dart';
import 'package:app/infra/config/app_state_service.dart';
import 'package:app/infra/config/remote_app_config.dart';
import 'package:app/infra/database/database_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';

/// A curated DP-1 channel reference derived from a full channel URL.
@immutable
class CuratedChannelRef {
  /// Creates a curated DP-1 channel reference.
  const CuratedChannelRef({
    required this.baseUrl,
    required this.channelId,
    required this.publisherId,
  });

  /// Feed server origin, e.g. `https://example.org`.
  final String baseUrl;

  /// DP-1 channel ID, e.g. `ch_...`.
  final String channelId;
  final int publisherId;

  /// Best-effort parser for curated DP-1 channel URLs.
  ///
  /// Expected shape:
  /// `https://example.org/api/v1/channels/ch_...`
  static CuratedChannelRef? tryParse(
    String raw, {
    required int publisherId,
  }) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;

    try {
      final uri = Uri.parse(trimmed);
      if (!uri.hasScheme || uri.host.isEmpty) return null;
      final origin = uri.origin;
      if (origin.isEmpty) return null;

      final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
      if (segments.isEmpty) return null;

      final channelId = segments.last;
      if (channelId.isEmpty) return null;

      return CuratedChannelRef(
        baseUrl: origin,
        channelId: channelId,
        publisherId: publisherId,
      );
    } on FormatException {
      return null;
    }
  }

  /// Parses and deduplicates channels from publisher-aware remote config.
  static List<CuratedChannelRef> parseAll(
    Iterable<RemoteConfigPublisher> publishers,
  ) {
    final refs = <CuratedChannelRef>[];
    for (final publisher in publishers) {
      final publisherId = publisher.id;
      for (final channelUrl in publisher.channelUrls) {
        final parsed = tryParse(
          channelUrl,
          publisherId: publisherId,
        );
        if (parsed != null) {
          refs.add(parsed);
        }
      }
    }
    // Deduplicate by (baseUrl, channelId, publisherId).
    final unique = <String, CuratedChannelRef>{};
    for (final ref in refs) {
      unique['${ref.baseUrl}::${ref.channelId}::${ref.publisherId}'] = ref;
    }
    return unique.values.toList();
  }
}

/// Immutable state for feed registry orchestration.
@immutable
class FeedRegistryState {
  /// Creates a [FeedRegistryState].
  const FeedRegistryState({
    required this.curatedChannels,
  });

  /// Curated DP-1 channel refs derived from curated channel URLs.
  final List<CuratedChannelRef> curatedChannels;
}

/// Bootstrap/reload summary for feed orchestration.
@immutable
class FeedBootstrapResult {
  /// Creates a [FeedBootstrapResult].
  const FeedBootstrapResult({
    required this.channelsFetched,
    required this.playlistsFetched,
    required this.feedServersTouched,
  });

  /// Curated channels fetched (best-effort; partial success is allowed).
  final int channelsFetched;

  /// Total playlists fetched across touched feed servers.
  final int playlistsFetched;

  /// Number of distinct feed servers touched.
  final int feedServersTouched;
}

/// Provider for [FeralFileFeedManager].
///
/// Holds the single feed manager instance; all setup/reload/cache APIs
/// delegate to it. Matches old repo's FeralFileFeedManager singleton.
final feedManagerProvider = Provider<FeralFileFeedManager>((ref) {
  return FeralFileFeedManager(
    databaseService: ref.read(databaseServiceProvider),
    appStateService: ref.read(appStateServiceProvider),
    defaultDp1FeedUrl: AppConfig.dp1FeedUrl,
    indexerService: ref.read(indexerServiceProvider),
    enrichmentScheduler: ref.read(indexerEnrichmentSchedulerServiceProvider),
    apiKey: AppConfig.dp1FeedApiKey,
    onChannelPersistedInDatabase: () async {
      await ref
          .read(tokensSyncCoordinatorProvider.notifier)
          .notifyChannelIngested();
    },
  );
});

/// Riverpod flow-driver for feed orchestration.
///
/// Delegates all operations to [FeralFileFeedManager] via [feedManagerProvider]:
/// - setupRemoteConfigChannels() and reloadAllCache() call into the manager
/// - State is derived from curated channel URLs for reactivity
class FeedRegistryNotifier extends AsyncNotifier<FeedRegistryState> {
  late final Logger _log;

  @override
  Future<FeedRegistryState> build() async {
    _log = Logger('FeedRegistryNotifier');

    final publishers = ref.watch(remoteConfigPublishersProvider);
    final curated = CuratedChannelRef.parseAll(publishers);

    return FeedRegistryState(
      curatedChannels: curated,
    );
  }

  /// Setup remote config channels from curated URLs.
  ///
  /// Delegates to [FeralFileFeedManager.setupRemoteConfigChannels] (matches
  /// old repo: parse → group by endpoint → add/update services + custom feeds).
  Future<void> setupRemoteConfigChannels(
    List<RemoteConfigPublisher> publishers,
  ) async {
    final channelCount = publishers.fold<int>(
      0,
      (count, publisher) => count + publisher.channelUrls.length,
    );
    _log.info('Setting up remote config channels: $channelCount URLs');
    final manager = ref.read(feedManagerProvider);
    await manager.setupRemoteConfigChannels(publishers);
    await manager.reloadAllCache(force: false);
    _log.info('Setup complete');
  }

  /// Reload cache for all feed services.
  ///
  /// Delegates to [FeralFileFeedManager.reloadAllCache].
  Future<void> reloadAllCache({bool force = false}) async {
    final manager = ref.read(feedManagerProvider);
    if (manager.feedServices.isEmpty) {
      _log.warning(
        'No feed services initialized, call setupRemoteConfigChannels first',
      );
      return;
    }
    _log.info('Reloading all caches, force=$force');
    await manager.reloadAllCache(force: force);
    _log.info('Cache reload complete');
  }

  /// Reloads state.
  Future<void> refreshFromStorage() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(build);
  }
}

/// Provider for [FeedRegistryNotifier].
///
/// UI should treat this as the single source of truth for feed orchestration.
final feedRegistryProvider =
    AsyncNotifierProvider<FeedRegistryNotifier, FeedRegistryState>(
      FeedRegistryNotifier.new,
    );
