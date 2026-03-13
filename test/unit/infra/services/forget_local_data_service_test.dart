import 'package:app/infra/database/favorite_history_snapshot.dart';
import 'package:app/infra/services/local_data_cleanup_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('forgetIExist executes fullClear then recreate and bootstrap', () async {
    final events = <String>[];

    final service = LocalDataCleanupService(
      stopWorkersGracefully: () async {
        events.add('stop-workers');
      },
      closeAndDeleteDatabase: () async {
        events.add('close-delete-db');
      },
      clearObjectBoxData: () async {
        events.add('clear-objectbox');
      },
      clearObjectBoxLight: () async {
        events.add('clear-objectbox-light');
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
      onDatabaseReady: () async {
        events.add('on-database-ready');
      },
      postDrainSettleDuration: Duration.zero,
    );

    await service.forgetIExist();

    expect(events, <String>[
      'pause-feed',
      'pause-token-polling',
      'stop-workers',
      'close-delete-db',
      'clear-objectbox-light',
      'clear-cached-images',
      'clear-objectbox',
      'clear-legacy-sqlite',
      'clear-legacy-hive',
      'close-delete-db',
      'recreate-db-from-seed',
      'run-bootstrap',
      'on-database-ready',
    ]);
  });

  test('forgetIExist runs onDatabaseReady after seed and bootstrap', () async {
    final events = <String>[];

    final service = LocalDataCleanupService(
      stopWorkersGracefully: () async {
        events.add('stop-workers');
      },
      closeAndDeleteDatabase: () async {
        events.add('close-delete-db');
      },
      clearObjectBoxData: () async {
        events.add('clear-objectbox');
      },
      clearObjectBoxLight: () async {
        events.add('clear-objectbox-light');
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
      onDatabaseReady: () async {
        events.add('on-database-ready');
      },
      clearLegacySqlite: () async {},
      clearLegacyHive: () async {},
      postDrainSettleDuration: Duration.zero,
    );

    await service.forgetIExist();

    expect(events.last, equals('on-database-ready'));
  });

  test(
    'rebuildMetadata uses lightClear, runs onDatabaseReady, restores favorites',
    () async {
      final events = <String>[];

      final service = LocalDataCleanupService(
        stopWorkersGracefully: () async {
          events.add('stop-workers');
        },
        closeAndDeleteDatabase: () async {
          events.add('close-delete-db');
        },
        clearObjectBoxData: () async {
          events.add('clear-objectbox');
        },
        clearObjectBoxLight: () async {
          events.add('clear-objectbox-light');
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
        onDatabaseReady: () async {
          events.add('on-database-ready');
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

      expect(events, <String>[
        'get-favorite-playlists-snapshot',
        'pause-feed',
        'pause-token-polling',
        'stop-workers',
        'close-delete-db',
        'clear-objectbox-light',
        'clear-cached-images',
        'recreate-db-from-seed',
        'run-bootstrap',
        'on-database-ready',
      ]);
      expect(events.where((event) => event == 'clear-objectbox'), isEmpty);
    },
  );
}
