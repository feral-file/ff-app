import 'package:app/infra/services/local_data_cleanup_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('forgetIExist executes fullClear then recreate and bootstrap', () async {
    final events = <String>[];

    final service = LocalDataCleanupService(
      closeAndDeleteDatabase: () async {
        events
          ..add('close-delete-db')
          ..add('clear-objectbox-light');
      },
      clearObjectBoxData: () async {
        events.add('clear-objectbox');
      },
      clearCachedImages: () async {
        events.add('clear-cached-images');
      },
      recreateDatabaseFromSeed: (_) async {
        events.add('recreate-db-from-seed');
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
      clearLegacySqlite: () async {
        events.add('clear-legacy-sqlite');
      },
      clearLegacyHive: () async {
        events.add('clear-legacy-hive');
      },
      postDrainSettleDuration: Duration.zero,
    );

    await service.forgetIExist();

    // forgetIExist returns after fullClear; recreate+bootstrap run in
    // background.
    // fullClear: lightClear (pause + cache), then close-delete, then rest.
    expect(events, <String>[
      'pause-feed',
      'pause-token-polling',
      'clear-cached-images',
      'close-delete-db',
      'clear-objectbox-light',
      'clear-objectbox',
      'clear-legacy-sqlite',
      'clear-legacy-hive',
      'close-delete-db',
      'clear-objectbox-light',
    ]);
  });

  test(
    'forgetIExist returns after fullClear; background tasks are '
    'fire-and-forget',
    () async {
      final events = <String>[];

      final service = LocalDataCleanupService(
        closeAndDeleteDatabase: () async {
          events
            ..add('close-delete-db')
            ..add('clear-objectbox-light');
        },
        clearObjectBoxData: () async {
          events.add('clear-objectbox');
        },
        clearCachedImages: () async {
          events.add('clear-cached-images');
        },
        recreateDatabaseFromSeed: (_) async {
          events.add('recreate-db-from-seed');
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
        clearLegacySqlite: () async {},
        clearLegacyHive: () async {},
        postDrainSettleDuration: Duration.zero,
      );

      await service.forgetIExist();

      // forgetIExist returns after fullClear; post-drain calls close/delete
      // again (includes objectbox light clear in the same callback).
      expect(events.last, equals('clear-objectbox-light'));
    },
  );

  test(
    'rebuildMetadata runs lightClear only; no close-delete until seed sync',
    () async {
      final events = <String>[];

      final service = LocalDataCleanupService(
        closeAndDeleteDatabase: () async {
          events
            ..add('close-delete-db')
            ..add('clear-objectbox-light');
        },
        clearObjectBoxData: () async {
          events.add('clear-objectbox');
        },
        clearCachedImages: () async {
          events.add('clear-cached-images');
        },
        recreateDatabaseFromSeed: (_) async {
          events.add('recreate-db-from-seed');
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
        'clear-cached-images',
      ]);
      expect(events.contains('close-delete-db'), isFalse);
      expect(events.contains('clear-objectbox'), isFalse);
    },
  );

  test(
    'rebuildMetadata skips reset recovery when retry fails before replace',
    () async {
      var resetRecoveryCalls = 0;
      var recreateCalls = 0;

      final service = LocalDataCleanupService(
        closeAndDeleteDatabase: () async {},
        clearObjectBoxData: () async {},
        clearCachedImages: () async {},
        recreateDatabaseFromSeed: (_) async {
          recreateCalls++;
          throw StateError('download failed before replace');
        },
        runBootstrap: () async {},
        pauseFeedWork: () {},
        pauseTokenPolling: () {},
        onResetFailed: (_) {
          resetRecoveryCalls++;
        },
        postDrainSettleDuration: Duration.zero,
      );

      await service.rebuildMetadata();
      await Future<void>.delayed(Duration.zero);

      expect(recreateCalls, 1);
      expect(resetRecoveryCalls, 0);
    },
  );

  test(
    'forgetIExist recovery still runs when retry fails before replace',
    () async {
      var resetRecoveryCalls = 0;
      var recreateCalls = 0;

      final service = LocalDataCleanupService(
        closeAndDeleteDatabase: () async {},
        clearObjectBoxData: () async {},
        clearCachedImages: () async {},
        recreateDatabaseFromSeed: (_) async {
          recreateCalls++;
          throw StateError('download failed before replace');
        },
        runBootstrap: () async {},
        pauseFeedWork: () {},
        pauseTokenPolling: () {},
        clearLegacySqlite: () async {},
        clearLegacyHive: () async {},
        onResetFailed: (_) {
          resetRecoveryCalls++;
        },
        postDrainSettleDuration: Duration.zero,
      );

      await service.forgetIExist();
      await Future<void>.delayed(Duration.zero);

      expect(recreateCalls, 1);
      expect(resetRecoveryCalls, 1);
    },
  );
}
