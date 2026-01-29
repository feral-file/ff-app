import 'package:app/app/feed/curated_channel_urls.dart';
import 'package:app/app/providers/services_provider.dart';
import 'package:app/infra/storage/feed_server_prefs_store.dart';
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
    required this.customFeedServerBaseUrls,
  });

  /// Curated DP-1 channel refs derived from curated channel URLs.
  final List<CuratedChannelRef> curatedChannels;

  /// Custom feed server baseUrls persisted by the user.
  final List<String> customFeedServerBaseUrls;

  /// Returns a new [FeedRegistryState] with optional overrides.
  FeedRegistryState copyWith({
    List<CuratedChannelRef>? curatedChannels,
    List<String>? customFeedServerBaseUrls,
  }) {
    return FeedRegistryState(
      curatedChannels: curatedChannels ?? this.curatedChannels,
      customFeedServerBaseUrls:
          customFeedServerBaseUrls ?? this.customFeedServerBaseUrls,
    );
  }
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
/// - curated channel URL parsing
/// - persistence for custom feed servers (via [FeedServerPrefsStore])
/// - bootstrap/reload intents that call into infra services
class FeedRegistryNotifier extends AsyncNotifier<FeedRegistryState> {
  late final Logger _log;

  @override
  Future<FeedRegistryState> build() async {
    _log = Logger('FeedRegistryNotifier');

    final curatedUrls = ref.watch(curatedDp1ChannelUrlsProvider);
    final curated = CuratedChannelRef.parseAll(curatedUrls);

    final prefs = ref.watch(feedServerPrefsStoreProvider);
    final custom = await prefs.readCustomBaseUrls();

    return FeedRegistryState(
      curatedChannels: curated,
      customFeedServerBaseUrls: custom,
    );
  }

  /// Reloads state from storage.
  Future<void> refreshFromStorage() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(build);
  }

  /// Adds a custom feed server baseUrl (normalized to origin).
  Future<void> addCustomServer(String baseUrl) async {
    final trimmed = baseUrl.trim();
    final normalized = _tryNormalizeOrigin(trimmed);
    if (normalized == null) {
      throw ArgumentError.value(baseUrl, 'baseUrl', 'Invalid feed server URL');
    }

    final prefs = ref.read(feedServerPrefsStoreProvider);
    await prefs.addCustomBaseUrl(normalized);

    final current = await future;
    final updated = <String>{...current.customFeedServerBaseUrls, normalized}
        .toList()
      ..sort();
    state = AsyncData(
      current.copyWith(customFeedServerBaseUrls: updated),
    );
  }

  /// Removes a custom feed server baseUrl.
  Future<void> removeCustomServer(String baseUrl) async {
    final trimmed = baseUrl.trim();
    final normalized = _tryNormalizeOrigin(trimmed) ?? trimmed;

    final prefs = ref.read(feedServerPrefsStoreProvider);
    await prefs.removeCustomBaseUrl(normalized);

    final current = await future;
    final updated = current.customFeedServerBaseUrls
        .where((e) => e != normalized)
        .toList()
      ..sort();
    state = AsyncData(
      current.copyWith(customFeedServerBaseUrls: updated),
    );
  }

  /// Bootstrap curated channels and custom feed servers.
  ///
  /// This is an orchestration helper: it triggers network fetch+ingest, but
  /// never reads DB results directly.
  Future<FeedBootstrapResult> bootstrap({
    Set<String> skipPlaylistsBaseUrls = const <String>{},
  }) async {
    final current = await future;
    final dp1FeedService = ref.read(dp1FeedServiceProvider);

    final skip = skipPlaylistsBaseUrls.map((e) => _tryNormalizeOrigin(e) ?? e);

    // 1) Curated channels: fetch channel details per (baseUrl, channelId).
    var channelsFetched = 0;
    for (final curated in current.curatedChannels) {
      try {
        await dp1FeedService.fetchChannel(
          baseUrl: curated.baseUrl,
          channelId: curated.channelId,
        );
        channelsFetched++;
      } on Exception catch (e) {
        _log.warning(
          'Failed to fetch curated channel ${curated.channelId} '
          'from ${curated.baseUrl}: $e',
        );
      }
    }

    // 2) Playlists: fetch playlists for each feed server baseUrl
    // (custom + curated).
    final baseUrls = <String>{
      ...current.customFeedServerBaseUrls,
      ...current.curatedChannels.map((c) => c.baseUrl),
    }.toList()
      ..sort();

    var playlistsFetched = 0;
    for (final baseUrl in baseUrls) {
      if (skip.contains(baseUrl)) {
        _log.info('Skipping playlist fetch for baseUrl=$baseUrl');
        continue;
      }
      try {
        final count = await dp1FeedService.fetchPlaylists(
          baseUrl: baseUrl,
          limit: 100,
        );
        playlistsFetched += count;
      } on Exception catch (e) {
        _log.warning('Failed to fetch playlists from $baseUrl: $e');
      }
    }

    return FeedBootstrapResult(
      channelsFetched: channelsFetched,
      playlistsFetched: playlistsFetched,
      feedServersTouched: baseUrls.length,
    );
  }

  /// Reloads all curated/custom feeds.
  ///
  /// Cache policy is intentionally deferred; for now reload == bootstrap.
  Future<FeedBootstrapResult> reloadAll({
    bool force = false,
    Set<String> skipPlaylistsBaseUrls = const <String>{},
  }) async {
    // Cache policy is intentionally deferred; for now, reload is equivalent
    // to bootstrap.
    // ignore: avoid_unused_parameters
    return bootstrap(skipPlaylistsBaseUrls: skipPlaylistsBaseUrls);
  }

  String? _tryNormalizeOrigin(String raw) {
    try {
      final uri = Uri.parse(raw);
      if (!uri.hasScheme || uri.host.isEmpty) return null;
      return uri.origin;
    } on FormatException {
      return null;
    }
  }
}

/// Provider for [FeedRegistryNotifier].
///
/// UI should treat this as the single source of truth for feed orchestration.
final feedRegistryProvider =
    AsyncNotifierProvider<FeedRegistryNotifier, FeedRegistryState>(
  FeedRegistryNotifier.new,
);
