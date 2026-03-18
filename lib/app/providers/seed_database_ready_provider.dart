import 'package:app/app/providers/indexer_tokens_provider.dart';
import 'package:app/app/providers/local_data_cleanup_provider.dart';
import 'package:app/app/providers/seed_database_provider.dart';
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

  /// Runs when transitioning to not-ready: stop workers, invalidate, close DB,
  /// delete files. Does NOT set [isSeedDatabaseReadyProvider]; caller does that.
  final Future<void> Function() onNotReady;

  /// Runs when transitioning to ready. Infra invalidation when DB is replaced
  /// is handled in [afterReplace] in the sync flow.
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
    await ref.read(seedDatabaseServiceProvider).deleteDatabaseFiles();
  }

  Future<void> onReady() async {
    cleanupService.invalidateProvidersForRebind?.call();
    ref.read(ensureTrackedAddressesSyncCoordinatorProvider.notifier).scheduleSync();
  }

  return SeedDatabaseReadyActions(
    onNotReady: onNotReady,
    onReady: onReady,
  );
});

/// Notifier that manages seed database ready state.
/// When state changes via [setNotReady]/[setReady], triggers beforeReplace/afterReplace logic.
class SeedDatabaseReadyNotifier extends Notifier<bool> {
  @override
  bool build() => true;

  /// Direct state setter for flows that manage their own teardown (e.g. forgetIExist).
  /// Does NOT run onNotReady/onReady.
  void setStateDirectly(bool value) {
    state = value;
  }

  /// Runs onNotReady, then sets state = false.
  /// No-op if [SeedDatabaseGate] not completed (first install).
  Future<void> setNotReady() async {
    final actions = ref.read(seedDatabaseReadyActionsProvider);
    await actions.onNotReady();
    state = false;
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
