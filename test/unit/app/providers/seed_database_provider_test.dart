import 'package:app/app/providers/seed_database_provider.dart';
import 'package:app/infra/config/app_state_service.dart';
import 'package:app/infra/database/seed_database_gate.dart';
import 'package:app/infra/services/seed_database_service.dart';
import 'package:app/infra/services/seed_database_sync_service.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

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

/// Minimal fake seed service for gate tests (hasLocalDatabase only).
class _FakeSeedDatabaseService extends SeedDatabaseService {
  _FakeSeedDatabaseService({required this.localExists}) : super(dio: Dio());

  final bool localExists;

  @override
  Future<bool> hasLocalDatabase() async => localExists;
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
    final progress = onProgress;
    if (progress != null) {
      progressValues.forEach(progress);
    }
    await afterReplace();
    return true;
  }
}

void main() {
  setUp(SeedDatabaseGate.resetForTesting);

  test('seed sync can run again after the first completed run', () async {
    final fakeSyncService = _FakeSeedDatabaseSyncService();

    final container = ProviderContainer.test(
      overrides: [
        seedDatabaseSyncServiceProvider.overrideWithValue(fakeSyncService),
        seedDatabaseServiceProvider.overrideWithValue(
          _FakeSeedDatabaseService(localExists: true),
        ),
        appStateServiceProvider.overrideWithValue(_FakeAppStateService()),
      ],
    );
    addTearDown(container.dispose);

    final notifier = container.read(seedDownloadProvider.notifier);

    await notifier.syncAtAppStart(
      beforeReplace: () async {},
      afterReplace: () async {},
    );
    await notifier.syncAtAppStart(
      beforeReplace: () async {},
      afterReplace: () async {},
    );

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
        seedDatabaseServiceProvider.overrideWithValue(
          _FakeSeedDatabaseService(localExists: true),
        ),
        appStateServiceProvider.overrideWithValue(_FakeAppStateService()),
      ],
    );
    addTearDown(container.dispose);

    container.listen(seedDownloadProvider, (prev, next) => states.add(next));

    final notifier = container.read(seedDownloadProvider.notifier);
    await notifier.syncAtAppStart(
      beforeReplace: () async {},
      afterReplace: () async {},
    );

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
        seedDatabaseServiceProvider.overrideWithValue(
          _FakeSeedDatabaseService(localExists: true),
        ),
        appStateServiceProvider.overrideWithValue(
          _FakeAppStateService(initialHasCompletedSeedDownload: true),
        ),
      ],
    );
    addTearDown(container.dispose);

    container.listen(seedDownloadProvider, (prev, next) => states.add(next));

    await container
        .read(seedDownloadProvider.notifier)
        .syncAtAppStart(
          beforeReplace: () async {},
          afterReplace: () async {},
        );

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
        seedDatabaseServiceProvider.overrideWithValue(
          _FakeSeedDatabaseService(localExists: true),
        ),
        appStateServiceProvider.overrideWithValue(_FakeAppStateService()),
      ],
    );
    addTearDown(container.dispose);

    container.listen(seedDownloadProvider, (prev, next) => states.add(next));

    await container
        .read(seedDownloadProvider.notifier)
        .syncAtAppStart(
          beforeReplace: () async {},
          afterReplace: () async {},
        );

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
            _FakeSeedDatabaseService(localExists: false),
          ),
          appStateServiceProvider.overrideWithValue(_FakeAppStateService()),
        ],
      );
      addTearDown(container.dispose);

      await container
          .read(seedDownloadProvider.notifier)
          .syncAtAppStart(
            beforeReplace: () async {},
            afterReplace: () async {},
          );

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
        seedDatabaseServiceProvider.overrideWithValue(
          _FakeSeedDatabaseService(localExists: true),
        ),
        appStateServiceProvider.overrideWithValue(_FakeAppStateService()),
      ],
    );
    addTearDown(container.dispose);

    await container
        .read(seedDownloadProvider.notifier)
        .syncAtAppStart(
          beforeReplace: () async {},
          afterReplace: () async {},
          failSilently: false,
        );

    expect(fakeSyncService.lastFailSilently, isFalse);
  });
}
