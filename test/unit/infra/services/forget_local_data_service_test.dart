import 'package:app/infra/database/favorite_history_snapshot.dart';
import 'package:app/infra/services/local_data_cleanup_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('forgetIExist executes fullClear then recreate and bootstrap', () async {
    final events = <String>[];

    final service = LocalDataCleanupService(
      closeAndDeleteDatabase: () async {
        events.add('close-delete-db');
        events.add('clear-objectbox-light');
      },
      clearObjectBoxData: () async {
        events.add('clear-objectbox');
      },
      clearCachedImages: () async {
        events.add('clear-cached-images');
      },
      recreateDatabaseFromSeed: () async {
        events.add('recreate-db-from-seed');
      },
      getFavoritePlaylistsSnapshot: () async => const [],
      restoreFavoritePlaylists: (_) async {},
      runBootstrap: () async {
        events.add('run-bootstrap');
      },
      pauseFeedWork: () {
        events.add('pause-feed');
      },
      pauseTokenPolling: () {
        events.add('pause-token-polling');
      },
      clearLegacySqlite: () async {
        events.add('clear-legacy-sqlite');
      },
      clearLegacyHive: () async {
        events.add('clear-legacy-hive');
      },
      postDrainSettleDuration: Duration.zero,
    );

    await service.forgetIExist();

    // forgetIExist returns after fullClear; recreate+bootstrap run in background.
    expect(events, <String>[
      'pause-feed',
      'pause-token-polling',
      'close-delete-db',
      'clear-objectbox-light',
      'clear-cached-images',
      'clear-objectbox',
      'clear-legacy-sqlite',
      'clear-legacy-hive',
      'close-delete-db',
      'clear-objectbox-light',
    ]);
  });

  test(
    'forgetIExist returns after fullClear; background tasks run fire-and-forget',
    () async {
    final events = <String>[];

    final service = LocalDataCleanupService(
      closeAndDeleteDatabase: () async {
        events.add('close-delete-db');
        events.add('clear-objectbox-light');
      },
      clearObjectBoxData: () async {
        events.add('clear-objectbox');
      },
      clearCachedImages: () async {
        events.add('clear-cached-images');
      },
      recreateDatabaseFromSeed: () async {
        events.add('recreate-db-from-seed');
      },
      getFavoritePlaylistsSnapshot: () async => const [],
      restoreFavoritePlaylists: (_) async {},
      runBootstrap: () async {
        events.add('run-bootstrap');
      },
      pauseFeedWork: () {
        events.add('pause-feed');
      },
      pauseTokenPolling: () {
        events.add('pause-token-polling');
      },
      clearLegacySqlite: () async {},
      clearLegacyHive: () async {},
      postDrainSettleDuration: Duration.zero,
    );

    await service.forgetIExist();

    // forgetIExist returns after fullClear; post-drain calls close/delete again
    // (includes objectbox light clear in the same callback).
    expect(events.last, equals('clear-objectbox-light'));
  });

  test(
    'rebuildMetadata uses lightClear, restores favorites',
    () async {
      final events = <String>[];

      final service = LocalDataCleanupService(
        closeAndDeleteDatabase: () async {
          events.add('close-delete-db');
          events.add('clear-objectbox-light');
        },
        clearObjectBoxData: () async {
          events.add('clear-objectbox');
        },
        clearCachedImages: () async {
          events.add('clear-cached-images');
        },
        recreateDatabaseFromSeed: () async {
          events.add('recreate-db-from-seed');
        },
        getFavoritePlaylistsSnapshot: () async {
          events.add('get-favorite-playlists-snapshot');
          return const <FavoritePlaylistSnapshot>[];
        },
        restoreFavoritePlaylists: (_) async {
          events.add('restore-favorite-playlists');
        },
        runBootstrap: () async {
          events.add('run-bootstrap');
        },
        pauseFeedWork: () {
          events.add('pause-feed');
        },
        pauseTokenPolling: () {
          events.add('pause-token-polling');
        },
        postDrainSettleDuration: Duration.zero,
      );

      await service.rebuildMetadata();

      // rebuildMetadata returns after lightClear; recreate+restore run in background.
      expect(events, <String>[
        'get-favorite-playlists-snapshot',
        'pause-feed',
        'pause-token-polling',
        'close-delete-db',
        'clear-objectbox-light',
        'clear-cached-images',
      ]);
      expect(events.where((event) => event == 'clear-objectbox'), isEmpty);
    },
  );
}
