import 'dart:io';

import 'package:app/domain/extensions/playlist_ext.dart';
import 'package:app/domain/models/channel.dart';
import 'package:app/domain/models/playlist.dart';
import 'package:app/domain/models/wallet_address.dart';
import 'package:app/infra/config/app_config.dart';
import 'package:app/infra/services/bootstrap_service.dart';
import 'package:app/infra/services/domain_address_service.dart';
import 'package:app/infra/services/local_data_cleanup_service.dart';
import 'package:app/infra/workers/background_worker.dart';
import 'package:app/infra/workers/worker_scheduler.dart';
import 'package:app/infra/workers/worker_state_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart' show Variable;
import 'package:logging/logging.dart';

import '../helpers/integration_test_harness.dart';

class _InMemoryWorkerStateStore implements WorkerStateStore {
  final Map<String, WorkerStateSnapshot> _rows =
      <String, WorkerStateSnapshot>{};

  @override
  Future<void> clearCheckpoint(String workerId) async {
    final current = _rows[workerId];
    _rows[workerId] = WorkerStateSnapshot(
      stateIndex: current?.stateIndex ?? BackgroundWorkerState.idle.index,
    );
  }

  @override
  Future<WorkerStateSnapshot?> load(String workerId) async => _rows[workerId];

  @override
  Future<void> save({
    required String workerId,
    required int stateIndex,
    Map<String, dynamic>? checkpoint,
  }) async {
    _rows[workerId] = WorkerStateSnapshot(
      stateIndex: stateIndex,
      checkpoint: checkpoint,
    );
  }
}

WorkerScheduler _makeScheduler({
  required IntegrationTestContext context,
  required _InMemoryWorkerStateStore workerStateStore,
}) {
  return WorkerScheduler(
    workerStateService: workerStateStore,
    databaseService: context.databaseService,
    indexerEndpoint: AppConfig.indexerApiUrl,
    indexerApiKey: AppConfig.indexerApiKey,
  );
}

