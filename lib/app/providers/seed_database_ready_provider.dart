import 'package:app/app/providers/indexer_tokens_provider.dart';
import 'package:app/app/providers/local_data_cleanup_provider.dart';
import 'package:app/app/providers/services_provider.dart';
import 'package:app/infra/database/database_provider.dart';
import 'package:app/infra/database/seed_database_gate.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Actions triggered when [isSeedDatabaseReadyProvider] changes.
class SeedDatabaseReadyActions {
  /// Creates [SeedDatabaseReadyActions].
  const SeedDatabaseReadyActions({
    required this.onNotReady,
    required this.onReady,
  });

  /// Callback for [beforeReplace]: prepares for replace (e.g. drain workers,
  /// close DB). Does NOT perform replace or delete files.
  /// [replaceDatabaseFromTemporaryFile] does delete+rename. Does NOT set
  /// [isSeedDatabaseReadyProvider]; caller does that.
  final Future<void> Function() onNotReady;

  /// Callback for [setReady]: rebinds when DB becomes ready (e.g. invalidate
  /// providers). Called after sync completes, not as the sync's afterReplace.
  /// Does NOT perform replace.
  final Future<void> Function() onReady;
}

/// Provides [SeedDatabaseReadyActions] for [SeedDatabaseReadyNotifier].
/// Logic mirrors [LocalDataCleanupService] stopWorkersGracefully and rebind.
final seedDatabaseReadyActionsProvider = Provider<SeedDatabaseReadyActions>((
  ref,
) {
  final cleanupService = ref.read(localDataCleanupServiceProvider);

  Future<void> onNotReady() async {
    if (!SeedDatabaseGate.isCompleted) return;

    await ref
        .read(tokensSyncCoordinatorProvider.notifier)
        .stopAndDrainForReset();
    await ref
        .read(ensureTrackedAddressesSyncCoordinatorProvider.notifier)
        .stopAndDrainForReset();
    ref.invalidate(tokensSyncCoordinatorProvider);
    ref.invalidate(ensureTrackedAddressesSyncCoordinatorProvider);

    cleanupService.invalidateListProvidersBeforeDbClose?.call();
    await SchedulerBinding.instance.endOfFrame;
    await ref.read(databaseServiceProvider).close();
    // Do NOT delete files here. replaceDatabaseFromTemporaryFile deletes and
    // renames atomically. If replace fails, old DB remains (project_spec).
  }

  Future<void> onReady() async {
    cleanupService.invalidateProvidersForRebind?.call();
    // trackedAddressesSyncProvider is invalidated above; when it rebuilds,
    // its watch emits and calls scheduleSync. No need to call scheduleSync
    // here—that would cause ensureTrackedAddresses to run twice.
  }

  return SeedDatabaseReadyActions(
    onNotReady: onNotReady,
    onReady: onReady,
  );
});

/// Notifier that manages seed database ready state.
/// [setNotReady] is passed as beforeReplace to sync; [setReady] is called after
/// sync completes when DB was replaced.
class SeedDatabaseReadyNotifier extends Notifier<bool> {
  @override
  bool build() => true;

  /// Direct state setter for flows that manage their own teardown (e.g. forgetIExist).
  /// Does NOT run onNotReady/onReady.
  void setStateDirectly(bool value) {
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

  /// Sets state = true, then runs onReady.
  Future<void> setReady() async {
    state = true;
    final actions = ref.read(seedDatabaseReadyActionsProvider);
    await actions.onReady();
  }
}

/// When true, the seed database is ready and DB-watch providers may create
/// streams. When false (during close/replace for Forget I Exist or Rebuild
/// Metadata), providers must not create streams so [close] can complete.
///
/// Use [SeedDatabaseReadyNotifier.setNotReady]/[setReady] to toggle; logic
/// triggers automatically on value change.
final isSeedDatabaseReadyProvider =
    NotifierProvider<SeedDatabaseReadyNotifier, bool>(
      SeedDatabaseReadyNotifier.new,
    );
