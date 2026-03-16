import 'package:app/domain/extensions/playlist_ext.dart';
import 'package:app/domain/models/playlist_item.dart';
import 'package:app/infra/database/database_service.dart';
import 'package:logging/logging.dart';

/// Service for managing the Favorite playlist (user-starred works).
class FavoritePlaylistService {
  /// Creates a FavoritePlaylistService.
  FavoritePlaylistService({
    required DatabaseService databaseService,
  }) : _db = databaseService {
    _log = Logger('FavoritePlaylistService');
  }

  final DatabaseService _db;
  late final Logger _log;

  /// Add a work to the Favorite playlist.
  Future<void> addWorkToFavorite(PlaylistItem item) async {
    await _db.ingestPlaylistItem(item);
    final sortKeyUs = DateTime.now().microsecondsSinceEpoch;
    await _db.addPlaylistEntry(
      playlistId: favoritePlaylistId,
      itemId: item.id,
      sortKeyUs: sortKeyUs,
    );
    _log.info('Added work ${item.id} to Favorite');
  }

  /// Remove a work from the Favorite playlist.
  Future<void> removeWorkFromFavorite(String itemId) async {
    await _db.removePlaylistEntry(
      playlistId: favoritePlaylistId,
      itemId: itemId,
    );
    _log.info('Removed work $itemId from Favorite');
  }

  /// Toggle favorite: add if not in Favorite, remove if already in Favorite.
  Future<void> toggleFavorite(PlaylistItem item) async {
    final isIn = await _db.hasPlaylistEntry(
      playlistId: favoritePlaylistId,
      itemId: item.id,
    );
    if (isIn) {
      await removeWorkFromFavorite(item.id);
    } else {
      await addWorkToFavorite(item);
    }
  }

  /// Stream of whether the work is in Favorite.
  Stream<bool> watchIsWorkInFavorite(String itemId) {
    return _db.watchHasPlaylistEntry(
      playlistId: favoritePlaylistId,
      itemId: itemId,
    );
  }
}
