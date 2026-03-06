import 'package:app/app/providers/channel_preview_provider.dart';
import 'package:app/domain/models/channel.dart';
import 'package:app/domain/models/playlist.dart';
import 'package:app/domain/models/playlist_item.dart';
import 'package:app/infra/database/app_database.dart';
import 'package:app/infra/database/database_provider.dart';
import 'package:app/infra/database/database_service.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Unit tests for channel preview provider (family by channelId).
void main() {
  group('ChannelPreviewProvider (family by channelId)', () {
    test('returns initial state with empty works', () {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final dbService = DatabaseService(db);

      final container = ProviderContainer.test(
        overrides: [
          databaseServiceProvider.overrideWith((ref) => dbService),
        ],
      );
      addTearDown(container.dispose);

      final state = container.read(channelPreviewProvider('ch_1'));

      expect(state.works, isEmpty);
      expect(state.hasMore, isTrue);
      expect(state.isLoading, isFalse);
      expect(state.isLoadingMore, isFalse);
      expect(state.error, isNull);
    });

    test('load() with no playlists completes with empty works', () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final dbService = DatabaseService(db);

      await dbService.ingestChannel(
        Channel(
          id: 'ch_1',
          name: 'Test Channel',
          type: ChannelType.dp1,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );

      final container = ProviderContainer.test(
        overrides: [
          databaseServiceProvider.overrideWith((ref) => dbService),
        ],
      );
      addTearDown(container.dispose);

      await container.read(channelPreviewProvider('ch_1').notifier).load();

      final state = container.read(channelPreviewProvider('ch_1'));
      expect(state.works, isEmpty);
      expect(state.isLoading, isFalse);
      expect(state.hasMore, isFalse);
      expect(state.error, isNull);
    });

    test('watch updates to empty list when no playlists exist', () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final dbService = DatabaseService(db);

      await dbService.ingestChannel(
        Channel(
          id: 'ch_1',
          name: 'Test Channel',
          type: ChannelType.dp1,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );

      final container = ProviderContainer.test(
        overrides: [
          databaseServiceProvider.overrideWith((ref) => dbService),
        ],
      );
      addTearDown(container.dispose);

      // Keep the provider alive to receive the watch stream emissions.
      final listener = container.listen(
        channelPreviewProvider('ch_1'),
        (_, __) {},
      );
      addTearDown(listener.close);

      await Future<void>.delayed(const Duration(milliseconds: 450));

      final state = container.read(channelPreviewProvider('ch_1'));
      expect(state.works, isEmpty);
      expect(state.hasMore, isFalse);
      expect(state.isLoading, isFalse);
      expect(state.error, isNull);
    });

    test(
      'load() with playlist and items returns first page of works',
      () async {
        final db = AppDatabase.forTesting(NativeDatabase.memory());
        addTearDown(db.close);
        final dbService = DatabaseService(db);

        await dbService.ingestChannel(
          Channel(
            id: 'ch_1',
            name: 'Test Channel',
            type: ChannelType.dp1,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        );

        await dbService.ingestPlaylist(
          Playlist(
            id: 'pl_1',
            name: 'Test Playlist',
            type: PlaylistType.dp1,
            channelId: 'ch_1',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        );

        final items = [
          PlaylistItem(
            id: 'item_1',
            kind: PlaylistItemKind.indexerToken,
            title: 'Item 1',
            updatedAt: DateTime.now(),
          ),
          PlaylistItem(
            id: 'item_2',
            kind: PlaylistItemKind.indexerToken,
            title: 'Item 2',
            updatedAt: DateTime.now(),
          ),
        ];
        await dbService.ingestPlaylistItems(items);

        final nowUs = BigInt.from(DateTime.now().microsecondsSinceEpoch);
        await db.upsertPlaylistEntries([
          PlaylistEntriesCompanion.insert(
            playlistId: 'pl_1',
            itemId: 'item_1',
            position: const Value(0),
            sortKeyUs: BigInt.zero,
            updatedAtUs: nowUs,
          ),
          PlaylistEntriesCompanion.insert(
            playlistId: 'pl_1',
            itemId: 'item_2',
            position: const Value(1),
            sortKeyUs: BigInt.zero,
            updatedAtUs: nowUs,
          ),
        ]);
        await db.updatePlaylistItemCount('pl_1');

        final container = ProviderContainer.test(
          overrides: [
            databaseServiceProvider.overrideWith((ref) => dbService),
          ],
        );
        addTearDown(container.dispose);

        await container.read(channelPreviewProvider('ch_1').notifier).load();

        final state = container.read(channelPreviewProvider('ch_1'));
        expect(state.works.length, 2);
        expect(state.works[0].id, 'item_1');
        expect(state.works[1].id, 'item_2');
        expect(state.isLoading, isFalse);
        expect(state.hasMore, isFalse);
        expect(state.error, isNull);
      },
    );

    test('loadMore() appends next page of works', () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final dbService = DatabaseService(db);

      await dbService.ingestChannel(
        Channel(
          id: 'ch_1',
          name: 'Test Channel',
          type: ChannelType.dp1,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );

      await dbService.ingestPlaylist(
        Playlist(
          id: 'pl_1',
          name: 'Test Playlist',
          type: PlaylistType.dp1,
          channelId: 'ch_1',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );

      const itemCount = 15;
      final items = List.generate(
        itemCount,
        (i) => PlaylistItem(
          id: 'item_$i',
          kind: PlaylistItemKind.indexerToken,
          title: 'Item $i',
          updatedAt: DateTime.now(),
        ),
      );
      await dbService.ingestPlaylistItems(items);

      final nowUs = BigInt.from(DateTime.now().microsecondsSinceEpoch);
      final entries = List.generate(
        itemCount,
        (i) => PlaylistEntriesCompanion.insert(
          playlistId: 'pl_1',
          itemId: 'item_$i',
          position: Value(i),
          sortKeyUs: BigInt.zero,
          updatedAtUs: nowUs,
        ),
      );
      await db.upsertPlaylistEntries(entries);
      await db.updatePlaylistItemCount('pl_1');

      final container = ProviderContainer.test(
        overrides: [
          databaseServiceProvider.overrideWith((ref) => dbService),
        ],
      );
      addTearDown(container.dispose);

      await container.read(channelPreviewProvider('ch_1').notifier).load();

      var state = container.read(channelPreviewProvider('ch_1'));
      expect(state.works.length, 10);
      expect(state.hasMore, isTrue);

      await container.read(channelPreviewProvider('ch_1').notifier).loadMore();

      state = container.read(channelPreviewProvider('ch_1'));
      expect(state.works.length, 15);
      expect(state.hasMore, isFalse);
      expect(state.isLoadingMore, isFalse);
    });
  });
}
