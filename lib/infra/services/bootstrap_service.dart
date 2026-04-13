import 'package:app/domain/models/channel.dart';
import 'package:app/domain/models/playlist.dart';
import 'package:app/infra/database/database_service.dart';
import 'package:logging/logging.dart';

/// Service for bootstrapping the application data.
/// Creates initial channels and structures.
class BootstrapService {
  /// Creates a BootstrapService.
  BootstrapService({
    required DatabaseService databaseService,
  }) : _databaseService = databaseService {
    _log = Logger('BootstrapService');
  }

  final DatabaseService _databaseService;
  late final Logger _log;

  /// Bootstrap the application.
  /// This creates the "My Collection" virtual channel and Favorite playlist
  /// if they don't exist.
  Future<void> bootstrap() async {
    try {
      _log.info('Starting bootstrap');

      await _createMyCollectionChannel();
      await _ensureFavoritePlaylists();

      _log.info('Bootstrap completed');
    } catch (e, stack) {
      _log.severe('Bootstrap failed', e, stack);
      rethrow;
    }
  }

  /// Create "My Collection" virtual channel.
  Future<void> _createMyCollectionChannel() async {
    final existingChannel = await _databaseService.getChannelById(
      Channel.myCollectionId,
    );

    if (existingChannel != null) {
      _log.info('My Collection channel already exists');
      return;
    }

    final myCollection = Channel(
      id: Channel.myCollectionId,
      name: 'My Collection',
      type: ChannelType.localVirtual,
      description: 'Your personal collection of artworks',
      isPinned: true,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      sortOrder: 0, // First in the list
    );

    await _databaseService.ingestChannel(myCollection);
    _log.info('Created My Collection channel');
  }

  /// Ensure Favorite playlist exists.
  /// Every user has this Favorite playlist.
  Future<void> _ensureFavoritePlaylists() async {
    final existingFavorite = await _databaseService.getPlaylistById(
      Playlist.favoriteId,
    );

    if (_isCanonicalFavoritePlaylist(existingFavorite)) {
      _log.info('Favorite playlist already exists');
      return;
    }

    final now = DateTime.now();
    await _databaseService.ingestPlaylist(
      Playlist.favorite(
        createdAt: now,
        updatedAt: now,
      ),
    );
    await _databaseService.refreshPlaylistItemCount(Playlist.favoriteId);
    _log.info('Created Favorite playlist');
  }

  bool _isCanonicalFavoritePlaylist(Playlist? playlist) {
    return playlist != null &&
        playlist.id == Playlist.favoriteId &&
        playlist.name == 'Favorites' &&
        playlist.type == PlaylistType.favorite &&
        playlist.channelId == Channel.myCollectionId &&
        playlist.sortMode == PlaylistSortMode.provenance;
  }
}
