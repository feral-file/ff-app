import 'dart:async';

import 'package:app/app/providers/seed_database_provider.dart';
import 'package:app/app/providers/seed_database_ready_provider.dart';
import 'package:app/domain/models/playlist.dart';
import 'package:app/infra/config/app_state_service.dart';
import 'package:app/infra/database/app_database.dart';
import 'package:app/infra/database/database_provider.dart';
import 'package:app/infra/database/database_service.dart';
import 'package:app/infra/database/favorite_history_snapshot.dart';
import 'package:app/infra/database/seed_database_gate.dart';
import 'package:app/infra/services/seed_database_service.dart';
import 'package:app/infra/services/seed_database_sync_service.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riverpod/misc.dart' show Override;

/// Fake [AppStateService] for seed sync tests. Tracks seed download completion
/// so subsequent syncs run in background (suppressLoading).
class _FakeAppStateService implements AppStateService {
  _FakeAppStateService({bool initialHasCompletedSeedDownload = false})
    : _hasCompletedSeedDownload = initialHasCompletedSeedDownload;

  bool _hasCompletedSeedDownload;

  @override
  Future<bool> hasCompletedSeedDownload() async => _hasCompletedSeedDownload;

  @override
  Future<void> setHasCompletedSeedDownload({required bool completed}) async {
    _hasCompletedSeedDownload = completed;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeSeedDatabaseSyncService implements SeedDatabaseSyncService {
  int syncCallCount = 0;
  bool? lastFailSilently;

  /// Progress values to report via onProgress (e.g. [0.0, 0.5, 1.0]).
  List<double> progressValues = const [0.0, 0.5, 1.0];

  /// When true (and forceReplace false), skips download (simulates ETag unchanged).
  /// onDownloadStarted is not called.
  bool skipDownload = false;

  /// When skipDownload is false, passed to onDownloadStarted. Use false for
  /// first install (emits syncing), true for update (no syncing).
  bool hasLocalDatabase = false;

  @override
  Future<bool> sync({
    required Future<void> Function() beforeReplace,
    required Future<void> Function() afterReplace,
    bool forceReplace = false,
    void Function({
      required bool hasLocalDatabase,
      String? localEtag,
      String? remoteEtag,
    })?
    onDownloadStarted,
    void Function(double progress)? onProgress,
    bool failSilently = false,
    bool Function()? isSessionActive,
  }) async {
    lastFailSilently = failSilently;
    syncCallCount++;
    if (!forceReplace && skipDownload) {
      return false;
    }
    onDownloadStarted?.call(
      hasLocalDatabase: hasLocalDatabase,
      localEtag: 'local',
      remoteEtag: 'remote',
    );
    await beforeReplace();
    for (final p in progressValues) {
      onProgress?.call(p);
    }
    await afterReplace();
    return true;
  }
}

/// Sync 1 runs [beforeReplace], then waits on [blockAfterBeforeReplace] so sync
/// 2 can interleave; the first session's snapshot must still restore later.
class _OverlappingSeedSyncRaceFake implements SeedDatabaseSyncService {
  _OverlappingSeedSyncRaceFake({
    required Completer<void> blockAfterBeforeReplace,
    required this.hasLocalDatabaseForStarted,
  }) : _block = blockAfterBeforeReplace;

  final Completer<void> _block;
  final bool hasLocalDatabaseForStarted;
  int syncCallCount = 0;

  @override
  Future<bool> sync({
    required Future<void> Function() beforeReplace,
    required Future<void> Function() afterReplace,
    bool forceReplace = false,
    void Function({
      required bool hasLocalDatabase,
      String? localEtag,
      String? remoteEtag,
    })?
    onDownloadStarted,
    void Function(double progress)? onProgress,
    bool failSilently = false,
    bool Function()? isSessionActive,
  }) async {
    syncCallCount++;
    if (syncCallCount == 1) {
      onDownloadStarted?.call(
        hasLocalDatabase: hasLocalDatabaseForStarted,
        localEtag: 'local',
        remoteEtag: 'remote',
      );
      await beforeReplace();
      await _block.future;
      await afterReplace();
      return true;
    }
    return false;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final _noOpActions = SeedDatabaseReadyActions(
  onNotReady: _noOpFuture,
  onReady: _noOpFuture,
);

Future<void> _noOpFuture() async {}

class _SpyDatabaseService extends DatabaseService {
  _SpyDatabaseService(super.db);

  int snapshotCalls = 0;
  int restoreCalls = 0;

  /// When true, snapshot returns an empty list (restore is skipped). Use when
  /// the test cannot survive provider invalidation closing the test [AppDatabase].
  bool snapshotReturnsEmpty = false;

  @override
  Future<List<FavoritePlaylistSnapshot>> getFavoritePlaylistsSnapshot() async {
    snapshotCalls++;
    if (snapshotReturnsEmpty) return [];
    final now = DateTime.now();
    return [
      FavoritePlaylistSnapshot(
        playlist: Playlist.favorite(createdAt: now, updatedAt: now),
        items: const [],
      ),
    ];
  }

  @override
  Future<void> restoreFavoritePlaylistsSnapshot(
    List<FavoritePlaylistSnapshot> snapshots,
  ) async {
    restoreCalls++;
  }
}

class _FakeSeedDatabaseService extends SeedDatabaseService {
  _FakeSeedDatabaseService({required this.hasLocal}) : super();

  final bool hasLocal;

  @override
  Future<bool> hasLocalDatabase() async => hasLocal;
}

/// Avoids real SeedDatabaseService.hasLocalDatabase (path_provider) in tests.
Override _fakeSeedDbSvc({required bool hasLocal}) {
  return seedDatabaseServiceProvider.overrideWithValue(
    _FakeSeedDatabaseService(hasLocal: hasLocal),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(SeedDatabaseGate.resetForTesting);

  test('seed sync can run again after the first completed run', () async {
    final fakeSyncService = _FakeSeedDatabaseSyncService();

    final container = ProviderContainer.test(
      overrides: [
        seedDatabaseSyncServiceProvider.overrideWithValue(fakeSyncService),
        appStateServiceProvider.overrideWithValue(_FakeAppStateService()),
        seedDatabaseReadyActionsProvider.overrideWithValue(_noOpActions),
        _fakeSeedDbSvc(hasLocal: false),
      ],
    );
    addTearDown(container.dispose);

    final notifier = container.read(seedDownloadProvider.notifier);

    await notifier.sync();
    await notifier.sync();

    expect(fakeSyncService.syncCallCount, 2);
    expect(
      container.read(seedDownloadProvider).status,
      SeedDownloadStatus.done,
    );
    expect(fakeSyncService.lastFailSilently, isTrue);
  });

  test('progress is updated during sync', () async {
    final fakeSyncService = _FakeSeedDatabaseSyncService();
    final states = <SeedDownloadState>[];

    final container = ProviderContainer.test(
      overrides: [
        seedDatabaseSyncServiceProvider.overrideWithValue(fakeSyncService),
        appStateServiceProvider.overrideWithValue(_FakeAppStateService()),
        seedDatabaseReadyActionsProvider.overrideWithValue(_noOpActions),
        _fakeSeedDbSvc(hasLocal: false),
      ],
    );
    addTearDown(container.dispose);

    container.listen(seedDownloadProvider, (prev, next) => states.add(next));

    final notifier = container.read(seedDownloadProvider.notifier);
    await notifier.sync();

    expect(
      container.read(seedDownloadProvider).status,
      SeedDownloadStatus.done,
    );
    expect(container.read(seedDownloadProvider).progress, isNull);

    final syncingStates = states.where(
      (s) => s.status == SeedDownloadStatus.syncing,
    );
    expect(syncingStates, isNotEmpty);
    final withProgress = syncingStates.where((s) => s.progress != null);
    expect(withProgress, isNotEmpty);
  });

  test('does not emit syncing when updating existing DB', () async {
    final fakeSyncService = _FakeSeedDatabaseSyncService()
      ..hasLocalDatabase = true; // Update scenario, not first install.
    final states = <SeedDownloadState>[];

    // User has completed seed download before; subsequent syncs run in background.
    final container = ProviderContainer.test(
      overrides: [
        seedDatabaseSyncServiceProvider.overrideWithValue(fakeSyncService),
        appStateServiceProvider.overrideWithValue(
          _FakeAppStateService(initialHasCompletedSeedDownload: true),
        ),
        seedDatabaseReadyActionsProvider.overrideWithValue(_noOpActions),
        // Snapshot uses [seedDatabaseServiceProvider], not the sync fake's
        // hasLocalDatabase (UI only). Avoid real AppDatabase I/O in this test.
        _fakeSeedDbSvc(hasLocal: false),
      ],
    );
    addTearDown(container.dispose);

    container.listen(seedDownloadProvider, (prev, next) => states.add(next));

    await container.read(seedDownloadProvider.notifier).sync();

    expect(
      container.read(seedDownloadProvider).status,
      SeedDownloadStatus.done,
    );

    final syncingStates = states.where(
      (s) => s.status == SeedDownloadStatus.syncing,
    );
    expect(syncingStates, isEmpty);
  });

  test('does not emit syncing when ETag unchanged (no download)', () async {
    final fakeSyncService = _FakeSeedDatabaseSyncService()..skipDownload = true;
    final states = <SeedDownloadState>[];

    final container = ProviderContainer.test(
      overrides: [
        seedDatabaseSyncServiceProvider.overrideWithValue(fakeSyncService),
        appStateServiceProvider.overrideWithValue(_FakeAppStateService()),
        seedDatabaseReadyActionsProvider.overrideWithValue(_noOpActions),
        _fakeSeedDbSvc(hasLocal: false),
      ],
    );
    addTearDown(container.dispose);

    container.listen(seedDownloadProvider, (prev, next) => states.add(next));

    await container.read(seedDownloadProvider.notifier).sync();

    expect(
      container.read(seedDownloadProvider).status,
      SeedDownloadStatus.done,
    );

    final syncingStates = states.where(
      (s) => s.status == SeedDownloadStatus.syncing,
    );
    expect(syncingStates, isEmpty);
  });

  test('passes silent-fail flag through to sync service', () async {
    final fakeSyncService = _FakeSeedDatabaseSyncService();
    final container = ProviderContainer.test(
      overrides: [
        seedDatabaseSyncServiceProvider.overrideWithValue(fakeSyncService),
        appStateServiceProvider.overrideWithValue(_FakeAppStateService()),
        seedDatabaseReadyActionsProvider.overrideWithValue(_noOpActions),
        _fakeSeedDbSvc(hasLocal: false),
      ],
    );
    addTearDown(container.dispose);

    await container
        .read(seedDownloadProvider.notifier)
        .sync(
          failSilently: false,
        );

    expect(fakeSyncService.lastFailSilently, isFalse);
  });

  test(
    'setReady is called and runs onReady only when DB was replaced',
    () async {
      final fakeSyncService = _FakeSeedDatabaseSyncService();
      var onReadyCalled = false;
      final actions = SeedDatabaseReadyActions(
        onNotReady: _noOpFuture,
        onReady: () async {
          onReadyCalled = true;
        },
      );

      final container = ProviderContainer.test(
        overrides: [
          seedDatabaseSyncServiceProvider.overrideWithValue(fakeSyncService),
          appStateServiceProvider.overrideWithValue(_FakeAppStateService()),
          seedDatabaseReadyActionsProvider.overrideWithValue(actions),
          _fakeSeedDbSvc(hasLocal: false),
        ],
      );
      addTearDown(container.dispose);

      await container.read(seedDownloadProvider.notifier).sync();

      expect(
        onReadyCalled,
        isTrue,
        reason: 'setReady runs onReady when DB replaced',
      );
    },
  );

  test(
    'setReady is not called when sync skips download (ETag unchanged)',
    () async {
      final fakeSyncService = _FakeSeedDatabaseSyncService()
        ..skipDownload = true;
      var onReadyCalled = false;
      final actions = SeedDatabaseReadyActions(
        onNotReady: _noOpFuture,
        onReady: () async {
          onReadyCalled = true;
        },
      );

      final container = ProviderContainer.test(
        overrides: [
          seedDatabaseSyncServiceProvider.overrideWithValue(fakeSyncService),
          appStateServiceProvider.overrideWithValue(_FakeAppStateService()),
          seedDatabaseReadyActionsProvider.overrideWithValue(actions),
          _fakeSeedDbSvc(hasLocal: false),
        ],
      );
      addTearDown(container.dispose);

      await container.read(seedDownloadProvider.notifier).sync();

      expect(
        onReadyCalled,
        isFalse,
        reason: 'no invalidation when DB unchanged',
      );
    },
  );

  test(
    'isSyncInProgress is true during sync even when status stays idle',
    () async {
      final completer = Completer<void>();
      final fakeSyncService = _FakeSeedDatabaseSyncService()
        ..hasLocalDatabase = true;
      final slowFake = _SlowFakeSeedDatabaseSyncService(
        delegate: fakeSyncService,
        beforeComplete: completer.future,
      );

      final container = ProviderContainer.test(
        overrides: [
          seedDatabaseSyncServiceProvider.overrideWithValue(slowFake),
          appStateServiceProvider.overrideWithValue(
            _FakeAppStateService(initialHasCompletedSeedDownload: true),
          ),
          seedDatabaseReadyActionsProvider.overrideWithValue(_noOpActions),
          _fakeSeedDbSvc(hasLocal: false),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(seedDownloadProvider.notifier);
      final syncFuture = notifier.sync();

      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(
        container.read(seedDownloadProvider).isSyncInProgress,
        isTrue,
        reason:
            'sync in progress even when status stays idle (suppressLoading)',
      );
      expect(
        container.read(seedDownloadProvider).status,
        SeedDownloadStatus.idle,
        reason: 'status not syncing when suppressLoading',
      );

      completer.complete();
      await syncFuture;

      expect(
        container.read(seedDownloadProvider).isSyncInProgress,
        isFalse,
      );
    },
  );

  test(
    'overlapping sync does not drop first session favorite snapshot',
    () async {
      final memDb = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(memDb.close);
      final spy = _SpyDatabaseService(memDb)..snapshotReturnsEmpty = false;
      final block = Completer<void>();
      final raceFake = _OverlappingSeedSyncRaceFake(
        blockAfterBeforeReplace: block,
        hasLocalDatabaseForStarted: true,
      );

      final container = ProviderContainer.test(
        overrides: [
          seedDatabaseSyncServiceProvider.overrideWithValue(raceFake),
          appStateServiceProvider.overrideWithValue(_FakeAppStateService()),
          seedDatabaseReadyActionsProvider.overrideWithValue(_noOpActions),
          appDatabaseProvider.overrideWithValue(memDb),
          rawDatabaseServiceProvider.overrideWithValue(spy),
          _fakeSeedDbSvc(hasLocal: true),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(seedDownloadProvider.notifier);
      final sync1 = notifier.sync();
      await Future<void>.delayed(const Duration(milliseconds: 5));
      await notifier.sync();
      block.complete();
      await sync1;

      expect(raceFake.syncCallCount, 2);
      expect(spy.snapshotCalls, 1);
      expect(spy.restoreCalls, 1);
    },
  );

  test(
    'ETag seed replace snapshots Favorite when local seed file exists',
    () async {
      final memDb = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(memDb.close);
      final spy = _SpyDatabaseService(memDb)..snapshotReturnsEmpty = true;
      final fakeSyncService = _FakeSeedDatabaseSyncService()
        ..hasLocalDatabase = true;

      final container = ProviderContainer.test(
        overrides: [
          seedDatabaseSyncServiceProvider.overrideWithValue(fakeSyncService),
          appStateServiceProvider.overrideWithValue(_FakeAppStateService()),
          seedDatabaseReadyActionsProvider.overrideWithValue(_noOpActions),
          appDatabaseProvider.overrideWithValue(memDb),
          rawDatabaseServiceProvider.overrideWithValue(spy),
          seedDatabaseServiceProvider.overrideWithValue(
            _FakeSeedDatabaseService(hasLocal: true),
          ),
        ],
      );
      addTearDown(container.dispose);

      await container.read(seedDownloadProvider.notifier).sync();

      expect(spy.snapshotCalls, 1);
      expect(spy.restoreCalls, 0);
    },
  );

  test(
    'first install seed replace skips favorite snapshot when no local DB file',
    () async {
      final memDb = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(memDb.close);
      final spy = _SpyDatabaseService(memDb);
      final fakeSyncService = _FakeSeedDatabaseSyncService();

      final container = ProviderContainer.test(
        overrides: [
          seedDatabaseSyncServiceProvider.overrideWithValue(fakeSyncService),
          appStateServiceProvider.overrideWithValue(_FakeAppStateService()),
          seedDatabaseReadyActionsProvider.overrideWithValue(_noOpActions),
          appDatabaseProvider.overrideWithValue(memDb),
          rawDatabaseServiceProvider.overrideWithValue(spy),
          seedDatabaseServiceProvider.overrideWithValue(
            _FakeSeedDatabaseService(hasLocal: false),
          ),
        ],
      );
      addTearDown(container.dispose);

      await container.read(seedDownloadProvider.notifier).sync();

      expect(spy.snapshotCalls, 0);
      expect(spy.restoreCalls, 0);
    },
  );

  test(
    'overridden session restores readiness when it completed replace',
    () async {
      final completer = Completer<void>();
      final fakeSyncService = _FakeSeedDatabaseSyncService();
      final slowFake = _SlowFakeSeedDatabaseSyncService(
        delegate: fakeSyncService,
        beforeComplete: completer.future,
      );
      var onReadyCallCount = 0;
      final actions = SeedDatabaseReadyActions(
        onNotReady: _noOpFuture,
        onReady: () async {
          onReadyCallCount++;
        },
      );

      final container = ProviderContainer.test(
        overrides: [
          seedDatabaseSyncServiceProvider.overrideWithValue(slowFake),
          appStateServiceProvider.overrideWithValue(_FakeAppStateService()),
          seedDatabaseReadyActionsProvider.overrideWithValue(actions),
          _fakeSeedDbSvc(hasLocal: false),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(seedDownloadProvider.notifier);
      final sync1Future = notifier.sync();

      await Future<void>.delayed(const Duration(milliseconds: 10));
      final sync2Future = notifier.sync();
      completer.complete();
      await sync1Future;
      await sync2Future;

      expect(
        onReadyCallCount,
        greaterThanOrEqualTo(1),
        reason:
            'overridden session must call setReady when it completed replace',
      );
      expect(
        fakeSyncService.syncCallCount,
        2,
        reason: 'both syncs must run',
      );
      expect(
        container.read(seedDownloadProvider).status,
        SeedDownloadStatus.done,
        reason: 'final state from active session',
      );
    },
  );
}

/// Wraps a sync service: delegates until onDownloadStarted, then awaits
/// [beforeComplete] before continuing. Allows override to happen after
/// syncing state is set but before completion.
class _SlowFakeSeedDatabaseSyncService implements SeedDatabaseSyncService {
  _SlowFakeSeedDatabaseSyncService({
    required this.delegate,
    required Future<void> beforeComplete,
  }) : _beforeComplete = beforeComplete;

  final SeedDatabaseSyncService delegate;
  final Future<void> _beforeComplete;

  @override
  Future<bool> sync({
    required Future<void> Function() beforeReplace,
    required Future<void> Function() afterReplace,
    bool forceReplace = false,
    void Function({
      required bool hasLocalDatabase,
      String? localEtag,
      String? remoteEtag,
    })?
    onDownloadStarted,
    void Function(double progress)? onProgress,
    bool failSilently = false,
    bool Function()? isSessionActive,
  }) async {
    onDownloadStarted?.call(
      hasLocalDatabase: delegate is _FakeSeedDatabaseSyncService
          ? (delegate as _FakeSeedDatabaseSyncService).hasLocalDatabase
          : false,
      localEtag: 'local',
      remoteEtag: 'remote',
    );
    await _beforeComplete;
    return delegate.sync(
      beforeReplace: beforeReplace,
      afterReplace: afterReplace,
      forceReplace: forceReplace,
      onDownloadStarted: null,
      onProgress: onProgress,
      failSilently: failSilently,
      isSessionActive: isSessionActive,
    );
  }
}
