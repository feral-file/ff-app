import 'package:app/domain/models/playlist.dart';
import 'package:app/domain/models/playlist_item.dart';
import 'package:app/infra/database/app_database.dart';
import 'package:app/infra/database/database_service.dart';
import 'package:app/infra/services/favorite_playlist_service.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FavoritePlaylistService', () {
    late AppDatabase db;
    late DatabaseService dbService;
    late FavoritePlaylistService favoriteService;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      dbService = DatabaseService(db);
      favoriteService = FavoritePlaylistService(databaseService: dbService);
    });

    tearDown(() async {
      await db.close();
    });

    test('addWorkToFavorite skips ingest when item already exists', () async {
      await dbService.ingestPlaylist(Playlist.favorite());

      final originalItem = PlaylistItem(
        id: 'wk_existing',
        kind: PlaylistItemKind.indexerToken,
        title: 'Original Title',
        updatedAt: DateTime.now(),
      );
      await dbService.ingestPlaylistItem(originalItem);

      final itemWithDifferentContent = PlaylistItem(
        id: 'wk_existing',
        kind: PlaylistItemKind.indexerToken,
        title: 'Updated Title',
        updatedAt: DateTime.now(),
      );
      await favoriteService.addWorkToFavorite(itemWithDifferentContent);

      final retrieved = await dbService.getPlaylistItemById('wk_existing');
      expect(retrieved, isNotNull);
      expect(retrieved!.title, 'Original Title');

      final favoriteItems =
          await dbService.getPlaylistItems(Playlist.favoriteId);
      expect(favoriteItems.map((i) => i.id), contains('wk_existing'));
    });

    test('addWorkToFavorite ingests when item does not exist', () async {
      await dbService.ingestPlaylist(Playlist.favorite());

      final newItem = PlaylistItem(
        id: 'wk_new',
        kind: PlaylistItemKind.indexerToken,
        title: 'New Work',
        updatedAt: DateTime.now(),
      );
      await favoriteService.addWorkToFavorite(newItem);

      final retrieved = await dbService.getPlaylistItemById('wk_new');
      expect(retrieved, isNotNull);
      expect(retrieved!.title, 'New Work');

      final favoriteItems =
          await dbService.getPlaylistItems(Playlist.favoriteId);
      expect(favoriteItems.map((i) => i.id), contains('wk_new'));
    });
  });
}
