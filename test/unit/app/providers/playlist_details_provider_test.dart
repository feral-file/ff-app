import 'dart:async';

import 'package:app/app/providers/playlist_details_provider.dart';
import 'package:app/domain/models/playlist.dart';
import 'package:app/domain/models/playlist_item.dart';
import 'package:app/infra/database/app_database.dart';
import 'package:app/infra/database/database_provider.dart';
import 'package:app/infra/database/database_service.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('playlistDetailsProvider starts in loading state', () {
    // Unit test: playlist details provider initializes with AsyncLoading.
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final container = ProviderContainer.test(
      overrides: [
        databaseServiceProvider.overrideWith((ref) => DatabaseService(db)),
      ],
    );
    addTearDown(container.dispose);

    final state = container.read(playlistDetailsProvider('pl_missing'));
    expect(state, isA<AsyncLoading<PlaylistDetailsState>>());
  });

  test(
    'playlistDetailsProvider keeps metadata when playlist loads'
    ' before items stream',
    () async {
      const playlistId = 'pl_test';
      final controller = StreamController<List<PlaylistItem>>();
      addTearDown(controller.close);

      final fakeService = _FakeDatabaseService(
        playlist: const Playlist(
          id: playlistId,
          name: 'Test Playlist',
          type: PlaylistType.dp1,
        ),
        itemsStream: controller.stream,
      );
      addTearDown(fakeService.close);

      final container = ProviderContainer.test(
        overrides: [
          databaseServiceProvider.overrideWith((ref) => fakeService),
        ],
      );
      addTearDown(container.dispose);

      // Let metadata load before the first items stream emission.
      container.listen(
        playlistDetailsProvider(playlistId),
        (_, _) {},
      );
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      controller.add(
        const [
          PlaylistItem(
            id: 'it_1',
            kind: PlaylistItemKind.dp1Item,
            title: 'Item 1',
            duration: 1,
          ),
        ],
      );
      await Future<void>.delayed(const Duration(milliseconds: 20));

      final state = container.read(playlistDetailsProvider(playlistId));
      expect(state, isA<AsyncData<PlaylistDetailsState>>());
      expect(state.value?.playlist?.id, playlistId);
    },
  );
}

class _FakeDatabaseService extends DatabaseService {
  factory _FakeDatabaseService({
    required Playlist? playlist,
    required Stream<List<PlaylistItem>> itemsStream,
  }) {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    return _FakeDatabaseService._(
      db,
      playlist: playlist,
      itemsStream: itemsStream,
    );
  }

  _FakeDatabaseService._(
    this._ownedDb, {
    required this.playlist,
    required this.itemsStream,
  }) : super(_ownedDb);

  final Playlist? playlist;
  final Stream<List<PlaylistItem>> itemsStream;
  final AppDatabase _ownedDb;

  @override
  Future<Playlist?> getPlaylistById(String id) async => playlist;

  @override
  Stream<List<PlaylistItem>> watchPlaylistItems(String playlistId) =>
      itemsStream;

  @override
  Future<List<PlaylistItem>> getPlaylistItems(
    String playlistId, {
    int? limit,
    int? offset,
  }) async {
    return const <PlaylistItem>[];
  }

  @override
  Future<void> close() => _ownedDb.close();
}
