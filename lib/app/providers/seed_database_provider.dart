import 'dart:async';

import 'package:app/app/providers/local_data_cleanup_provider.dart';
import 'package:app/app/providers/seed_database_ready_provider.dart';
import 'package:app/infra/config/app_state_service.dart';
import 'package:app/infra/config/seed_database_config_store.dart';
import 'package:app/infra/database/database_provider.dart';
import 'package:app/infra/database/favorite_history_snapshot.dart';
import 'package:app/infra/database/objectbox_init.dart';
import 'package:app/infra/database/objectbox_models.dart';
import 'package:app/infra/database/seed_database_gate.dart';
import 'package:app/infra/services/bootstrap_service.dart';
import 'package:app/infra/services/seed_database_service.dart';
import 'package:app/infra/services/seed_database_sync_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:uuid/uuid.dart';

final _log = Logger('SeedDownloadNotifier');

/// Possible states of the background seed-database download.
enum SeedDownloadStatus {
  /// Download not yet started.
  idle,

  /// Sync is in progress.
  syncing,

  /// Sync finished (download may have been skipped when ETag unchanged).
  done,

  /// Sync failed; app start may continue with existing DB or empty DB.
  error,
}

/// State for [SeedDownloadNotifier].
class SeedDownloadState {
  /// Creates a [SeedDownloadState].
  const SeedDownloadState({
    required this.status,
    this.errorMessage,
    this.progress,
    this.isSyncInProgress = false,
  });

  /// Current download status.
  final SeedDownloadStatus status;

  /// Error message when [status] is [SeedDownloadStatus.error].
  final String? errorMessage;

  /// Download progress 0.0–1.0 when [status] is [SeedDownloadStatus.syncing].
  final double? progress;

  /// True while any sync() call is running, regardless of UI status.
  /// Use for guards (e.g. skip resume) when [status] may stay idle due to
  /// suppressed loading (hasCompletedSeedDownload).
  final bool isSyncInProgress;

  /// Returns a copy with the given fields replaced.
  SeedDownloadState copyWith({
    SeedDownloadStatus? status,
    String? errorMessage,
    double? progress,
    bool? isSyncInProgress,
  }) {
    return SeedDownloadState(
      status: status ?? this.status,
      errorMessage: errorMessage ?? this.errorMessage,
      progress: progress ?? this.progress,
      isSyncInProgress: isSyncInProgress ?? this.isSyncInProgress,
    );
  }
}

/// Session for a single sync run. A newer sync overrides the previous by
/// replacing the active session; callbacks check the session state before
/// updating.
class _SyncSession {
  _SyncSession(this.id);

  final String id;
  bool completed = false;

  /// Favorite snapshot for this seed sync run only. Overlapping runs must not
  /// share or clear another session's capture before that session restores.
  List<FavoritePlaylistSnapshot>? favoritesSnapshotBeforeReplace;
}

/// Orchestrates the one-time background seed-database download.
///
/// The notifier is kicked off early at app startup (see `App` widget), where
/// it can perform an ETag-based refresh. On completion (success/failure/skip)
/// it opens `SeedDatabaseGate` so Drift can proceed.
///
/// Uses a session model: a newer sync request overrides the current one by
/// replacing the active session. When overridden, the running sync must not
/// update state, callbacks, or UI on completion.
class SeedDownloadNotifier extends Notifier<SeedDownloadState> {
  _SyncSession? _activeSession;
  static const _uuid = Uuid();
  int _syncInProgressCount = 0;

  /// Snapshots from sessions that completed a replace while no longer active
  /// (superseded by a newer [sync]). Restore runs with the winning session or
  /// when no sync remains in flight ([finally] drain), never before another
  /// session's replace can overwrite the DB.
  List<FavoritePlaylistSnapshot>? _pendingFavoriteSnapshots;

  @override
  SeedDownloadState build() {
    return const SeedDownloadState(status: SeedDownloadStatus.idle);
  }

  bool _isSessionActive(_SyncSession session) {
    return _activeSession?.id == session.id && !session.completed;
  }

  _SyncSession _beginSession() {
    final session = _SyncSession(_uuid.v4());
    _activeSession = session;
    return session;
  }

  void _clearSession(_SyncSession session) {
    session.completed = true;
    if (_activeSession?.id == session.id) {
      _activeSession = null;
    }
  }

