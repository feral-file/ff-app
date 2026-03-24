import 'dart:async';

import 'package:app/app/providers/bootstrap_provider.dart';
import 'package:app/app/providers/database_service_provider.dart'
    show databaseServiceProvider, rawDatabaseServiceProvider;
import 'package:app/app/providers/ff1_wifi_providers.dart';
import 'package:app/app/providers/onboarding_provider.dart';
import 'package:app/app/providers/seed_database_provider.dart';
import 'package:app/app/providers/seed_database_ready_provider.dart';
import 'package:app/app/providers/services_provider.dart';
import 'package:app/infra/config/app_state_service.dart';
import 'package:app/infra/database/app_database.dart';
import 'package:app/infra/database/database_service.dart';
import 'package:app/infra/database/seed_database_gate.dart';
import 'package:app/infra/services/bootstrap_service.dart';
import 'package:app/infra/services/seed_database_service.dart';
import 'package:app/infra/services/seed_database_sync_service.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/integration_test_harness.dart';

// --- Fakes aligned with `test/unit/app/providers/seed_database_provider_test.dart` ---

Future<void> _noOpFuture() async {}

final _noOpActions = SeedDatabaseReadyActions(
  onNotReady: _noOpFuture,
  onReady: _noOpFuture,
);

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

/// First call: startup sync produced no replace (offline / failure). Second
/// call: successful download + replace (matches resume / retry success).
class _TwoPhaseStartupSeedSync implements SeedDatabaseSyncService {
  int _calls = 0;

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
    _calls++;
    if (_calls == 1) {
      return false;
    }
    onDownloadStarted?.call(
      hasLocalDatabase: false,
      localEtag: null,
      remoteEtag: 'remote',
    );
    await beforeReplace();
    onProgress?.call(1);
    await afterReplace();
    return true;
  }
}

/// Blocks until the test allows the seed sync to finish.
class _BlockingStartupSeedSync implements SeedDatabaseSyncService {
  _BlockingStartupSeedSync(this._finishCompleter);

  final Completer<bool> _finishCompleter;

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
      hasLocalDatabase: false,
      localEtag: null,
      remoteEtag: 'remote',
    );
    return _finishCompleter.future;
  }
}

class _IntegrationSeedDbSvc extends SeedDatabaseService {
  _IntegrationSeedDbSvc() : super();

  /// Simulates `dp1_library.sqlite` on disk after a successful seed download.
  bool fileExists = false;

  @override
  Future<bool> hasLocalDatabase() async => fileExists;
}

class _MockBootstrapService implements BootstrapService {
  int bootstrapCallCount = 0;

