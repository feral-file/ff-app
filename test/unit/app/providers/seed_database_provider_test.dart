import 'dart:async';
import 'dart:io';

import 'package:app/app/providers/local_data_cleanup_provider.dart';
import 'package:app/app/providers/seed_database_provider.dart';
import 'package:app/app/providers/seed_database_ready_provider.dart';
import 'package:app/domain/models/playlist.dart';
import 'package:app/infra/config/app_state_service.dart';
import 'package:app/infra/database/app_database.dart';
import 'package:app/infra/database/database_provider.dart';
import 'package:app/infra/database/database_service.dart';
import 'package:app/infra/database/favorite_history_snapshot.dart';
import 'package:app/infra/database/seed_database_gate.dart';
import 'package:app/infra/services/local_data_cleanup_service.dart';
import 'package:app/infra/services/seed_database_artifact_validator.dart';
import 'package:app/infra/services/seed_database_service.dart';
import 'package:app/infra/services/seed_database_sync_service.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:riverpod/misc.dart' show Override;

import '../../../helpers/seed_database_test_helper.dart';

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

  /// Test-only: persisted first-install / seed completion flag.
  bool get seedDownloadCompletedForTest => _hasCompletedSeedDownload;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Real [SeedDatabaseSyncService] + blocking replace: sync1 holds replace
/// while sync2 fails at download (exercises `_replaceLock` in sync service).
class _BlockingReplaceSeedService extends SeedDatabaseService {
  _BlockingReplaceSeedService({
    required this.validArtifactPath,
    required this.replaceEntered,
    required this.replaceMayComplete,
  });

  final String validArtifactPath;
  final Completer<void> replaceEntered;
  final Completer<void> replaceMayComplete;

  int _downloadCount = 0;

  @override
  Future<bool> hasLocalDatabase() async => true;

  @override
  Future<String> headRemoteEtag() async => 'remote-v2';

  @override
  Future<String> downloadToTemporaryFile({
    void Function(double progress)? onProgress,
    int? maxBytes,
  }) async {
    _downloadCount += 1;
    if (_downloadCount >= 2) {
      throw const SeedDownloadException('simulated second download failure');
    }
    onProgress?.call(1);
    return validArtifactPath;
  }

  @override
  Future<void> replaceDatabaseFromTemporaryFile(
    String tempPath, {
    SeedDatabaseArtifactMetadata? prevalidatedArtifact,
  }) async {
    if (!replaceEntered.isCompleted) {
      replaceEntered.complete();
    }
    await replaceMayComplete.future;
  }

  @override
  Future<void> cleanupTemporarySeedArtifact(String tempPath) async {}
}

class _FakeSeedDatabaseSyncService implements SeedDatabaseSyncService {
  int syncCallCount = 0;
  bool? lastFailSilently;

  /// Progress values to report via onProgress (e.g. [0.0, 0.5, 1.0]).
  List<double> progressValues = const [0.0, 0.5, 1.0];

  /// When true (and not forceReplace), skips download (ETag unchanged).
  /// onDownloadStarted is not called.
  bool skipDownload = false;

  /// When true, sync returns false immediately (e.g. failed download, no file).
  bool returnFalseWithoutDownload = false;

  /// When true, sync fails after `beforeReplace` has already dropped readiness.
  bool throwAfterBeforeReplace = false;

  /// When skipDownload is false, passed to onDownloadStarted. Use false for
  /// first install (emits syncing), true for update (no syncing).
  bool hasLocalDatabase = false;

  @override
  Future<T> runWithReplaceLock<T>(Future<T> Function() action) async {
    return action();
  }

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
    if (returnFalseWithoutDownload) {
      return false;
    }
    if (!forceReplace && skipDownload) {
      return false;
    }
    onDownloadStarted?.call(
      hasLocalDatabase: hasLocalDatabase,
      localEtag: 'local',
      remoteEtag: 'remote',
    );
    await beforeReplace();
    if (throwAfterBeforeReplace) {
      throw Exception('Simulated replace failure after beforeReplace');
    }
    final progress = onProgress;
    if (progress != null) {
      progressValues.forEach(progress);
    }
    await afterReplace();
    return true;
  }
}