  /// Moves this [session]'s snapshot into [_pendingFavoriteSnapshots] for a
  /// later restore. A superseded session must not restore before the final
  /// replace.
  void _appendSessionSnapshotToPendingFavorites(_SyncSession session) {
    final s = session.favoritesSnapshotBeforeReplace;
    session.favoritesSnapshotBeforeReplace = null;
    if (s == null || s.isEmpty) return;
    _pendingFavoriteSnapshots = [...?_pendingFavoriteSnapshots, ...s];
  }

  Future<void> _bootstrapAndRestoreFavoriteSnapshots(
    List<FavoritePlaylistSnapshot> snapshots,
  ) async {
    if (snapshots.isEmpty) return;
    final db = ref.read(rawDatabaseServiceProvider);
    await BootstrapService(databaseService: db).bootstrap();
    await db.restoreFavoritePlaylistsSnapshot(snapshots);
  }

  /// Restores favorites from [session] plus any pending snapshots,
  /// then clears both. Used only when this [session] is still the active one.
  ///
  /// Uses `rawDatabaseServiceProvider` from `database_provider.dart` so this
  /// notifier does not import `database_service_provider` (that would create
  /// a provider cycle: seed ready → cleanup → seed download notifier).
  Future<void> _restorePreservedFavoritesAfterSuccessfulSeedReplace(
    _SyncSession session,
  ) async {
    final fromSession = session.favoritesSnapshotBeforeReplace;
    session.favoritesSnapshotBeforeReplace = null;
    final combined = <FavoritePlaylistSnapshot>[
      ...?_pendingFavoriteSnapshots,
      ...?fromSession,
    ];
    _pendingFavoriteSnapshots = null;
    if (combined.isEmpty) return;
    await _bootstrapAndRestoreFavoriteSnapshots(combined);
  }

  /// When no [sync] is in flight, restores snapshots left in
  /// [_pendingFavoriteSnapshots] (e.g. only overridden sessions ran a
  /// replace).
  Future<void> _drainPendingFavoriteRestoreIfIdle() async {
    if (_syncInProgressCount != 0) return;
    final snapshots = _pendingFavoriteSnapshots;
    _pendingFavoriteSnapshots = null;
    if (snapshots == null || snapshots.isEmpty) return;
    await _bootstrapAndRestoreFavoriteSnapshots(snapshots);
  }

