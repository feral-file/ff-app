import 'package:app/app/providers/database_service_provider.dart';
import 'package:app/app/providers/indexer_tokens_provider.dart';
import 'package:app/app/providers/local_data_cleanup_provider.dart';
import 'package:app/app/providers/services_provider.dart';
import 'package:app/infra/database/seed_database_gate.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Actions triggered when [isSeedDatabaseReadyProvider] changes.
///
/// Use [SeedDatabaseReadyActions] for tests with explicit [onNotReady]/[onReady]
/// callbacks. Production wiring is built by [seedDatabaseReadyActionsProvider].
class SeedDatabaseReadyActions {
  /// Stub for tests: explicit [onNotReady] / [onReady] replace wired behavior.
  SeedDatabaseReadyActions({
    required Future<void> Function() onNotReady,
    required Future<void> Function() onReady,
  }) : _ref = null,
       _onNotReadyStub = onNotReady,
       _onReadyStub = onReady;

  /// Production wiring (same library as [seedDatabaseReadyActionsProvider]).
  SeedDatabaseReadyActions._wired(this._ref)
    : _onNotReadyStub = null,
      _onReadyStub = null;

  final Ref? _ref;
  final Future<void> Function()? _onNotReadyStub;
  final Future<void> Function()? _onReadyStub;

  /// Drains token sync and ensureTrackedAddresses workers, then invalidates
  /// coordinator providers so they rebuild after DB rebind.
  Future<void> _stopWorkersGracefully(Ref ref) async {
    await ref
        .read(tokensSyncCoordinatorProvider.notifier)
        .stopAndDrainForReset();
    await ref
        .read(ensureTrackedAddressesSyncCoordinatorProvider.notifier)
        .stopAndDrainForReset();
    ref
      ..invalidate(tokensSyncCoordinatorProvider)
      ..invalidate(ensureTrackedAddressesSyncCoordinatorProvider);
  }

  /// Prepares for replace (drain workers, close DB). Does NOT delete files.
  /// `replaceDatabaseFromTemporaryFile` owns the staged swap and any
  /// backup/restore behavior. Does NOT set `isSeedDatabaseReadyProvider`;
  /// `SeedDatabaseReadyNotifier.setNotReady` does.
  Future<void> onNotReady() async {
    final stub = _onNotReadyStub;
    if (stub != null) return stub();

    if (!SeedDatabaseGate.isCompleted) return;

    final ref = _ref!;
    await _stopWorkersGracefully(ref);

    final cleanupService = ref.read(localDataCleanupServiceProvider);
    cleanupService.invalidateListProvidersBeforeDbClose?.call();
    await SchedulerBinding.instance.endOfFrame;
    await ref.read(appDatabaseProvider).close();
    // Same order as forget/rebuild metadata teardown: after SQLite is
    // closed, drop [RemoteAppConfigEntity] + [AppStateAddressEntity] so
    // indexing/checkpoints cannot outlive the DB file being replaced.
    await ref.read(objectBoxLocalDataCleanerProvider).lightClear();
    // Do NOT delete files here. The replace service owns the recoverable file
    // swap so the old DB can be restored if promotion fails mid-replace.
  }

  /// Rebinds when DB becomes ready (invalidate providers).
  /// Does NOT perform replace.
  Future<void> onReady() async {
    final stub = _onReadyStub;
    if (stub != null) return stub();

    final ref = _ref!;
    final cleanupService = ref.read(localDataCleanupServiceProvider);
    cleanupService.invalidateProvidersForRebind?.call();
    cleanupService.invalidateReconnectInfraProviders?.call();
    // trackedAddressesSyncProvider is invalidated above; when it rebuilds,
    // its watch emits and calls scheduleSync. No need to call scheduleSync
    // here—that would cause ensureTrackedAddresses to run twice.
  }
}

/// Provides [SeedDatabaseReadyActions] for [SeedDatabaseReadyNotifier].
/// `onNotReady` is the single place for drain + close before DB replace; local
/// cleanup `closeAndDeleteDatabase` calls `setNotReady` then deletes files.
final seedDatabaseReadyActionsProvider = Provider<SeedDatabaseReadyActions>((
  ref,
) {
  return SeedDatabaseReadyActions._wired(ref);
});

/// Notifier that manages seed database ready state.
/// [setNotReady] is passed as beforeReplace to sync; [setReady] is called after
/// sync completes when DB was replaced.
class SeedDatabaseReadyNotifier extends Notifier<bool> {
  @override
  bool build() => true;

  /// Same as [state]; pairs with [seedReadyDirect] setter for lints.
  bool get seedReadyDirect => state;

  /// Direct state assignment for flows that manage their own teardown.
  /// Example: `forgetIExist`.
  /// Does NOT run onNotReady/onReady.
  set seedReadyDirect(bool value) {
    state = value;
  }

  /// Sets state = false first, then runs onNotReady.
  /// Ready-state flip before teardown prevents DB consumers from scheduling
  /// work during invalidation/close (avoids close/reset race).
  /// No-op if [SeedDatabaseGate] not completed (first install).
  Future<void> setNotReady() async {
    if (!SeedDatabaseGate.isCompleted) return;
    final actions = ref.read(seedDatabaseReadyActionsProvider);
    state = false;
    await actions.onNotReady();
  }

  /// Runs `onReady` (invalidate / rebind) first, then sets state = true.
  ///
  /// Ordering avoids a window where `isSeedDatabaseReadyProvider` is true
  /// while consumers still see a stale or closed DB before
  /// `appDatabaseProvider` invalidation completes.
  Future<void> setReady() async {
    final actions = ref.read(seedDatabaseReadyActionsProvider);
    await actions.onReady();
    state = true;
  }
}

/// When true, the seed database is ready and DB-watch providers may create
/// streams. When false (during close/replace for Forget I Exist or Rebuild
/// Metadata), providers must not create streams so `close()` can complete.
///
/// Use `SeedDatabaseReadyNotifier.setNotReady` and `setReady` to run teardown
/// / rebind around a seed replace. Those methods flip readiness and invoke the
/// wired `onNotReady` / `onReady` actions. The `seedReadyDirect` setter updates
/// only the notifier state and does not run `onNotReady` or `onReady`.
final isSeedDatabaseReadyProvider =
    NotifierProvider<SeedDatabaseReadyNotifier, bool>(
      SeedDatabaseReadyNotifier.new,
    );