  @override
  Future<void> bootstrap() async {
    bootstrapCallCount++;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('First install seed + lightweight bootstrap (integration)', () {
    test(
      'offline first sync leaves gate closed; lightweight bootstrap; retry '
      'finishes DP1 bootstrap after file exists',
      () async {
        final provisionedEnvFile = await provisionIntegrationEnvFile();
        addTearDown(() async {
          final parent = provisionedEnvFile.parent;
          if (parent.existsSync()) {
            await parent.delete(recursive: true);
          }
        });

        SeedDatabaseGate.resetForTesting();

        final syncFake = _TwoPhaseStartupSeedSync();
        final seedSvc = _IntegrationSeedDbSvc();
        final mockBootstrap = _MockBootstrapService();
        final memDb = AppDatabase.forTesting(NativeDatabase.memory());
        addTearDown(memDb.close);
        final dbService = DatabaseService(memDb);

        final container = ProviderContainer.test(
          overrides: [
            seedDatabaseSyncServiceProvider.overrideWithValue(syncFake),
            seedDatabaseServiceProvider.overrideWithValue(seedSvc),
            appStateServiceProvider.overrideWithValue(_FakeAppStateService()),
            seedDatabaseReadyActionsProvider.overrideWithValue(_noOpActions),
            rawDatabaseServiceProvider.overrideWithValue(dbService),
            databaseServiceProvider.overrideWith((ref) => dbService),
            bootstrapServiceProvider.overrideWith((ref) => mockBootstrap),
          ],
        );
        addTearDown(container.dispose);

        final seedNotifier = container.read(seedDownloadProvider.notifier);

        await seedNotifier.sync();
        expect(SeedDatabaseGate.isCompleted, isFalse);
        expect(
          container.read(seedDownloadProvider).status,
          SeedDownloadStatus.error,
        );

        final bootstrapNotifier = container.read(bootstrapProvider.notifier);
        await bootstrapNotifier.bootstrapWithoutDp1Library();
        expect(bootstrapNotifier.pendingDp1BootstrapAfterSeed, isTrue);
        expect(
          container.read(bootstrapProvider).phase,
          BootstrapPhase.completed,
        );

        await seedNotifier.sync();
        expect(SeedDatabaseGate.isCompleted, isTrue);
        expect(
          container.read(seedDownloadProvider).status,
          SeedDownloadStatus.done,
        );

        seedSvc.fileExists = true;
        await _ensureDp1BootstrapAfterSeedIfPending(container);

        expect(mockBootstrap.bootstrapCallCount, 1);
        expect(
          container
              .read(bootstrapProvider.notifier)
              .pendingDp1BootstrapAfterSeed,
          isFalse,
        );
      },
    );

    test(
      'onboarding gate defers actions while seed sync is in flight and '
      'stays closed until lightweight bootstrap publishes deferred recovery',
      () async {
        final provisionedEnvFile = await provisionIntegrationEnvFile();
        addTearDown(() async {
          final parent = provisionedEnvFile.parent;
          if (parent.existsSync()) {
            await parent.delete(recursive: true);
          }
        });

        SeedDatabaseGate.resetForTesting();

        final finishSync = Completer<bool>();
        final syncFake = _BlockingStartupSeedSync(finishSync);
        final seedSvc = _IntegrationSeedDbSvc();
        final syncingContainer = ProviderContainer.test(
          overrides: [
            seedDatabaseSyncServiceProvider.overrideWithValue(syncFake),
            seedDatabaseServiceProvider.overrideWithValue(seedSvc),
            appStateServiceProvider.overrideWithValue(_FakeAppStateService()),
            seedDatabaseReadyActionsProvider.overrideWithValue(_noOpActions),
            ff1AutoConnectWatcherProvider.overrideWithValue(null),
          ],
        );
        addTearDown(syncingContainer.dispose);

        syncingContainer
            .read(bootstrapProvider.notifier)
            .markSeedSyncInProgress();
        final syncFuture = syncingContainer
            .read(seedDownloadProvider.notifier)
            .sync();
        await Future<void>.delayed(Duration.zero);

        expect(
          syncingContainer.read(bootstrapSeedSyncGatePhaseProvider),
          BootstrapSeedSyncGatePhase.syncInProgress,
        );
        expect(
          syncingContainer
              .read(onboardingAddAddressActionGateProvider)
              .actionsEnabled,
          isFalse,
        );

        finishSync.complete(false);
        await syncFuture;

        expect(
          syncingContainer.read(bootstrapSeedSyncGatePhaseProvider),
          BootstrapSeedSyncGatePhase.syncInProgress,
        );
        expect(
          syncingContainer
              .read(onboardingAddAddressActionGateProvider)
              .actionsEnabled,
          isFalse,
        );

        await syncingContainer
            .read(bootstrapProvider.notifier)
            .bootstrapWithoutDp1Library();

        expect(
          syncingContainer.read(bootstrapSeedSyncGatePhaseProvider),
          BootstrapSeedSyncGatePhase.deferredRecovery,
        );
        expect(
          syncingContainer
              .read(onboardingAddAddressActionGateProvider)
              .actionsEnabled,
          isTrue,
        );
      },
    );
  });
}

/// Same control flow as `_ensureDp1BootstrapAfterSeedIfPending` in `app.dart`.
Future<void> _ensureDp1BootstrapAfterSeedIfPending(
  ProviderContainer container,
) async {
  final notifier = container.read(bootstrapProvider.notifier);
  if (!notifier.pendingDp1BootstrapAfterSeed) {
    return;
  }
  if (!await container.read(seedDatabaseServiceProvider).hasLocalDatabase()) {
    return;
  }
  await notifier.bootstrap();
}