  /// Syncs seed DB from remote. Passes setNotReady as beforeReplace; passes
  /// performReconnectInfraInvalidation as afterReplace. Calls setReady after
  /// sync when updated. The actual replace is in
  /// `replaceDatabaseFromTemporaryFile`.
  ///
  /// `onBeforeReplaceStarted` fires at the moment the sync enters the replace
  /// phase, after the download has succeeded but before teardown begins.
  /// Cleanup recovery uses this edge to decide whether the old DB is still the
  /// active source of truth.
  ///
  /// Always starts a new session; a newer session overrides the previous.
  /// Inactive sessions must not update state, provider, or UI on completion.
  ///
  /// Emits [SeedDownloadStatus.syncing] only when [showLoadingInUI] and a
  /// download starts for first install (!hasLocalDatabase). For updates, status
  /// stays idle.
  Future<bool> sync({
    bool forceReplace = false,
    bool showLoadingInUI = true,
    bool completeSeedDatabaseGate = true,
    bool failSilently = true,
    void Function()? onBeforeReplaceStarted,
    void Function(double progress)? onProgress,

    /// Called when a download will actually occur (after ETag check).
    /// Use to show UI (e.g. toast) only when download starts, not on
    /// ETag-unchanged skip.
    void Function()? onDownloadStarted,
  }) async {
    final session = _beginSession();
    _syncInProgressCount++;
    state = state.copyWith(isSyncInProgress: true);

    final service = ref.read(seedDatabaseSyncServiceProvider);
    final appStateService = ref.read(appStateServiceProvider);
    final seedReadyNotifier = ref.read(isSeedDatabaseReadyProvider.notifier);

    var lastProgressBucket = -1;
    var restoreReadinessWhenDrained = false;
    var completeGateWhenDrained = false;

    final suppressLoading = await appStateService.hasCompletedSeedDownload();

    try {
      final updated = await service.sync(
        forceReplace: forceReplace,
        beforeReplace: () async {
          final seedDatabaseService = ref.read(seedDatabaseServiceProvider);
          onBeforeReplaceStarted?.call();
          if (await seedDatabaseService.hasLocalDatabase()) {
            try {
              session.favoritesSnapshotBeforeReplace = await ref
                  .read(rawDatabaseServiceProvider)
                  .getFavoritePlaylistsSnapshot();
            } on Object catch (e, st) {
              _log.warning(
                'Could not snapshot Favorite playlists before seed replace; '
                'favorites may be lost for this session.',
                e,
                st,
              );
              session.favoritesSnapshotBeforeReplace = null;
            }
          }
          await seedReadyNotifier.setNotReady();
        },
        afterReplace: () async {
          // Ref.onDispose does not await async AppDatabase.close. Invalidating
          // appDatabaseProvider while the Drift isolate still releases the file
          // can open a second native connection and hit SQLITE_BUSY (often on
          // PRAGMA journal_mode = WAL).
          if (ref.exists(appDatabaseProvider)) {
            await ref.read(appDatabaseProvider).close();
          }
          ref
              .read(localDataCleanupServiceProvider)
              .performReconnectInfraInvalidation();
        },
        isSessionActive: () => _isSessionActive(session),
        onDownloadStarted:
            ({
              required hasLocalDatabase,
              localEtag,
              remoteEtag,
            }) {
              if (!_isSessionActive(session)) return;
              if (showLoadingInUI && !suppressLoading) {
                notifyForceReplaceStarted();
              }
              onDownloadStarted?.call();
            },
        failSilently: failSilently,
        onProgress: (progress) {
          if (!_isSessionActive(session)) return;
          final bucket = (progress * 100).floor();
          if (bucket > lastProgressBucket) {
            lastProgressBucket = bucket;
            _log.info(
              'Seed database sync download: ${(progress * 100).round()}%',
            );
            notifyForceReplaceProgress(progress);
          }
          onProgress?.call(progress);
        },
      );

      _log.info('Seed database sync complete');
      if (!_isSessionActive(session)) {
        // Overridden session must not update state, UI, or gate. But if it
        // completed replace+afterReplace (updated==true), we must restore
        // readiness: no other path will, and DB consumers stay gated otherwise.
        // Do not restore favorites here: a newer session may still replace the
        // DB; defer snapshot to pending and restore with the winning session or
        // in finally when no sync remains in flight.
        if (updated) {
          await appStateService.setHasCompletedSeedDownload(completed: true);
          await seedReadyNotifier.setReady();
          if (completeSeedDatabaseGate) {
            SeedDatabaseGate.complete();
          }
          _appendSessionSnapshotToPendingFavorites(session);
        }
        return false;
      }
      if (updated) {
        await appStateService.setHasCompletedSeedDownload(completed: true);
        await seedReadyNotifier.setReady();
        await _restorePreservedFavoritesAfterSuccessfulSeedReplace(session);
        notifyForceReplaceFinished();
        if (completeSeedDatabaseGate) {
          SeedDatabaseGate.complete();
        }
        return updated;
      }

      final seedOnDisk = await ref
          .read(seedDatabaseServiceProvider)
          .hasLocalDatabase();
      if (seedOnDisk) {
        // Restore when any prior session dropped readiness (e.g. overlap where
        // this session never reached beforeReplace so it has no local flag).
        // If another sync() is still in flight (replace or download), defer
        // until [finally] drains — same contract as failure recovery.
        final mustDeferReadinessAndGate = _syncInProgressCount > 1;
        if (!ref.read(isSeedDatabaseReadyProvider)) {
          if (mustDeferReadinessAndGate) {
            restoreReadinessWhenDrained = true;
          } else {
            await seedReadyNotifier.setReady();
          }
        }
        notifyForceReplaceFinished();
        if (completeSeedDatabaseGate) {
          if (mustDeferReadinessAndGate) {
            completeGateWhenDrained = true;
          } else {
            SeedDatabaseGate.complete();
          }
        }
        return updated;
      }

      // Sync did not replace the file and none exists yet (e.g. first install
      // offline): keep gate closed until a successful download.
      const msg =
          'Seed database file is missing after sync; waiting for a successful '
          'download before opening the library database.';
      _log.warning(msg);
      notifyForceReplaceFinished(
        success: false,
        errorMessage: msg,
      );
      return false;
    } on Exception catch (e, st) {
      // Only clear this session's in-flight capture. Do not clear
      // [_pendingFavoriteSnapshots]: a superseded session may have enqueued
      // favorites before a newer sync fails; draining in [finally] must still
      // be able to restore them.
      session.favoritesSnapshotBeforeReplace = null;
      _log.severe(
        'Seed database sync failed; app continues with existing database.',
        e,
        st,
      );
      if (_isSessionActive(session)) {
        final seedOnDisk = await ref
            .read(seedDatabaseServiceProvider)
            .hasLocalDatabase();
        if (seedOnDisk && !ref.read(isSeedDatabaseReadyProvider)) {
          // Defer until all overlapping sync() calls finish so we never reopen
          // readiness while another session is still inside replace/swap.
          restoreReadinessWhenDrained = true;
          if (completeSeedDatabaseGate) {
            completeGateWhenDrained = true;
          }
        }
        notifyForceReplaceFinished(success: false, errorMessage: e.toString());
      }
      return false;
    } finally {
      _syncInProgressCount--;
      state = state.copyWith(isSyncInProgress: _syncInProgressCount > 0);
      _clearSession(session);
      if (_syncInProgressCount == 0) {
        if (restoreReadinessWhenDrained) {
          final seedOnDisk = await ref
              .read(seedDatabaseServiceProvider)
              .hasLocalDatabase();
          if (seedOnDisk && !ref.read(isSeedDatabaseReadyProvider)) {
            await seedReadyNotifier.setReady();
          }
          if (completeGateWhenDrained &&
              await ref.read(seedDatabaseServiceProvider).hasLocalDatabase()) {
            SeedDatabaseGate.complete();
          }
        }
        await _drainPendingFavoriteRestoreIfIdle();
      }
    }
  }

