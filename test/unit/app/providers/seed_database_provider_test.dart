import 'package:app/app/providers/seed_database_provider.dart';
import 'package:app/infra/database/seed_database_gate.dart';
import 'package:app/infra/services/seed_database_sync_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeSeedDatabaseSyncService implements SeedDatabaseSyncService {
  int syncCallCount = 0;
  bool? lastFailSilently;

  /// Progress values to report via onProgress (e.g. [0.0, 0.5, 1.0]).
  List<double> progressValues = const [0.0, 0.5, 1.0];

  @override
  Future<bool> syncIfNeeded({
    required Future<void> Function() beforeReplace,
    required Future<void> Function() afterReplace,
    void Function(double progress)? onProgress,
    bool failSilently = false,
  }) async {
    lastFailSilently = failSilently;
    syncCallCount++;
    await beforeReplace();
    for (final p in progressValues) {
      onProgress?.call(p);
    }
    await afterReplace();
    return false;
  }

  @override
  Future<void> forceReplace({
    required Future<void> Function() beforeReplace,
    required Future<void> Function() afterReplace,
    void Function(double progress)? onProgress,
  }) {
    throw UnimplementedError();
  }
}

void main() {
  setUp(SeedDatabaseGate.resetForTesting);

  test('seed sync can run again after the first completed run', () async {
    final fakeSyncService = _FakeSeedDatabaseSyncService();

    final container = ProviderContainer.test(
      overrides: [
        seedDatabaseSyncServiceProvider.overrideWithValue(fakeSyncService),
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

  test('passes silent-fail flag through to sync service', () async {
    final fakeSyncService = _FakeSeedDatabaseSyncService();
    final container = ProviderContainer.test(
      overrides: [
        seedDatabaseSyncServiceProvider.overrideWithValue(fakeSyncService),
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