void main() {
  group('Worker orchestration lifecycle integration', () {
    late IntegrationTestContext context;
    late _InMemoryWorkerStateStore workerStateStore;

    setUp(() async {
      context = await createIntegrationTestContext();
      workerStateStore = _InMemoryWorkerStateStore();
    });

    tearDown(() async {
      await context.dispose();
    });

    test(
      'startOnForeground / pauseOnBackground / stopAll lifecycle completes',
      () async {
        final scheduler = _makeScheduler(
          context: context,
          workerStateStore: workerStateStore,
        );

        await scheduler.startOnForeground();
        await Future<void>.delayed(const Duration(milliseconds: 100));
        await scheduler.pauseOnBackground();
        await scheduler.startOnForeground();
        await scheduler.stopAll();
      },
    );

    test(
      'scheduler can fresh-start after stop without stale sqlite lock',
      () async {
        final scheduler = _makeScheduler(
          context: context,
          workerStateStore: workerStateStore,
        );

        await scheduler.startOnForeground();
        await scheduler.stopAll();

        // Trigger a real DB access to open the sqlite file, then verify the
        // scheduler can start again without hitting a stale WAL/shm lock.
        await context.databaseService.getAddressPlaylists();
        final sqliteFile = File(context.databaseFile.path);
        expect(sqliteFile.existsSync(), isTrue);

        await scheduler.startOnForeground();
        await scheduler.stopAll();
      },
    );

    test(
      'forget I exist clears workers, sqlite, and objectbox local data',
      () async {
        final scheduler = _makeScheduler(
          context: context,
          workerStateStore: workerStateStore,
        );

        final now = DateTime.now().toUtc();
        await context.databaseService.ingestPublisher(id: 1, name: 'Publisher');
        await context.databaseService.ingestChannel(
          Channel(
            id: 'ch_forget',
            name: 'Forget Channel',
            type: ChannelType.dp1,
            publisherId: 1,
            createdAt: now,
            updatedAt: now,
          ),
        );
        await context.databaseService.ingestPlaylist(
          Playlist(
            id: 'pl_forget',
            name: 'Forget Playlist',
            type: PlaylistType.dp1,
            channelId: 'ch_forget',
            sortMode: PlaylistSortMode.position,
            createdAt: now,
            updatedAt: now,
          ),
        );

        await scheduler.startOnForeground();
        await Future<void>.delayed(const Duration(milliseconds: 100));

        final fakeObjectBoxRows = <String, int>{
          'app_state': 1,
          'app_state_address': 1,
          'worker_state': 1,
          'ff1_device': 1,
          'remote_config': 1,
        };

        final service = LocalDataCleanupService(
          stopWorkersGracefully: scheduler.stopAll,
          checkpointDatabase: context.databaseService.checkpoint,
          truncateDatabase: context.databaseService.clearAll,
          clearObjectBoxData: () async {
            fakeObjectBoxRows.updateAll((key, value) => 0);
          },
          clearCachedImages: () async {},
          getPersonalAddresses: () async => const <String>[],
          restorePersonalAddressPlaylists: (_) async {},
          refetchFromBeginning: (_) async {},
          pauseFeedWork: () {},
          pauseTokenPolling: () {},
        );

        await service.clearLocalData();

        final channelsCount = await context.database
            .customSelect('SELECT COUNT(*) AS count FROM channels')
            .getSingle();
        expect(channelsCount.read<int>('count'), equals(0));

        final playlistsCount = await context.database
            .customSelect('SELECT COUNT(*) AS count FROM playlists')
            .getSingle();
        expect(playlistsCount.read<int>('count'), equals(0));

        expect(
          fakeObjectBoxRows.values.every((count) => count == 0),
          isTrue,
        );
      },
    );

    test(
      'imports ENS/TNS addresses via workers with full sqlite records',
      () async {
        const sqliteArtifactPath = '/tmp/ff_app_worker_address_import.sqlite';
        const ensDomain = 'einstein-rosen.eth';
        const tnsDomain = 'einstein-rosen.tez';
        final workerLogs = <String>[];
        final originalRootLevel = Logger.root.level;
        Logger.root.level = Level.ALL;
        final workerLogSubscription = Logger.root.onRecord.listen((record) {
          if (record.loggerName.contains('IndexAddressWorker') ||
              record.loggerName.contains('WorkerScheduler')) {
            final line =
                '${record.level.name} ${record.loggerName}: ${record.message}';
            workerLogs.add(line);
            // ignore: avoid_print
            print(line);
          }
        });

        expect(AppConfig.domainResolverUrl, isNotEmpty);
        expect(AppConfig.domainResolverApiKey, isNotEmpty);
        expect(AppConfig.indexerApiUrl, isNotEmpty);
        expect(AppConfig.indexerApiKey, isNotEmpty);

        await BootstrapService(
          databaseService: context.databaseService,
        ).bootstrap();

        final domainAddressService = DomainAddressService(
          resolverUrl: AppConfig.domainResolverUrl,
          resolverApiKey: AppConfig.domainResolverApiKey,
        );

        final ensResolved = await domainAddressService.verifyAddressOrDomain(
          ensDomain,
        );
        final tnsResolved = await domainAddressService.verifyAddressOrDomain(
          tnsDomain,
        );

        expect(ensResolved, isNotNull);
        expect(tnsResolved, isNotNull);

        final resolvedAddresses = <String>[
          ensResolved!.address,
          tnsResolved!.address,
        ];

        for (final resolvedAddress in resolvedAddresses) {
          final playlist = PlaylistExt.fromWalletAddress(
            WalletAddress(
              address: resolvedAddress,
              createdAt: DateTime.now(),
              name: resolvedAddress,
            ),
          );
          await context.databaseService.ingestPlaylist(playlist);
        }
        await context.databaseService.checkpoint();

        final scheduler = _makeScheduler(
          context: context,
          workerStateStore: workerStateStore,
        );

        try {
          await scheduler.startOnForeground();
          for (final resolvedAddress in resolvedAddresses) {
            await scheduler.onAddressAdded(resolvedAddress);
            await _waitForAddressIndexedWithinTwoMinutes(
              context: context,
              address: resolvedAddress,
              workerLogs: workerLogs,
            );
          }

          await scheduler.stopAll();
          await context.databaseService.checkpoint();

          final sqliteArtifact = File(sqliteArtifactPath);
          if (sqliteArtifact.existsSync()) {
            await sqliteArtifact.delete();
          }
          await context.databaseFile.copy(sqliteArtifactPath);
          expect(sqliteArtifact.existsSync(), isTrue);

          for (final resolvedAddress in resolvedAddresses) {
            final stats = await _loadAddressStats(
              context: context,
              address: resolvedAddress,
            );
            expect(
              stats.playlistCount,
              equals(1),
              reason: 'Expected exactly one playlist for $resolvedAddress.',
            );
            expect(
              stats.channelCount,
              equals(1),
              reason: 'Expected exactly one channel for $resolvedAddress.',
            );
            expect(
              stats.itemCount,
              greaterThan(100),
              reason: 'Expected more than 100 items for $resolvedAddress.',
            );
            expect(
              stats.missingThumbnailCount,
              equals(0),
              reason:
                  'Expected no items without thumbnails for $resolvedAddress.',
            );
          }
        } finally {
          Logger.root.level = originalRootLevel;
          await workerLogSubscription.cancel();
          await scheduler.stopAll();
        }
      },
      timeout: const Timeout(Duration(minutes: 30)),
    );
  });
}

