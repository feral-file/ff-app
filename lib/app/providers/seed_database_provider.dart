import 'dart:async';

import 'package:app/app/providers/local_data_cleanup_provider.dart';
import 'package:app/app/providers/seed_database_ready_provider.dart';
import 'package:app/infra/config/app_state_service.dart';
import 'package:app/infra/config/seed_database_config_store.dart';
import 'package:app/infra/database/objectbox_init.dart';
import 'package:app/infra/database/objectbox_models.dart';
import 'package:app/infra/database/seed_database_gate.dart';
import 'package:app/infra/services/seed_database_service.dart';
import 'package:app/infra/services/seed_database_sync_service.dart';
import 'package:app/widgets/seed_sync_loading_indicator.dart'
    show SeedSyncLoadingIndicator;
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
  });

  /// Current download status.
  final SeedDownloadStatus status;

  /// Error message when [status] is [SeedDownloadStatus.error].
  final String? errorMessage;

  /// Download progress 0.0–1.0 when [status] is [SeedDownloadStatus.syncing].
  final double? progress;

  /// Returns a copy with the given fields replaced.
  SeedDownloadState copyWith({
    SeedDownloadStatus? status,
    String? errorMessage,
    double? progress,
  }) {
    return SeedDownloadState(
      status: status ?? this.status,
      errorMessage: errorMessage ?? this.errorMessage,
      progress: progress ?? this.progress,
    );
  }
}

/// Session for a single sync run. A newer sync overrides the previous by
/// replacing [_activeSession]; callbacks check [isActive] before updating.
class _SyncSession {
  _SyncSession(this.id);

  final String id;
  bool completed = false;
}

/// Orchestrates the one-time background seed-database download.
///
/// The notifier is kicked off early at app startup (see `App` widget), where
/// it can perform an ETag-based refresh. On completion (success/failure/skip)
/// it opens `SeedDatabaseGate` so Drift can proceed.
///
/// Uses a session model: a newer sync request overrides the current one by
/// replacing [_activeSession]. When overridden, the running sync must not
/// update state, callbacks, or UI on completion.
class SeedDownloadNotifier extends Notifier<SeedDownloadState> {
  _SyncSession? _activeSession;
  static const _uuid = Uuid();

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

  /// Syncs seed DB from remote. Passes [setNotReady] as beforeReplace; passes
  /// [performReconnectInfraInvalidation] as afterReplace. Calls [setReady] after
  /// sync when updated. The actual replace is in [replaceDatabaseFromTemporaryFile].
  ///
  /// Always starts a new session; a newer session overrides the previous. Inactive
  /// sessions must not update state, provider, or UI on completion.
  ///
  /// Emits [SeedDownloadStatus.syncing] only when [showLoadingInUI] and a download
  /// starts for first install (!hasLocalDatabase). For updates, status stays idle.
  Future<bool> sync({
    bool forceReplace = false,
    bool showLoadingInUI = true,
    bool completeSeedDatabaseGate = true,
    bool failSilently = true,
    void Function(double progress)? onProgress,

    /// Called when a download will actually occur (after ETag check).
    /// Use to show UI (e.g. toast) only when download starts, not on ETag-unchanged skip.
    void Function()? onDownloadStarted,
  }) async {
    final session = _beginSession();

    final service = ref.read(seedDatabaseSyncServiceProvider);
    final appStateService = ref.read(appStateServiceProvider);
    final seedReadyNotifier = ref.read(isSeedDatabaseReadyProvider.notifier);

    var lastProgressBucket = -1;

    final suppressLoading = await appStateService.hasCompletedSeedDownload();

    try {
      final updated = await service.sync(
        forceReplace: forceReplace,
        beforeReplace: seedReadyNotifier.setNotReady,
        afterReplace: () async {
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
        // Gate completion owned only by active session; overridden session must
        // not open it before the active sync finishes download/replace.
        return false;
      }
      if (updated) {
        await appStateService.setHasCompletedSeedDownload(completed: true);
        await seedReadyNotifier.setReady();
      }
      notifyForceReplaceFinished();
      if (completeSeedDatabaseGate) {
        SeedDatabaseGate.complete();
      }
      return updated;
    } on Exception catch (e, st) {
      _log.severe(
        'Seed database sync failed; app continues with existing database.',
        e,
        st,
      );
      if (_isSessionActive(session)) {
        notifyForceReplaceFinished(success: false, errorMessage: e.toString());
        if (completeSeedDatabaseGate) SeedDatabaseGate.complete();
      }
      return false;
    } finally {
      _clearSession(session);
    }
  }

  /// Notifies that a force-replace (e.g. Forget I Exist) has started.
  /// Call from [forceReplaceDatabaseFromSeed] so tabs show [SeedSyncLoadingIndicator].
  void notifyForceReplaceStarted() {
    state = const SeedDownloadState(
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

  /// Notifies that force-replace finished. Call after seed replacement completes.
  void notifyForceReplaceFinished({bool success = true, String? errorMessage}) {
    state = success
        ? const SeedDownloadState(status: SeedDownloadStatus.done)
        : SeedDownloadState(
            status: SeedDownloadStatus.error,
            errorMessage: errorMessage,
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
