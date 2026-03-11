import 'package:app/app/providers/services_provider.dart';
import 'package:app/domain/models/channel.dart';
import 'package:app/domain/models/playlist.dart';
import 'package:app/infra/database/database_provider.dart';
import 'package:riverpod/src/providers/stream_provider.dart';
import 'package:rxdart/rxdart.dart';

/// State for Me section playlists (Favorite, address-based).
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
/// Combines Favorite and address-based playlists in order:
/// Favorite → address playlists (by created_at).
final meSectionPlaylistsProvider = StreamProvider<MeSectionPlaylistsState>((
  ref,
) {
  final databaseService = ref.read(databaseServiceProvider);

  return Rx.combineLatest2<Playlist?, List<Playlist>, MeSectionPlaylistsState>(
    databaseService.watchPlaylistById(Playlist.favoriteId),
    databaseService.watchPlaylists(
      type: PlaylistType.addressBased,
      channelId: Channel.myCollectionId,
    ),
    (favorite, addressPlaylists) {
      final systemPlaylists = [favorite]
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
final StreamProviderFamily<bool, String> isWorkInFavoriteProvider = StreamProvider.family<bool, String>((
  ref,
  workId,
) {
  final favoriteService = ref.watch(favoritePlaylistServiceProvider);
  return favoriteService.watchIsWorkInFavorite(workId);
});
