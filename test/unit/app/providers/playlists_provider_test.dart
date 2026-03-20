import 'package:app/app/providers/database_service_provider.dart';
import 'package:app/app/providers/playlists_provider.dart';
import 'package:app/domain/models/playlist.dart';
import 'package:app/infra/database/app_database.dart';
import 'package:app/infra/database/database_service.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Unit tests for playlists provider (family by PlaylistType).
void main() {
  group('PlaylistsProvider (family by PlaylistType)', () {
    test('dp1 provider returns initial state with empty playlists', () {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final dbService = DatabaseService(db);

      final container = ProviderContainer.test(
        overrides: [
          databaseServiceProvider.overrideWith((ref) => dbService),
        ],
      );
      addTearDown(container.dispose);

      final state = container.read(playlistsProvider(PlaylistType.dp1));

      expect(state.playlists, isEmpty);
      expect(state.isLoading, isFalse);
      expect(state.isLoadingMore, isFalse);
      expect(state.hasMore, isTrue);
      expect(state.cursor, isNull);
      expect(state.error, isNull);
    });

    test(
      'addressBased provider returns initial state with empty playlists',
      () {
        final db = AppDatabase.forTesting(NativeDatabase.memory());
        addTearDown(db.close);
        final dbService = DatabaseService(db);

        final container = ProviderContainer.test(
          overrides: [
            databaseServiceProvider.overrideWith((ref) => dbService),
          ],
        );
        addTearDown(container.dispose);

        final state = container.read(
          playlistsProvider(PlaylistType.addressBased),
        );

        expect(state.playlists, isEmpty);
        expect(state.isLoading, isFalse);
        expect(state.cursor, isNull);
      },
    );

    test('loadPlaylists for dp1 completes and updates state', () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final dbService = DatabaseService(db);

      final container = ProviderContainer.test(
        overrides: [
          databaseServiceProvider.overrideWith((ref) => dbService),
        ],
      );
      addTearDown(container.dispose);

      await container
          .read(playlistsProvider(PlaylistType.dp1).notifier)
          .loadPlaylists();

      final state = container.read(playlistsProvider(PlaylistType.dp1));
      expect(state.playlists, isEmpty);
      expect(state.isLoading, isFalse);
      expect(state.error, isNull);
    });

    test(
      'loadPlaylists for addressBased completes and updates state',
      () async {
        final db = AppDatabase.forTesting(NativeDatabase.memory());
        addTearDown(db.close);
        final dbService = DatabaseService(db);

        final container = ProviderContainer.test(
          overrides: [
            databaseServiceProvider.overrideWith((ref) => dbService),
          ],
        );
        addTearDown(container.dispose);

        await container
            .read(playlistsProvider(PlaylistType.addressBased).notifier)
            .loadPlaylists();

        final state = container.read(
          playlistsProvider(PlaylistType.addressBased),
        );
        expect(state.playlists, isEmpty);
        expect(state.isLoading, isFalse);
      },
    );

    test('loadPlaylists returns empty when database is unavailable', () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      final dbService = DatabaseService(db);
      await db.close();

      final container = ProviderContainer.test(
        overrides: [
          databaseServiceProvider.overrideWith((ref) => dbService),
        ],
      );
      addTearDown(container.dispose);

      await container
          .read(playlistsProvider(PlaylistType.dp1).notifier)
          .loadPlaylists();

      final state = container.read(playlistsProvider(PlaylistType.dp1));
      expect(state.playlists, isEmpty);
      expect(state.error, isNull);
      expect(state.hasMore, isFalse);
    });
  });
}