/// Sync 1 runs beforeReplace, then waits on blockAfterBeforeReplace so sync 2
/// can interleave; the first session's snapshot must still restore later.
class _OverlappingSeedSyncRaceFake implements SeedDatabaseSyncService {
  _OverlappingSeedSyncRaceFake({
    required Completer<void> blockAfterBeforeReplace,
    required this.hasLocalDatabaseForStarted,
  }) : _block = blockAfterBeforeReplace;

  final Completer<void> _block;
  final bool hasLocalDatabaseForStarted;
  int syncCallCount = 0;

  @override
  Future<T> runWithReplaceLock<T>(Future<T> Function() action) async {
    return action();
  }

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

/// First sync yields so a second [sync] can start; first returns quickly with
/// no update while the second blocks — exercises deferred readiness merge when
/// the first session finishes before the second.
class _ParallelQuickSkipAndBlockFake implements SeedDatabaseSyncService {
  _ParallelQuickSkipAndBlockFake({required Completer<void> blockSecond})
    : _blockSecond = blockSecond;

  final Completer<void> _blockSecond;
  var _call = 0;

  @override
  Future<T> runWithReplaceLock<T>(Future<T> Function() action) async {
    return action();
  }

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
    _call++;
    if (_call == 1) {
      await Future<void>.value();
      onDownloadStarted?.call(
        hasLocalDatabase: true,
        localEtag: 'local',
        remoteEtag: 'remote',
      );
      return false;
    }
    await _blockSecond.future;
    return false;
  }
}

/// Session 1 blocks after `beforeReplace`; session 2 throws before
/// `beforeReplace` (overlap: session 1 dropped readiness).
class _OverlapFailBeforeSecondBeforeReplaceFake
    implements SeedDatabaseSyncService {
  _OverlapFailBeforeSecondBeforeReplaceFake({
    required Completer<void> blockAfterBeforeReplace,
  }) : _block = blockAfterBeforeReplace;

  final Completer<void> _block;
  int syncCallCount = 0;

  @override
  Future<T> runWithReplaceLock<T>(Future<T> Function() action) async {
    return action();
  }

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
        hasLocalDatabase: true,
        localEtag: 'local',
        remoteEtag: 'remote',
      );
      await beforeReplace();
      await _block.future;
      await afterReplace();
      return true;
    }
    throw Exception('sync2 failed before replace');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// First sync completes successfully while second remains in-flight, so the
/// first session becomes superseded after replace has already reopened state.
class _OverlapUpdatedSuccessFake implements SeedDatabaseSyncService {
  _OverlapUpdatedSuccessFake({
    required Completer<void> firstMayComplete,
    required Completer<void> secondStarted,
    required Completer<void> secondMayComplete,
  }) : _firstMayComplete = firstMayComplete,
       _secondStarted = secondStarted,
       _secondMayComplete = secondMayComplete;

  final Completer<void> _firstMayComplete;
  final Completer<void> _secondStarted;
  final Completer<void> _secondMayComplete;
  int syncCallCount = 0;

