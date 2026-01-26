import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';

import '../../domain/models/playlist.dart';
import '../../infra/database/database_provider.dart';

/// State for playlists list.
class PlaylistsState {
  /// Creates a PlaylistsState.
  const PlaylistsState({
    required this.playlists,
    required this.isLoading,
    this.error,
  });

  /// List of playlists.
  final List<Playlist> playlists;

  /// Whether playlists are being loaded.
  final bool isLoading;

  /// Error if loading failed.
  final String? error;

  /// Initial state.
  factory PlaylistsState.initial() {
    return const PlaylistsState(
      playlists: [],
      isLoading: false,
    );
  }

  /// Loading state.
  factory PlaylistsState.loading() {
    return const PlaylistsState(
      playlists: [],
      isLoading: true,
    );
  }

  /// Loaded state.
  factory PlaylistsState.loaded(List<Playlist> playlists) {
    return PlaylistsState(
      playlists: playlists,
      isLoading: false,
    );
  }

  /// Error state.
  factory PlaylistsState.error(String error) {
    return PlaylistsState(
      playlists: [],
      isLoading: false,
      error: error,
    );
  }
}

/// Provider for playlists in a channel.
final playlistsProvider =
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

/// Provider for all address playlists.
final addressPlaylistsProvider = FutureProvider<List<Playlist>>((ref) async {
  final databaseService = ref.watch(databaseServiceProvider);
  return databaseService.getAddressPlaylists();
});
