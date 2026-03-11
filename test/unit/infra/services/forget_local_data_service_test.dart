import 'package:app/infra/database/favorite_history_snapshot.dart';
import 'package:app/infra/services/local_data_cleanup_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('clearLocalData executes stop and cleanup sequence in order', () async {
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
      clearPendingAddresses: () async {
        events.add('clear-pending-addresses');
      },
      clearCachedImages: () async {
        events.add('clear-cached-images');
      },
      getPersonalAddresses: () async => const <String>[],
      restorePersonalAddressPlaylists: (_) async {},
      refetchFromBeginning: (_) async {},
      recreateDatabaseFromSeed: () async {
        events.add('recreate-db-from-seed');
      },
      getFavoritePlaylistsSnapshot: () async => const [],
      restoreFavoritePlaylists: (_) async {},
      runBootstrap: () async {},
      pauseFeedWork: () {
        events.add('pause-feed');
      },
      pauseTokenPolling: () {
        events.add('pause-token-polling');
      },
      postDrainSettleDuration: Duration.zero,
    );

    await service.clearLocalData();

    expect(events, <String>[
      'pause-feed',
      'pause-token-polling',
      'stop-workers',
      'close-delete-db',
      'clear-objectbox',
      'clear-pending-addresses',
      'clear-cached-images',
      'close-delete-db',
    ]);
  });

  test('clearLocalData runs post-reset callback after cleanup', () async {
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
      clearPendingAddresses: () async {
        events.add('clear-pending-addresses');
      },
      clearCachedImages: () async {
        events.add('clear-cached-images');
      },
      getPersonalAddresses: () async => const <String>[],
      restorePersonalAddressPlaylists: (_) async {},
      refetchFromBeginning: (_) async {},
      recreateDatabaseFromSeed: () async {
        events.add('recreate-db-from-seed');
      },
      getFavoritePlaylistsSnapshot: () async => const [],
      restoreFavoritePlaylists: (_) async {},
      runBootstrap: () async {},
      pauseFeedWork: () {
        events.add('pause-feed');
      },
      pauseTokenPolling: () {
        events.add('pause-token-polling');
      },
      onResetCompleted: () async {
        events.add('on-reset-completed');
      },
      postDrainSettleDuration: Duration.zero,
    );

    await service.clearLocalData();

    expect(events.last, equals('on-reset-completed'));
  });

  test(
    'rebuildMetadata clears sqlite and refetches while keeping addresses',
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
        clearPendingAddresses: () async {
          events.add('clear-pending-addresses');
        },
        clearCachedImages: () async {
          events.add('clear-cached-images');
        },
        getPersonalAddresses: () async {
          events.add('get-addresses');
          return <String>['0xabc'];
        },
        restorePersonalAddressPlaylists: (addresses) async {
          events.add('restore:${addresses.join(",")}');
        },
        refetchFromBeginning: (addresses) async {
          events.add('refetch:${addresses.join(",")}');
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

      expect(events, <String>[
        'pause-feed',
        'pause-token-polling',
        'stop-workers',
        'get-addresses',
        'get-favorite-playlists-snapshot',
        'recreate-db-from-seed',
        'run-bootstrap',
        'restore:0xabc',
        'clear-cached-images',
        'refetch:0xabc',
      ]);
      expect(events.where((event) => event == 'clear-objectbox'), isEmpty);
    },
  );
}