  @override
  Future<T> runWithReplaceLock<T>(Future<T> Function() action) async {
    return action();
  }

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
        hasLocalDatabase: true,
        localEtag: 'local',
        remoteEtag: 'remote',
      );
      await beforeReplace();
      await _firstMayComplete.future;
      await afterReplace();
      return true;
    }
    onDownloadStarted?.call(
      hasLocalDatabase: true,
      localEtag: 'local',
      remoteEtag: 'remote',
    );
    await beforeReplace();
    if (!_secondStarted.isCompleted) {
      _secondStarted.complete();
    }
    await _secondMayComplete.future;
    await afterReplace();
    return true;
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
  // `DatabaseService` exposes a private constructor parameter name, so this
  // test helper keeps the explicit forwarding constructor instead of the
  // super-parameter shorthand.
  // ignore: use_super_parameters
  _SpyDatabaseService(AppDatabase db) : super(db);

  int snapshotCalls = 0;
  int restoreCalls = 0;

  /// When true, snapshot returns an empty list (restore is skipped). Use when
  /// the test cannot survive provider invalidation closing the test
  /// [AppDatabase].
  bool snapshotReturnsEmpty = false;
  bool restoreThrows = false;

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
    if (restoreThrows) {
      throw Exception('simulated favorite restore failure');
    }
  }
}

class _FakeSeedDatabaseService extends SeedDatabaseService {
  _FakeSeedDatabaseService({required this.hasLocal}) : super();

  final bool hasLocal;

  @override
  Future<bool> hasLocalDatabase() async => hasLocal;
}

/// Simulates a slow Drift/native shutdown: if reconnect invalidation ran
/// without awaiting [close], [isClosedFully] would still be false when
/// [LocalDataCleanupService.performReconnectInfraInvalidation] runs
/// (SQLITE_BUSY regression on the real file DB).
class _SlowClosingAppDatabase extends AppDatabase {
  _SlowClosingAppDatabase({required this.closeDelay})
    : super.forTesting(NativeDatabase.memory());

  final Duration closeDelay;

  /// Set to true only after [super.close] completes (and optional delay).
  bool isClosedFully = false;

  @override
  Future<void> close() async {
    if (closeDelay > Duration.zero) {
      await Future<void>.delayed(closeDelay);
    }
    await super.close();
    isClosedFully = true;
  }
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

  test(
    'seed afterReplace awaits DB close before reconnect invalidation '
    '(SQLITE_BUSY / dual AppDatabase regression)',
    () async {
      const slowClose = Duration(milliseconds: 25);
      final db = _SlowClosingAppDatabase(closeDelay: slowClose);
      addTearDown(() async {
        try {
          await db.close();
        } on Object catch (_) {}
      });

      var reconnectInvalidationCalls = 0;

      final cleanupSpy = LocalDataCleanupService(
        closeAndDeleteDatabase: () async {},
        clearObjectBoxData: () async {},
        clearCachedImages: () async {},
        recreateDatabaseFromSeed: (_) async {},
        runBootstrap: () async {},
        pauseFeedWork: () {},
        pauseTokenPolling: () {},
        invalidateReconnectInfraProviders: () {
          reconnectInvalidationCalls++;
          expect(
            db.isClosedFully,
            isTrue,
            reason:
                'Riverpod onDispose does not await async close. If we '
                'invalidate appDatabaseProvider before await close() '
                'completes, a second native open can race the first '
                '(SQLITE_BUSY on e.g. PRAGMA journal_mode = WAL).',
          );
        },
      );

      final fakeSyncService = _FakeSeedDatabaseSyncService()
        ..hasLocalDatabase = true;

      final container = ProviderContainer.test(
        overrides: [
          seedDatabaseSyncServiceProvider.overrideWithValue(fakeSyncService),
          appStateServiceProvider.overrideWithValue(_FakeAppStateService()),
          seedDatabaseReadyActionsProvider.overrideWithValue(_noOpActions),
          appDatabaseProvider.overrideWithValue(db),
          rawDatabaseServiceProvider.overrideWithValue(DatabaseService(db)),
          localDataCleanupServiceProvider.overrideWithValue(cleanupSpy),
          _fakeSeedDbSvc(hasLocal: true),
        ],
      );
      addTearDown(container.dispose);

      // Warm up so ref.exists(appDatabaseProvider) is true in afterReplace.
      expect(container.read(appDatabaseProvider), same(db));

      await container.read(seedDownloadProvider.notifier).sync();

      expect(reconnectInvalidationCalls, 1);
      expect(db.isClosedFully, isTrue);
    },
  );

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

