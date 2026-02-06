import 'package:app/app/feed/curated_channel_urls.dart';
import 'package:app/app/feed/feed_manager.dart';
import 'package:app/app/providers/services_provider.dart';
import 'package:app/infra/config/app_config.dart';
import 'package:app/infra/config/feed_config_store.dart';
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
  });

  /// Feed server origin, e.g. `https://example.org`.
  final String baseUrl;

  /// DP-1 channel ID, e.g. `ch_...`.
  final String channelId;

  /// Best-effort parser for curated DP-1 channel URLs.
  ///
  /// Expected shape:
  /// `https://example.org/api/v1/channels/ch_...`
  static CuratedChannelRef? tryParse(String raw) {
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
      );
    } on FormatException {
      return null;
    }
  }

  /// Parses and deduplicates a list of curated channel URLs.
  static List<CuratedChannelRef> parseAll(Iterable<String> urls) {
    final refs = urls.map(tryParse).whereType<CuratedChannelRef>().toList();
    // Deduplicate by (baseUrl, channelId).
    final unique = <String, CuratedChannelRef>{};
    for (final ref in refs) {
      unique['${ref.baseUrl}::${ref.channelId}'] = ref;
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
    feedConfigStore: ref.read(feedConfigStoreProvider),
    defaultDp1FeedUrl: AppConfig.dp1FeedUrl,
    indexerService: ref.read(indexerServiceProvider),
    apiKey: AppConfig.dp1FeedApiKey,
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

    final curatedUrls = ref.watch(curatedDp1ChannelUrlsProvider);
    final curated = CuratedChannelRef.parseAll(curatedUrls);

    return FeedRegistryState(
      curatedChannels: curated,
    );
  }

  /// Setup remote config channels from curated URLs.
  ///
  /// Delegates to [FeralFileFeedManager.setupRemoteConfigChannels] (matches
  /// old repo: parse → group by endpoint → add/update services + custom feeds).
  Future<void> setupRemoteConfigChannels(List<String> channelUrls) async {
    _log.info('Setting up remote config channels: ${channelUrls.length} URLs');
    final manager = ref.read(feedManagerProvider);
    await manager.setupRemoteConfigChannels(channelUrls);
    await manager.reloadAllCache(force: true);
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
