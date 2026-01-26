import 'package:app/infra/database/database_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/playlist_item.dart';

/// Provider for all items in the database.
/// UI layer refers to these as "works" when displaying to users.
final allWorksProvider = FutureProvider<List<PlaylistItem>>((ref) async {
  final databaseService = ref.watch(databaseServiceProvider);
  return databaseService.getAllItems();
});

/// Provider for playlist items in a playlist.
/// UI layer can refer to these as "works" when displaying to users.
final playlistItemsProvider =
    FutureProvider.family<List<PlaylistItem>, String>((ref, playlistId) async {
  final databaseService = ref.watch(databaseServiceProvider);
  return databaseService.getPlaylistItems(playlistId);
});

/// Provider for a specific playlist item by ID.
/// UI layer can refer to this as "work" when displaying to users.
final playlistItemByIdProvider =
    FutureProvider.family<PlaylistItem?, String>((ref, itemId) async {
  final databaseService = ref.watch(databaseServiceProvider);
  return databaseService.getPlaylistItemById(itemId);
});
