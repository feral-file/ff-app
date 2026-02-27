import 'package:app/app/providers/seed_database_provider.dart';
import 'package:app/infra/database/seed_database_gate.dart';
import 'package:app/infra/services/seed_database_sync_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeSeedDatabaseSyncService implements SeedDatabaseSyncService {
  int syncCallCount = 0;

  @override
  Future<bool> syncIfNeeded({
    required Future<void> Function() beforeReplace,
    required Future<void> Function() afterReplace,
    void Function(double progress)? onProgress,
    bool failSilently = false,
  }) async {
    syncCallCount++;
    await beforeReplace();
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
  });
}
