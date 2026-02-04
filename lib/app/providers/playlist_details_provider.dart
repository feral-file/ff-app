import 'package:app/infra/database/app_database.dart';
import 'package:app/infra/database/database_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';

/// View model for playlist details (UI uses only Drift models).
class PlaylistDetails {
  const PlaylistDetails({
    required this.playlist,
    required this.items,
  });

  /// Playlist being viewed (Drift).
  final PlaylistData? playlist;

  /// Works in the playlist (Drift).
  final List<ItemData> items;
}

/// Provider for playlist details state.
final playlistDetailsProvider =
    FutureProvider.family<PlaylistDetails, String>((ref, playlistId) async {
  final log = Logger('playlistDetailsProvider');

  try {
    final databaseService = ref.read(databaseServiceProvider);
    final playlist = await databaseService.getPlaylistByIdData(playlistId);
    final items = await databaseService.getPlaylistItemsData(playlistId);
    return PlaylistDetails(playlist: playlist, items: items);
  } catch (e, stack) {
    log.severe('Failed to load playlist details for $playlistId', e, stack);
    rethrow;
  }
});