class _AddressStats {
  _AddressStats({
    required this.playlistCount,
    required this.channelCount,
    required this.itemCount,
    required this.missingThumbnailCount,
  });

  final int playlistCount;
  final int channelCount;
  final int itemCount;
  final int missingThumbnailCount;
}

Future<_AddressStats> _loadAddressStats({
  required IntegrationTestContext context,
  required String address,
}) async {
  final normalized = address.toUpperCase();

  final playlistCountRow = await context.database
      .customSelect(
        '''
        SELECT COUNT(*) AS count
        FROM playlists
        WHERE UPPER(owner_address) = ?1
        ''',
        variables: [Variable.withString(normalized)],
      )
      .getSingle();
  final channelCountRow = await context.database
      .customSelect(
        '''
        SELECT COUNT(DISTINCT ch.id) AS count
        FROM channels ch
        JOIN playlists p ON p.channel_id = ch.id
        WHERE UPPER(p.owner_address) = ?1
        ''',
        variables: [Variable.withString(normalized)],
      )
      .getSingle();
  final itemCountRow = await context.database
      .customSelect(
        '''
        SELECT COUNT(*) AS count
        FROM items i
        JOIN playlist_entries pe ON pe.item_id = i.id
        JOIN playlists p ON p.id = pe.playlist_id
        WHERE UPPER(p.owner_address) = ?1
        ''',
        variables: [Variable.withString(normalized)],
      )
      .getSingle();
  final missingThumbnailRow = await context.database
      .customSelect(
        '''
        SELECT COUNT(*) AS count
        FROM items i
        JOIN playlist_entries pe ON pe.item_id = i.id
        JOIN playlists p ON p.id = pe.playlist_id
        WHERE UPPER(p.owner_address) = ?1
          AND i.thumbnail_uri IS NULL
        ''',
        variables: [Variable.withString(normalized)],
      )
      .getSingle();

  return _AddressStats(
    playlistCount: playlistCountRow.read<int>('count'),
    channelCount: channelCountRow.read<int>('count'),
    itemCount: itemCountRow.read<int>('count'),
    missingThumbnailCount: missingThumbnailRow.read<int>('count'),
  );
}

Future<void> _waitForAddressIndexedWithinTwoMinutes({
  required IntegrationTestContext context,
  required String address,
  required List<String> workerLogs,
}) async {
  final startedAt = DateTime.now();
  final deadline = startedAt.add(const Duration(minutes: 2));

  while (DateTime.now().isBefore(deadline)) {
    final stats = await _loadAddressStats(
      context: context,
      address: address,
    );
    if (stats.itemCount > 100) {
      return;
    }
    await Future<void>.delayed(const Duration(seconds: 2));
  }

  final elapsed = DateTime.now().difference(startedAt);
  final lastStats = await _loadAddressStats(
    context: context,
    address: address,
  );
  final recentWorkerLogs = workerLogs.length <= 30
      ? workerLogs
      : workerLogs.sublist(workerLogs.length - 30);
  final logsSummary = recentWorkerLogs.isEmpty
      ? 'No worker logs captured.'
      : recentWorkerLogs.join('\n');
  fail(
    'Address indexing exceeded 2 minutes for $address '
    '(elapsed=${elapsed.inSeconds}s). '
    'stats={playlists:${lastStats.playlistCount}, '
    'channels:${lastStats.channelCount}, items:${lastStats.itemCount}, '
    'missingThumb:${lastStats.missingThumbnailCount}}.\n'
    'Recent worker logs:\n$logsSummary',
  );
}
