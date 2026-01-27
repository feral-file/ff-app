import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';

import '../../domain/models/playlist.dart';
import '../../infra/database/database_provider.dart';
import 'mutations.dart';

/// Enhanced state for playlists with curated vs personal separation.
class PlaylistsState {
  /// Creates a PlaylistsState.
  const PlaylistsState({
    required this.curatedPlaylists,
    required this.personalPlaylists,
    required this.isLoading,
    this.error,
  });

  /// Curated playlists from DP1 feeds.
  final List<Playlist> curatedPlaylists;

  /// Personal playlists (address-based).
  final List<Playlist> personalPlaylists;

  /// Whether playlists are being loaded.
  final bool isLoading;

  /// Error if loading failed.
  final String? error;

  /// Initial state.
  factory PlaylistsState.initial() {
    return const PlaylistsState(
      curatedPlaylists: [],
      personalPlaylists: [],
      isLoading: false,
    );
  }

  /// Loading state.
  factory PlaylistsState.loading() {
    return const PlaylistsState(
      curatedPlaylists: [],
      personalPlaylists: [],
      isLoading: true,
    );
  }

  /// Loaded state.
  factory PlaylistsState.loaded({
    required List<Playlist> curated,
    required List<Playlist> personal,
  }) {
    return PlaylistsState(
      curatedPlaylists: curated,
      personalPlaylists: personal,
      isLoading: false,
    );
  }

  /// Error state.
  factory PlaylistsState.error(String error) {
    return PlaylistsState(
      curatedPlaylists: [],
      personalPlaylists: [],
      isLoading: false,
      error: error,
    );
  }

  /// Copy with new values.
  PlaylistsState copyWith({
    List<Playlist>? curatedPlaylists,
    List<Playlist>? personalPlaylists,
    bool? isLoading,
    String? error,
  }) {
    return PlaylistsState(
      curatedPlaylists: curatedPlaylists ?? this.curatedPlaylists,
      personalPlaylists: personalPlaylists ?? this.personalPlaylists,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

/// Notifier for managing playlists state.
class PlaylistsNotifier extends Notifier<PlaylistsState> {
  late final Logger _log;

  @override
  PlaylistsState build() {
    _log = Logger('PlaylistsNotifier');
    return PlaylistsState.initial();
  }

  /// Load all playlists (curated + personal).
  Future<void> loadPlaylists() async {
    try {
      _log.info('Loading playlists from database...');
      state = PlaylistsState.loading();

      final databaseService = ref.read(databaseServiceProvider);

      // Load curated playlists from all channels
      // In a real app, we'd fetch from DP1 API
      // For now, get all playlists from database
      final allPlaylists = await databaseService.getAllPlaylists();

      _log.info('Loaded ${allPlaylists.length} total playlists from database');

      // Debug: Log first few playlists with their channelIds
      if (allPlaylists.isNotEmpty) {
        _log.info('Sample playlists:');
        for (var i = 0; i < allPlaylists.length.clamp(0, 3); i++) {
          final p = allPlaylists[i];
          _log.info('  - ${p.name} | channelId: ${p.channelId} | type: ${p.type}');
        }
      }

      // Separate curated vs personal
      // Personal playlists are address-based (have ownerAddress)
      // Curated playlists are from DP1 feeds (type == dp1)
      final curated = allPlaylists
          .where((Playlist p) => p.type == PlaylistType.dp1)
          .toList();
      final personal = await databaseService.getAddressPlaylists();

      _log.info('Curated playlists: ${curated.length}, Personal playlists: ${personal.length}');

      state = PlaylistsState.loaded(curated: curated, personal: personal);
    } catch (e, stack) {
      _log.severe('Failed to load playlists', e, stack);
      state = PlaylistsState.error(e.toString());
    }
  }

  /// Refresh playlists.
  Future<void> refresh() async {
    await loadPlaylists();
  }
}

/// Provider for playlists state.
final playlistsProvider = NotifierProvider<PlaylistsNotifier, PlaylistsState>(
  PlaylistsNotifier.new,
);

/// Mutation for loading playlists.
final loadPlaylistsMutationProvider =
    NotifierProvider<MutationNotifier<void>, MutationState<void>>(
  MutationNotifier.new,
);

/// Mutation for refreshing playlists.
final refreshPlaylistsMutationProvider =
    NotifierProvider<MutationNotifier<void>, MutationState<void>>(
  MutationNotifier.new,
);

/// Mutation for loading more playlists.
final loadMorePlaylistsMutationProvider =
    NotifierProvider<MutationNotifier<void>, MutationState<void>>(
  MutationNotifier.new,
);

/// Provider for playlists in a specific channel.
final playlistsByChannelProvider =
    FutureProvider.family<List<Playlist>, String>((ref, channelId) async {
  final databaseService = ref.watch(databaseServiceProvider);
  return databaseService.getPlaylistsByChannel(channelId);
});

/// Provider for a specific playlist by ID.
final playlistByIdProvider =
    FutureProvider.family<Playlist?, String>((ref, playlistId) async {
  final databaseService = ref.watch(databaseServiceProvider);
  return databaseService.getPlaylistById(playlistId);
});