    // User already completed seed download; syncs run in background.
    final container = ProviderContainer.test(
      overrides: [
        seedDatabaseSyncServiceProvider.overrideWithValue(fakeSyncService),
        appStateServiceProvider.overrideWithValue(
          _FakeAppStateService(initialHasCompletedSeedDownload: true),
        ),
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

  test('does not emit syncing when ETag unchanged (no download)', () async {
    final fakeSyncService = _FakeSeedDatabaseSyncService()..skipDownload = true;
    final states = <SeedDownloadState>[];

    final container = ProviderContainer.test(
      overrides: [
        seedDatabaseSyncServiceProvider.overrideWithValue(fakeSyncService),
        appStateServiceProvider.overrideWithValue(_FakeAppStateService()),
        seedDatabaseReadyActionsProvider.overrideWithValue(_noOpActions),
        // No replace (updated==false) but a seed file already exists on disk.
        _fakeSeedDbSvc(hasLocal: true),
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

  test(
    'does not complete SeedDatabaseGate when no local DB after sync',
    () async {
      final fakeSyncService = _FakeSeedDatabaseSyncService()
        ..returnFalseWithoutDownload = true;

      final container = ProviderContainer.test(
        overrides: [
          seedDatabaseSyncServiceProvider.overrideWithValue(fakeSyncService),
          seedDatabaseServiceProvider.overrideWithValue(
            _FakeSeedDatabaseService(hasLocal: false),
          ),
          appStateServiceProvider.overrideWithValue(_FakeAppStateService()),
        ],
      );
      addTearDown(container.dispose);

      await container.read(seedDownloadProvider.notifier).sync();

      expect(SeedDatabaseGate.isCompleted, isFalse);
      expect(
        container.read(seedDownloadProvider).status,
        SeedDownloadStatus.error,
      );
    },
  );

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
    'restores readiness when sync fails after beforeReplace '
    'but local DB remains',
    () async {
      final fakeSyncService = _FakeSeedDatabaseSyncService()
        ..hasLocalDatabase = true
        ..throwAfterBeforeReplace = true;
      final memDb = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(memDb.close);
      final spy = _SpyDatabaseService(memDb)..snapshotReturnsEmpty = true;
      var onNotReadyCallCount = 0;
      var onReadyCallCount = 0;
      final actions = SeedDatabaseReadyActions(
        onNotReady: () async {
          onNotReadyCallCount++;
        },
        onReady: () async {
          onReadyCallCount++;
        },
      );

      SeedDatabaseGate.complete();
      final container = ProviderContainer.test(
        overrides: [
          seedDatabaseSyncServiceProvider.overrideWithValue(fakeSyncService),
          appStateServiceProvider.overrideWithValue(_FakeAppStateService()),
          seedDatabaseReadyActionsProvider.overrideWithValue(actions),
          appDatabaseProvider.overrideWithValue(memDb),
          rawDatabaseServiceProvider.overrideWithValue(spy),
          _fakeSeedDbSvc(hasLocal: true),
        ],
      );
      addTearDown(container.dispose);

      final changed = await container
          .read(seedDownloadProvider.notifier)
          .sync();

      expect(changed, isFalse);
      expect(onNotReadyCallCount, 1);
      expect(
        onReadyCallCount,
        1,
        reason: 'existing DB remained readable and readiness must reopen',
      );
      expect(container.read(isSeedDatabaseReadyProvider), isTrue);
      expect(SeedDatabaseGate.isCompleted, isTrue);
      expect(
        container.read(seedDownloadProvider).status,
        SeedDownloadStatus.error,
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
      SeedDatabaseGate.complete();
      final completer = Completer<void>();
      final fakeSyncService = _FakeSeedDatabaseSyncService();
      final slowFake = _SlowFakeSeedDatabaseSyncService(
        delegate: fakeSyncService,
        beforeComplete: completer.future,
      );
      final appState = _FakeAppStateService();
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
          appStateServiceProvider.overrideWithValue(appState),
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
      expect(
        SeedDatabaseGate.isCompleted,
        isTrue,
        reason:
            'superseded session must open SeedDatabaseGate once the overlap '
            'drains',
      );
      expect(
        appState.seedDownloadCompletedForTest,
        isTrue,
        reason:
            'superseded session must persist hasCompletedSeedDownload so '
            'resume does not treat the next launch like first install',
      );
    },
  );

  test(
    'successful replace keeps gate open even if favorite restore fails',
    () async {
      SeedDatabaseGate.complete();
      final fakeSyncService = _FakeSeedDatabaseSyncService();
      final memDb = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(memDb.close);
      final spy = _SpyDatabaseService(memDb)
        ..snapshotReturnsEmpty = false
        ..restoreThrows = true;
      var onReadyCallCount = 0;
      final actions = SeedDatabaseReadyActions(
        onNotReady: _noOpFuture,
        onReady: () async {
          onReadyCallCount++;
        },
      );

      final container = ProviderContainer.test(
        overrides: [
          seedDatabaseSyncServiceProvider.overrideWithValue(fakeSyncService),
          appStateServiceProvider.overrideWithValue(_FakeAppStateService()),
          seedDatabaseReadyActionsProvider.overrideWithValue(actions),
          appDatabaseProvider.overrideWithValue(memDb),
          rawDatabaseServiceProvider.overrideWithValue(spy),
          _fakeSeedDbSvc(hasLocal: true),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(seedDownloadProvider.notifier);
      await notifier.sync();

      expect(onReadyCallCount, 1);
      expect(spy.restoreCalls, 1);
      expect(
        container.read(seedDownloadProvider).status,
        SeedDownloadStatus.done,
      );
      expect(SeedDatabaseGate.isCompleted, isTrue);
    },
  );

  test(
    'superseded successful sync defers readiness and gate until overlap drains',
    () async {
      SeedDatabaseGate.resetForTesting();
      final firstMayComplete = Completer<void>();
      final secondStarted = Completer<void>();
      final secondMayComplete = Completer<void>();
      final fakeSyncService = _OverlapUpdatedSuccessFake(
        firstMayComplete: firstMayComplete,
        secondStarted: secondStarted,
        secondMayComplete: secondMayComplete,
      );
      final appState = _FakeAppStateService();
      var onReadyCallCount = 0;
      final actions = SeedDatabaseReadyActions(
        onNotReady: _noOpFuture,
        onReady: () async {
          onReadyCallCount++;
        },
      );

      final container = ProviderContainer.test(
        overrides: [
          seedDatabaseSyncServiceProvider.overrideWithValue(fakeSyncService),
          appStateServiceProvider.overrideWithValue(appState),
          seedDatabaseReadyActionsProvider.overrideWithValue(actions),
          _fakeSeedDbSvc(hasLocal: false),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(seedDownloadProvider.notifier);
      final sync1Future = notifier.sync();
      final sync2Future = notifier.sync();

      await secondStarted.future;
      expect(SeedDatabaseGate.isCompleted, isFalse);

      firstMayComplete.complete();
      await sync1Future;
      expect(SeedDatabaseGate.isCompleted, isFalse);

      secondMayComplete.complete();
      await sync2Future;

      expect(onReadyCallCount, greaterThanOrEqualTo(1));
      expect(container.read(isSeedDatabaseReadyProvider), isTrue);
      expect(SeedDatabaseGate.isCompleted, isTrue);
      expect(appState.seedDownloadCompletedForTest, isTrue);
    },
  );

  test(
    'second sync failure while first holds replaceLock does not reopen '
    'readiness before first completes',
    () async {
      SeedDatabaseGate.complete();
      final memDb = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(memDb.close);

      final tempDir = await Directory.systemTemp.createTemp('ff_seed_lock_');
      addTearDown(() async {
        if (tempDir.existsSync()) {
          await tempDir.delete(recursive: true);
        }
      });

      final artifact = File(p.join(tempDir.path, 'valid_seed.sqlite'));
      createSeedArtifactDatabase(file: artifact);

      final replaceEntered = Completer<void>();
      final replaceMayComplete = Completer<void>();
      final blockingSeed = _BlockingReplaceSeedService(
        validArtifactPath: artifact.path,
        replaceEntered: replaceEntered,
        replaceMayComplete: replaceMayComplete,
      );

      var localEtag = 'local-v1';
      final realSync = SeedDatabaseSyncService(
        seedDatabaseService: blockingSeed,
        loadLocalEtag: () => localEtag,
        saveLocalEtag: (etag) => localEtag = etag,
      );

      final container = ProviderContainer.test(
        overrides: [
          seedDatabaseSyncServiceProvider.overrideWithValue(realSync),
          seedDatabaseServiceProvider.overrideWithValue(blockingSeed),
          appStateServiceProvider.overrideWithValue(_FakeAppStateService()),
          seedDatabaseReadyActionsProvider.overrideWithValue(_noOpActions),
          appDatabaseProvider.overrideWithValue(memDb),
          rawDatabaseServiceProvider.overrideWithValue(
            _SpyDatabaseService(memDb)..snapshotReturnsEmpty = true,
          ),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(seedDownloadProvider.notifier);
      final sync1Future = notifier.sync();

      await replaceEntered.future;
      expect(container.read(isSeedDatabaseReadyProvider), isFalse);

      await notifier.sync();

      expect(
        container.read(isSeedDatabaseReadyProvider),
        isFalse,
        reason:
            'replace still in progress; failed download must not reopen '
            'readiness until all sync() calls drain.',
      );

      replaceMayComplete.complete();
      await sync1Future;

      expect(container.read(isSeedDatabaseReadyProvider), isTrue);
    },
  );

  test(
    'restores readiness when overlapping sync fails before beforeReplace '
    'but local DB remains',
    () async {
      SeedDatabaseGate.complete();
      final memDb = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(memDb.close);
      final block = Completer<void>();
      final fake = _OverlapFailBeforeSecondBeforeReplaceFake(
        blockAfterBeforeReplace: block,
      );

      final container = ProviderContainer.test(
        overrides: [
          seedDatabaseSyncServiceProvider.overrideWithValue(fake),
          appStateServiceProvider.overrideWithValue(_FakeAppStateService()),
          seedDatabaseReadyActionsProvider.overrideWithValue(_noOpActions),
          appDatabaseProvider.overrideWithValue(memDb),
          rawDatabaseServiceProvider.overrideWithValue(
            _SpyDatabaseService(memDb)..snapshotReturnsEmpty = true,
          ),
          _fakeSeedDbSvc(hasLocal: true),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(seedDownloadProvider.notifier);
      final sync1Future = notifier.sync();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(container.read(isSeedDatabaseReadyProvider), isFalse);

      await notifier.sync();

      expect(
        container.read(isSeedDatabaseReadyProvider),
        isFalse,
        reason:
            'Session 1 is still in replace; session 2 failure must not reopen '
            'readiness until all sync calls have drained.',
      );
      block.complete();
      await sync1Future;

      expect(
        container.read(isSeedDatabaseReadyProvider),
        isTrue,
        reason:
            'After the last sync completes, readiness reflects DB on disk '
            'again.',
      );
    },
  );

  test(
    'deferred readiness from first overlapping sync is not lost when the '
    'first session finishes before the blocked second',
    () async {
      final memDb = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(memDb.close);

      final blockSecond = Completer<void>();
      final fake = _ParallelQuickSkipAndBlockFake(blockSecond: blockSecond);

      final container = ProviderContainer.test(
        overrides: [
          seedDatabaseSyncServiceProvider.overrideWithValue(fake),
          appStateServiceProvider.overrideWithValue(_FakeAppStateService()),
          seedDatabaseReadyActionsProvider.overrideWithValue(_noOpActions),
          appDatabaseProvider.overrideWithValue(memDb),
          rawDatabaseServiceProvider.overrideWithValue(
            _SpyDatabaseService(memDb)..snapshotReturnsEmpty = true,
          ),
          _fakeSeedDbSvc(hasLocal: true),
        ],
      );
      addTearDown(container.dispose);

      SeedDatabaseGate.complete();
      container.read(isSeedDatabaseReadyProvider.notifier).seedReadyDirect =
          false;

      final notifier = container.read(seedDownloadProvider.notifier);
      final f1 = notifier.sync();
      final f2 = notifier.sync();

      await f1;
      expect(
        container.read(isSeedDatabaseReadyProvider),
        isFalse,
        reason:
            'Second sync still in flight; deferred reopen must wait for drain.',
      );

      blockSecond.complete();
      await f2;

      expect(container.read(isSeedDatabaseReadyProvider), isTrue);
    },
  );

  test(
    'when overlapping skip-only sync defers gate, drain completes gate even if '
    'readiness was already true',
    () async {
      SeedDatabaseGate.resetForTesting();
      final memDb = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(memDb.close);

      final blockSecond = Completer<void>();
      final fake = _ParallelQuickSkipAndBlockFake(blockSecond: blockSecond);

      final container = ProviderContainer.test(
        overrides: [
          seedDatabaseSyncServiceProvider.overrideWithValue(fake),
          appStateServiceProvider.overrideWithValue(_FakeAppStateService()),
          seedDatabaseReadyActionsProvider.overrideWithValue(_noOpActions),
          appDatabaseProvider.overrideWithValue(memDb),
          rawDatabaseServiceProvider.overrideWithValue(
            _SpyDatabaseService(memDb)..snapshotReturnsEmpty = true,
          ),
          _fakeSeedDbSvc(hasLocal: true),
        ],
      );
      addTearDown(container.dispose);

      container.read(isSeedDatabaseReadyProvider.notifier).seedReadyDirect =
          true;

      final notifier = container.read(seedDownloadProvider.notifier);
      final f1 = notifier.sync();
      final f2 = notifier.sync();

      await f1;
      expect(SeedDatabaseGate.isCompleted, isFalse);

      blockSecond.complete();
      await f2;

      expect(SeedDatabaseGate.isCompleted, isTrue);
    },
  );
}

/// Wraps a sync service: delegates until onDownloadStarted, then awaits
/// beforeComplete before continuing. Allows override to happen after syncing
/// state is set but before completion.
class _SlowFakeSeedDatabaseSyncService implements SeedDatabaseSyncService {
  _SlowFakeSeedDatabaseSyncService({
    required this.delegate,
    required Future<void> beforeComplete,
  }) : _beforeComplete = beforeComplete;

  final SeedDatabaseSyncService delegate;
  final Future<void> _beforeComplete;

  @override
  Future<T> runWithReplaceLock<T>(Future<T> Function() action) async {
    return action();
  }

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
      hasLocalDatabase:
          delegate is _FakeSeedDatabaseSyncService &&
          (delegate as _FakeSeedDatabaseSyncService).hasLocalDatabase,
      localEtag: 'local',
      remoteEtag: 'remote',
    );
    await _beforeComplete;
    return delegate.sync(
      beforeReplace: beforeReplace,
      afterReplace: afterReplace,
      forceReplace: forceReplace,
      onProgress: onProgress,
      failSilently: failSilently,
      isSessionActive: isSessionActive,
    );
  }
}