  /// Notifies that a force-replace (e.g. Forget I Exist) has started.
  /// Call from the local-data cleanup force-replace flow for tab loading UI.
  void notifyForceReplaceStarted() {
    state = state.copyWith(
      status: SeedDownloadStatus.syncing,
      progress: 0,
    );
  }

  /// Updates progress during force-replace (0.0–1.0).
  void notifyForceReplaceProgress(double progress) {
    if (state.status == SeedDownloadStatus.syncing) {
      state = state.copyWith(progress: progress);
    }
  }

  /// Notifies that force-replace finished. Call after replacement completes.
  void notifyForceReplaceFinished({bool success = true, String? errorMessage}) {
    state = SeedDownloadState(
      status: success ? SeedDownloadStatus.done : SeedDownloadStatus.error,
      errorMessage: errorMessage,
      isSyncInProgress: state.isSyncInProgress,
    );
  }
}

/// Provider for [SeedDownloadNotifier].
final seedDownloadProvider =
    NotifierProvider<SeedDownloadNotifier, SeedDownloadState>(
      SeedDownloadNotifier.new,
    );

/// Provider for retrying seed download. Must be overridden by the app
/// bootstrap with the actual sync logic.
final seedDownloadRetryProvider = Provider<Future<void> Function()>((ref) {
  throw UnimplementedError(
    'seedDownloadRetryProvider must be overridden by the app',
  );
});

/// Provider for [SeedDatabaseService].
final seedDatabaseServiceProvider = Provider<SeedDatabaseService>((ref) {
  return SeedDatabaseService();
});

/// Provider for ObjectBox-backed seed DB config metadata storage.
final seedDatabaseConfigStoreProvider = Provider<SeedDatabaseConfigStore>((
  ref,
) {
  final store = getInitializedObjectBoxStore();
  final box = store.box<RemoteAppConfigEntity>();
  return SeedDatabaseConfigStore(box);
});

/// Provider for ETag-based seed DB sync orchestration.
final seedDatabaseSyncServiceProvider = Provider<SeedDatabaseSyncService>((
  ref,
) {
  final configStore = ref.read(seedDatabaseConfigStoreProvider);
  return SeedDatabaseSyncService(
    seedDatabaseService: ref.read(seedDatabaseServiceProvider),
    loadLocalEtag: configStore.loadSeedEtag,
    saveLocalEtag: configStore.saveSeedEtag,
  );
});
