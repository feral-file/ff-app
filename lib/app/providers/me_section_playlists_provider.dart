import 'package:app/app/providers/services_provider.dart';
import 'package:app/domain/models/channel.dart';
import 'package:app/domain/models/playlist.dart';
import 'package:app/infra/database/database_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rxdart/rxdart.dart';

/// State for Me section playlists (Favorite, History, address-based).
class MeSectionPlaylistsState {
  const MeSectionPlaylistsState({
    required this.playlists,
    required this.isLoading,
    this.error,
  });

  final List<Playlist> playlists;
  final bool isLoading;
  final String? error;

  static const initial = MeSectionPlaylistsState(
    playlists: [],
    isLoading: true,
  );
}

/// Provider for Me section playlists.
/// Combines Favorite, History, and address-based playlists in order:
/// Favorite → History → address playlists (by created_at).
final meSectionPlaylistsProvider =
    StreamProvider<MeSectionPlaylistsState>((ref) {
  final databaseService = ref.read(databaseServiceProvider);

  return Rx.combineLatest3<Playlist?, Playlist?, List<Playlist>,
      MeSectionPlaylistsState>(
    databaseService.watchPlaylistById(Playlist.favoriteId),
    databaseService.watchPlaylistById(Playlist.historyId),
    databaseService.watchPlaylists(
      type: PlaylistType.addressBased,
      channelId: Channel.myCollectionId,
    ),
    (favorite, history, addressPlaylists) {
      final systemPlaylists = [favorite, history]
          .whereType<Playlist>()
          .where((p) => p.itemCount > 0)
          .toList();
      return MeSectionPlaylistsState(
        playlists: [...systemPlaylists, ...addressPlaylists],
        isLoading: false,
      );
    },
  );
});

/// Provider for whether a work is in the Favorite playlist.
/// Family by work ID.
final isWorkInFavoriteProvider =
    StreamProvider.family<bool, String>((ref, workId) {
  final favoriteService = ref.watch(favoritePlaylistServiceProvider);
  return favoriteService.watchIsWorkInFavorite(workId);
});
