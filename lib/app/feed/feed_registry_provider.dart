import 'package:app/app/feed/curated_channel_urls.dart';
import 'package:app/app/providers/services_provider.dart';
import 'package:app/infra/config/app_config.dart';
import 'package:app/infra/config/feed_config_store.dart';
import 'package:app/infra/database/database_provider.dart';
import 'package:app/infra/services/feral_file_dp1_feed_service.dart';
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

/// Riverpod flow-driver for feed orchestration.
///
/// This replaces the legacy `FeedManager` singleton by providing:
/// - Simple 2-step API: setupRemoteConfigChannels() + reloadAllCache()
/// - Automatic composite cursor pagination for curated channels
/// - Cache policy support (TTL + remote last-updated)
class FeedRegistryNotifier extends AsyncNotifier<FeedRegistryState> {
  late final Logger _log;
  final Map<String, FeralFileDP1FeedService> _feedServices = {};

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
  /// This parses channel URLs, groups by baseUrl, and initializes
  /// FeralFileDP1FeedService instances with remote config channel IDs.
  ///
  /// Usage (matches old repo pattern):
  /// ```dart
  /// await feedRegistry.setupRemoteConfigChannels(curatedUrls);
  /// await feedRegistry.reloadAllCache();
  /// ```
  Future<void> setupRemoteConfigChannels(List<String> channelUrls) async {
    _log.info('Setting up remote config channels: ${channelUrls.length} URLs');

    // Parse and group by baseUrl
    final channelIdsByUrl = <String, List<String>>{};
    for (final url in channelUrls) {
      final parsed = CuratedChannelRef.tryParse(url);
      if (parsed == null) {
        _log.warning('Failed to parse channel URL: $url');
        continue;
      }
      channelIdsByUrl
          .putIfAbsent(parsed.baseUrl, () => [])
          .add(parsed.channelId);
    }

    _log.info('Grouped into ${channelIdsByUrl.length} feed servers');

    // Initialize or update services
    for (final entry in channelIdsByUrl.entries) {
      final baseUrl = entry.key;
      final channelIds = entry.value;

      var service = _feedServices[baseUrl];
      if (service == null) {
        _log.info('Creating new FeralFileDP1FeedService for $baseUrl');
        service = FeralFileDP1FeedService(
          baseUrl: baseUrl,
          databaseService: ref.read(databaseServiceProvider),
          indexerService: ref.read(indexerServiceProvider),
          feedConfigStore: ref.read(feedConfigStoreProvider),
          apiKey: AppConfig.dp1FeedApiKey,
        );
        _feedServices[baseUrl] = service;
      }

      service.setRemoteConfigChannelIds(channelIds);
      _log.info('Setup $baseUrl with ${channelIds.length} channels');
    }

    _log.info(
      'Setup complete: ${_feedServices.length} feed services initialized',
    );
  }

  /// Reload cache for all feed services.
  ///
  /// Respects cache policy (TTL + remote last-updated) unless force=true.
  ///
  /// This matches the old repo's FeedManager.reloadAllCache() behavior.
  Future<void> reloadAllCache({bool force = false}) async {
    _log.info(
      'Reloading all caches, force=$force, services=${_feedServices.length}',
    );

    if (_feedServices.isEmpty) {
      _log.warning(
        'No feed services initialized, '
        'call setupRemoteConfigChannels first',
      );
      return;
    }

    for (final entry in _feedServices.entries) {
      final baseUrl = entry.key;
      final service = entry.value;
      try {
        _log.info('Reloading cache for $baseUrl...');
        await service.reloadCacheIfNeeded(force: force);
        _log.info('✓ Reloaded cache for $baseUrl');
      } on Exception catch (e, stack) {
        _log.warning(
          'Failed to reload cache for $baseUrl',
          e,
          stack,
        );
      }
    }

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
